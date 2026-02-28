import { supabaseAdmin } from '@/lib/supabase-admin';
import { sendEmail } from '@/lib/comms';
import { followUpEmail } from '@/lib/comms/templates';
import { buildDebtorPortalUrl } from '@/lib/debtor-token';
import { getRagSnippet, RAG_QUERIES } from '@/lib/rag';

/**
 * Send follow-up email for a debtor. Used by cron and server actions.
 * Does not require auth context.
 */
export async function sendFollowUpEmail(debtorId: string): Promise<{ success: boolean; error?: string }> {
  const { data: debtor, error: debtorError } = await supabaseAdmin
    .from('debtors')
    .select('*, merchant:merchants(name, email)')
    .eq('id', debtorId)
    .single();

  if (debtorError || !debtor) return { success: false, error: 'Debtor not found' };

  const merchant = debtor.merchant as { name: string; email?: string };
  const merchantId = debtor.merchant_id;
  const baseUrl = process.env.NEXT_PUBLIC_URL || 'https://www.dragun.app';
  const chatUrl = buildDebtorPortalUrl(baseUrl, debtorId, 'chat');
  const payUrl = buildDebtorPortalUrl(baseUrl, debtorId, 'pay');

  const lastContacted = debtor.last_contacted ? new Date(debtor.last_contacted) : new Date();
  const daysSince = Math.max(1, Math.round((Date.now() - lastContacted.getTime()) / (1000 * 60 * 60 * 24)));

  const contractSnippet = await getRagSnippet(merchantId, RAG_QUERIES.outreach, 280);

  const emailContent = followUpEmail(
    {
      debtorName: debtor.name,
      merchantName: merchant.name,
      amount: Number(debtor.total_debt).toLocaleString(),
      currency: debtor.currency || 'USD',
      chatUrl,
      payUrl,
      contractSnippet: contractSnippet || undefined,
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

  if (!result.ok) return { success: false, error: result.error.message };

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

  return { success: true };
}
