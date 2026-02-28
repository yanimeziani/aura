'use server';

import { supabaseAdmin } from '@/lib/supabase-admin';
import { ensureMerchant } from '@/lib/merchant';

export async function updateMerchantSettings(settings: { 
  name?: string, 
  strictness_level?: number, 
  settlement_floor?: number,
  data_retention_days?: number, 
}) {
  try {
    const merchantId = await ensureMerchant();
    if (!merchantId) throw new Error('Unauthorized');

    const { error } = await supabaseAdmin
      .from('merchants')
      .update(settings)
      .eq('id', merchantId);

    if (error) throw new Error(error.message);
    return { success: true };
  } catch (error: unknown) {
    const message = error instanceof Error ? error.message : 'Unknown error';
    return { success: false, error: message };
  }
}

export async function completeOnboarding(data: {
  name: string,
  strictness_level: number,
  settlement_floor: number
}) {
  try {
    const merchantId = await ensureMerchant();
    if (!merchantId) throw new Error('Unauthorized');

    const { error } = await supabaseAdmin
      .from('merchants')
      .update({
        ...data,
        onboarding_complete: true
      })
      .eq('id', merchantId);

    if (error) throw new Error(error.message);
    return { success: true };
  } catch (error: unknown) {
    const message = error instanceof Error ? error.message : 'Unknown error';
    return { success: false, error: message };
  }
}
