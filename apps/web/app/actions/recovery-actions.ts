'use server';

import { supabaseAdmin } from '@/lib/supabase-admin';
import { getMerchantId } from '@/lib/auth';
import { revalidatePath } from 'next/cache';
import * as Sentry from '@sentry/nextjs';
import { toCollectionStatus, CollectionStatus } from '@/lib/recovery-types';

export async function updateRecoveryStatus(formData: FormData) {
  try {
    const merchantId = await getMerchantId();
    if (!merchantId) throw new Error('Unauthorized');

    const debtorId = String(formData.get('debtor_id') || '').trim();
    const status = toCollectionStatus(formData.get('status'));
    const note = String(formData.get('note') || '').trim();
    const actionType = String(formData.get('action_type') || 'status_update').trim();
    const confirmEscalated = String(formData.get('confirm_escalated') || '').trim().toLowerCase();

    if (!debtorId) throw new Error('Missing debtor_id');
    if (status === 'escalated' && confirmEscalated !== 'yes') {
      throw new Error('Escalation requires confirmation. Tick confirm escalation.');
    }

    const updatePayload: { status: CollectionStatus; last_contacted?: string } = { status };
    if (status === 'contacted' || status === 'promise_to_pay' || status === 'no_answer') {
      updatePayload.last_contacted = new Date().toISOString();
    }

    const { error: updateError } = await supabaseAdmin
      .from('debtors')
      .update(updatePayload)
      .eq('id', debtorId)
      .eq('merchant_id', merchantId);

    if (updateError) throw new Error(updateError.message);

    const { error: logError } = await supabaseAdmin.from('recovery_actions').insert({
      debtor_id: debtorId,
      merchant_id: merchantId,
      action_type: actionType,
      status_after: status,
      note: note || null,
    });

    if (logError) throw new Error(logError.message);

    revalidatePath('/[locale]/dashboard', 'page');
  } catch (error) {
    Sentry.captureException(error);
    throw error;
  }
}
