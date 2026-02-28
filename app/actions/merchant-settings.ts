'use server';

import { revalidatePath } from 'next/cache';
import { supabaseAdmin } from '@/lib/supabase-admin';
import { ensureMerchant } from '@/lib/merchant';

export async function updateMerchantSettings(settings: {
  name?: string;
  strictness_level?: number;
  settlement_floor?: number;
  data_retention_days?: number;
  currency_preference?: string;
  phone?: string;
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

/** Form-facing action for use with useActionState (returns state for modal close, etc.). */
export async function updateMerchantSettingsFromForm(
  _prev: { success: boolean; error?: string },
  formData: FormData
): Promise<{ success: boolean; error?: string }> {
  const name = (formData.get('name') as string)?.trim();
  const strictness = parseInt(formData.get('strictness') as string, 10);
  const settlement = parseFloat(formData.get('settlement') as string) / 100;
  const retention = parseInt(formData.get('data_retention_days') as string, 10) || 0;
  const currency_preference = (formData.get('currency_preference') as string) || undefined;
  const phone = (formData.get('phone') as string)?.trim() || undefined;

  if (!name || Number.isNaN(strictness) || Number.isNaN(settlement)) {
    return { success: false, error: 'Invalid form data' };
  }

  const result = await updateMerchantSettings({
    name,
    strictness_level: strictness,
    settlement_floor: settlement,
    data_retention_days: retention,
    currency_preference: currency_preference || undefined,
    phone,
  });
  if (result.success) revalidatePath('/dashboard');
  return result;
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
