'use server';

import { supabaseAdmin } from '@/lib/supabase-admin';
import { getMerchantId } from '@/lib/auth';
import { sendSms } from '@/lib/comms';
import { initialOutreachSms, followUpSms, paymentReminderSms } from '@/lib/comms/templates';
import { normalizePhoneToE164 } from '@/lib/phone';
import type { MerchantBasic } from '@/lib/merchant-types';
import { checkOutreachEtiquette } from '@/lib/outreach-etiquette';
import { revalidatePath } from 'next/cache';
import * as Sentry from '@sentry/nextjs';

const SMS_RATE_LIMIT_PER_DAY = 3;
const IDEMPOTENCY_WINDOW_MS = 60 * 60 * 1000; // 1 hour

type SmsType = 'initial' | 'follow_up' | 'reminder';

export async function sendSmsOutreach(formData: FormData) {
  try {
    const merchantId = await getMerchantId();
    if (!merchantId) throw new Error('Unauthorized');

    const debtorId = String(formData.get('debtor_id') || '').trim();
    const smsType = (formData.get('sms_type') as SmsType) || 'initial';
    if (!debtorId) throw new Error('Missing debtor_id');

    const { data: debtor, error: debtorError } = await supabaseAdmin
      .from('debtors')
      .select('*, merchant:merchants(name)')
      .eq('id', debtorId)
      .eq('merchant_id', merchantId)
      .single();

    if (debtorError || !debtor) throw new Error('Debtor not found');
    if (!debtor.phone) throw new Error('No phone number on file for this debtor');

    const smsOptOut = (debtor as { sms_opt_out?: boolean }).sms_opt_out;
    if (smsOptOut) {
      return { success: false, error: 'This recipient has opted out of SMS.' };
    }

    const etiquette = await checkOutreachEtiquette(debtorId, 'sms');
    if (!etiquette.allowed) {
      return { success: false, error: etiquette.reason ?? 'Outreach not allowed by etiquette rules.' };
    }

    const since24h = new Date(Date.now() - 24 * 60 * 60 * 1000).toISOString();
    const { count: count24h } = await supabaseAdmin
      .from('recovery_actions')
      .select('id', { count: 'exact', head: true })
      .eq('debtor_id', debtorId)
      .in('action_type', ['sms_initial', 'sms_follow_up', 'sms_reminder'])
      .gte('created_at', since24h);
    if ((count24h ?? 0) >= SMS_RATE_LIMIT_PER_DAY) {
      return { success: false, error: 'SMS rate limit reached for this debtor. Try again tomorrow.' };
    }

    const since1h = new Date(Date.now() - IDEMPOTENCY_WINDOW_MS).toISOString();
    const { count: sameRecent } = await supabaseAdmin
      .from('recovery_actions')
      .select('id', { count: 'exact', head: true })
      .eq('debtor_id', debtorId)
      .eq('action_type', `sms_${smsType}`)
      .gte('created_at', since1h);
    if ((sameRecent ?? 0) >= 1) {
      revalidatePath('/[locale]/dashboard', 'page');
      return { success: true };
    }

    const merchant = (debtor.merchant ?? { name: 'Merchant' }) as MerchantBasic;
    const baseUrl = process.env.NEXT_PUBLIC_URL || 'https://www.dragun.app';
    const { buildDebtorPortalUrl } = await import('@/lib/debtor-token');
    const chatUrl = buildDebtorPortalUrl(baseUrl, debtorId, 'chat');

    const params = {
      debtorName: debtor.name,
      merchantName: merchant.name,
      amount: Number(debtor.total_debt).toLocaleString(),
      currency: debtor.currency || 'USD',
      chatUrl,
    };

    let body: string;
    switch (smsType) {
      case 'follow_up': {
        const lastContacted = debtor.last_contacted ? new Date(debtor.last_contacted) : new Date();
        const daysSince = Math.max(1, Math.round((Date.now() - lastContacted.getTime()) / (1000 * 60 * 60 * 24)));
        body = followUpSms(params, daysSince);
        break;
      }
      case 'reminder':
        body = paymentReminderSms(params);
        break;
      default:
        body = initialOutreachSms(params);
    }

    const toE164 = normalizePhoneToE164(debtor.phone);
    const result = await sendSms({
      to: toE164,
      body,
      metadata: {
        debtor_id: debtorId,
        merchant_id: merchantId,
        type: `sms_${smsType}`,
      },
    });

    if (!result.ok) {
      throw new Error(`SMS failed: ${result.error.message}`);
    }

    await supabaseAdmin.from('recovery_actions').insert({
      debtor_id: debtorId,
      merchant_id: merchantId,
      action_type: `sms_${smsType}`,
      status_after: debtor.status === 'pending' ? 'contacted' : debtor.status,
      note: `SMS (${smsType}) sent to ${toE164}`,
    });

    if (debtor.status === 'pending') {
      await supabaseAdmin
        .from('debtors')
        .update({ status: 'contacted', last_contacted: new Date().toISOString() })
        .eq('id', debtorId)
        .eq('merchant_id', merchantId);
    } else {
      await supabaseAdmin
        .from('debtors')
        .update({ last_contacted: new Date().toISOString() })
        .eq('id', debtorId)
        .eq('merchant_id', merchantId);
    }

    revalidatePath('/[locale]/dashboard', 'page');
    return { success: true };
  } catch (error) {
    Sentry.captureException(error);
    const message = error instanceof Error ? error.message : 'SMS failed';
    return { success: false, error: message };
  }
}
