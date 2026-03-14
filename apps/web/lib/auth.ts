import { createClient } from '@/lib/supabase/server';

export async function getMerchantId() {
  const supabase = await createClient();
  const { data: { user } } = await supabase.auth.getUser();
  
  if (!user) {
    // In dev, you might want a fallback, but in prod we should probably return null or throw
    // For now let's keep a fallback for development if needed, but the PRD implies we need real auth.
    // Let's return the user id if it exists.
    return null;
  }

  return user.id;
}
