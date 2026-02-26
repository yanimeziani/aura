'use server';

import { supabaseAdmin } from '@/lib/supabase-admin';
import { ensureMerchant } from '@/lib/merchant';

export async function updateOnboardingProfile(data: {
  name: string;
  country: string;
  currency_preference: string;
  phone?: string | null;
}) {
  try {
    const merchantId = await ensureMerchant();
    if (!merchantId) throw new Error('Unauthorized');

    const { error } = await supabaseAdmin
      .from('merchants')
      .update({
        name: data.name,
        country: data.country,
        currency_preference: data.currency_preference,
        phone: data.phone || null,
        onboarding_step: 'tutorial',
      })
      .eq('id', merchantId);

    if (error) throw new Error(error.message);
    return { success: true };
  } catch (error: any) {
    return { success: false, error: error.message };
  }
}

export async function completeOnboardingTutorial() {
  try {
    const merchantId = await ensureMerchant();
    if (!merchantId) throw new Error('Unauthorized');

    const { error } = await supabaseAdmin
      .from('merchants')
      .update({
        onboarding_completed: true,
        onboarding_step: null,
      })
      .eq('id', merchantId);

    if (error) throw new Error(error.message);
    return { success: true };
  } catch (error: any) {
    return { success: false, error: error.message };
  }
}
