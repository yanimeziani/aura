import { supabaseAdmin } from './supabase-admin';
import { createClient } from './supabase/server';

export async function ensureMerchant() {
  const supabase = await createClient();
  const { data: { user } } = await supabase.auth.getUser();

  if (!user) return null;

  // 1. Check if merchant already exists by ID
  const { data: existing } = await supabaseAdmin
    .from('merchants')
    .select('id')
    .eq('id', user.id)
    .single();

  if (existing) return existing.id;

  // 2. Check by email (for robustness/recovery)
  const { data: byEmail } = await supabaseAdmin
    .from('merchants')
    .select('id')
    .eq('email', user.email!)
    .single();

  if (byEmail) {
    // Sync the ID if they differ
    if (byEmail.id !== user.id) {
        await supabaseAdmin
            .from('merchants')
            .update({ id: user.id })
            .eq('email', user.email!);
    }
    return user.id;
  }

  // 3. Create new merchant record
  const { error: createError } = await supabaseAdmin
    .from('merchants')
    .insert({
      id: user.id,
      email: user.email!,
      name: user.user_metadata?.full_name || user.email?.split('@')[0] || 'New Merchant',
    });

  if (createError) {
    console.error('Error creating merchant during ensureMerchant:', createError);
    // If it's a conflict, just return the ID (someone might have created it concurrently)
    if (createError.code === '23505') {
        return user.id;
    }
    throw new Error(`Failed to initialize merchant account: ${createError.message} (Code: ${createError.code})`);
  }

  return user.id;
}
