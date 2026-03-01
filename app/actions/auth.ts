'use server';

import { createClient } from '@/lib/supabase/server';
import { headers } from 'next/headers';
import { redirect } from 'next/navigation';
import { routing } from '@/i18n/routing';

export async function signInWithGoogle() {
  const supabase = await createClient();
  const h = await headers();
  const host = h.get('x-forwarded-host') ?? h.get('host');
  const proto = h.get('x-forwarded-proto') ?? 'https';
  const baseUrl = process.env.NEXT_PUBLIC_URL ?? (host ? `${proto}://${host}` : null);

  const dashboardPath = `/${routing.defaultLocale}/dashboard`;
  const options = baseUrl
    ? { redirectTo: `${baseUrl}/api/auth/callback?next=${encodeURIComponent(dashboardPath)}` }
    : undefined;

  const { data, error } = await supabase.auth.signInWithOAuth({
    provider: 'google',
    options,
  });

  if (error) {
    console.error('OAuth error:', error);
    return { error: error.message };
  }

  if (data.url) {
    redirect(data.url);
  }
}

export async function signOut() {
  const supabase = await createClient();
  await supabase.auth.signOut();
}
