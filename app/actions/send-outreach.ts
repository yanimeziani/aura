'use server';

import { supabaseAdmin } from '@/lib/supabase-admin';
import { getMerchantId } from '@/lib/auth';
import { sendEmail } from '@/lib/comms';
import { initialOutreachEmail, followUpEmail } from '@/lib/comms/templates';
import { revalidatePath } from 'next/cache';
import * as Sentry from '@sentry/nextjs';

export async function sendInitialOutreach(formData: FormData) {
  try {
    const merchantId = await getMerchantId();
    if (!merchantId) throw new Error('Unauthorized');

    const debtorId = String(formData.get('debtor_id') || '').trim();
    if (!debtorId) throw new Error('Missing debtor_id');

    const { data: debtor, error: debtorError } = await supabaseAdmin
      .from('debtors')
      .select('*, merchant:merchants(name, email)')
      .eq('id', debtorId)
      .eq('merchant_id', merchantId)
      .single();

    if (debtorError || !debtor) throw new Error('Debtor not found');

    // eslint-disable-next-line @typescript-eslint/no-explicit-any
    const merchant = debtor.merchant as any;
    const baseUrl = process.env.NEXT_PUBLIC_URL || 'https://www.dragun.app';

    const emailContent = initialOutreachEmail({
      debtorName: debtor.name,
      merchantName: merchant.name,
      amount: Number(debtor.total_debt).toLocaleString(),
      currency: debtor.currency || 'USD',
      chatUrl: `${baseUrl}/en/chat/${debtorId}`,
      payUrl: `${baseUrl}/en/pay/${debtorId}`,
    });

    const result = await sendEmail({
      to: debtor.email,
      subject: emailContent.subject,
      html: emailContent.html,
      text: emailContent.text,
      tags: ['outreach', 'initial'],
      metadata: {
        debtor_id: debtorId,
        merchant_id: merchantId,
        type: 'initial_outreach',
      },
    });

    if (!result.ok) {
      throw new Error(`Email failed: ${result.error.message}`);
    }

    await supabaseAdmin.from('recovery_actions').insert({
      debtor_id: debtorId,
      merchant_id: merchantId,
      action_type: 'email_outreach',
      status_after: debtor.status === 'pending' ? 'contacted' : debtor.status,
      note: `Initial outreach email sent to ${debtor.email}`,
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
    const message = error instanceof Error ? error.message : 'Outreach failed';
    return { success: false, error: message };
  }
}

export async function sendFollowUp(formData: FormData) {
  try {
    const merchantId = await getMerchantId();
    if (!merchantId) throw new Error('Unauthorized');

    const debtorId = String(formData.get('debtor_id') || '').trim();
    if (!debtorId) throw new Error('Missing debtor_id');

    const { data: debtor, error: debtorError } = await supabaseAdmin
      .from('debtors')
      .select('*, merchant:merchants(name, email)')
      .eq('id', debtorId)
      .eq('merchant_id', merchantId)
      .single();

    if (debtorError || !debtor) throw new Error('Debtor not found');

    // eslint-disable-next-line @typescript-eslint/no-explicit-any
    const merchant = debtor.merchant as any;
    const baseUrl = process.env.NEXT_PUBLIC_URL || 'https://www.dragun.app';

    const lastContacted = debtor.last_contacted ? new Date(debtor.last_contacted) : new Date();
    const daysSince = Math.max(1, Math.round((Date.now() - lastContacted.getTime()) / (1000 * 60 * 60 * 24)));

    const emailContent = followUpEmail(
      {
        debtorName: debtor.name,
        merchantName: merchant.name,
        amount: Number(debtor.total_debt).toLocaleString(),
        currency: debtor.currency || 'USD',
        chatUrl: `${baseUrl}/en/chat/${debtorId}`,
        payUrl: `${baseUrl}/en/pay/${debtorId}`,
      },
      daysSince,
    );

    const result = await sendEmail({
      to: debtor.email,
      subject: emailContent.subject,
      html: emailContent.html,
      text: emailContent.text,
      tags: ['outreach', 'follow_up'],
      metadata: {
        debtor_id: debtorId,
        merchant_id: merchantId,
        type: 'follow_up',
        days_since_first: String(daysSince),
      },
    });

    if (!result.ok) {
      throw new Error(`Email failed: ${result.error.message}`);
    }

    await supabaseAdmin.from('recovery_actions').insert({
      debtor_id: debtorId,
      merchant_id: merchantId,
      action_type: 'email_follow_up',
      status_after: debtor.status,
      note: `Follow-up email sent (${daysSince}d since last contact)`,
    });

    await supabaseAdmin
      .from('debtors')
      .update({ last_contacted: new Date().toISOString() })
      .eq('id', debtorId)
      .eq('merchant_id', merchantId);

    revalidatePath('/[locale]/dashboard', 'page');
    return { success: true };
  } catch (error) {
    Sentry.captureException(error);
    const message = error instanceof Error ? error.message : 'Follow-up failed';
    return { success: false, error: message };
  }
}
