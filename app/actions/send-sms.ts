'use server';

import { supabaseAdmin } from '@/lib/supabase-admin';
import { getMerchantId } from '@/lib/auth';
import { sendSms } from '@/lib/comms';
import { initialOutreachSms, followUpSms, paymentReminderSms } from '@/lib/comms/templates';
import { revalidatePath } from 'next/cache';
import * as Sentry from '@sentry/nextjs';

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

    // eslint-disable-next-line @typescript-eslint/no-explicit-any
    const merchant = debtor.merchant as any;
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

    const result = await sendSms({
      to: debtor.phone,
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
      note: `SMS (${smsType}) sent to ${debtor.phone}`,
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
