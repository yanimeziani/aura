import { createClient } from '@/lib/supabase/server';
import { supabaseAdmin } from '@/lib/supabase-admin';
import { NextResponse } from 'next/server';
import { routing } from '@/i18n/routing';

const DEFAULT_DASHBOARD = `/${routing.defaultLocale}/dashboard`;

export async function GET(request: Request) {
  const { searchParams, origin } = new URL(request.url);
  const code = searchParams.get('code');
  // if "next" is in search params, use it as the redirection URL after confirmation
  const next = searchParams.get('next') ?? DEFAULT_DASHBOARD;
  const safeNext = next.startsWith('/') ? next : DEFAULT_DASHBOARD;

  if (code) {
    const supabase = await createClient();
    const {
      data: { user },
      error,
    } = await supabase.auth.exchangeCodeForSession(code);

    if (!error && user) {
      // Check if merchant record exists by ID
      let { data: merchant } = await supabaseAdmin
        .from('merchants')
        .select('id')
        .eq('id', user.id)
        .single();

      if (!merchant) {
        // Fallback: Check if merchant record exists by email
        const { data: existingByEmail } = await supabaseAdmin
          .from('merchants')
          .select('id')
          .eq('email', user.email!)
          .single();

        if (existingByEmail) {
          // Update the ID to match the new auth ID
          await supabaseAdmin.from('merchants').update({ id: user.id }).eq('email', user.email!);
          merchant = { id: user.id };
        } else {
          // Create new record
          const { error: merchantError } = await supabaseAdmin.from('merchants').insert({
            id: user.id,
            email: user.email!,
            name: user.user_metadata?.full_name || user.email?.split('@')[0] || 'New Merchant',
          });

          if (!merchantError) {
            merchant = { id: user.id };
            // Seed a sample debtor for the new merchant
            await supabaseAdmin.from('debtors').insert({
              merchant_id: user.id,
              name: 'John Sample',
              email: 'john@example.com',
              total_debt: 1250.0,
              currency: 'USD',
              status: 'pending',
            });
          } else {
            console.error('Error creating merchant record:', merchantError);
          }
        }
      }

      const { data: merchantData } = await supabaseAdmin
        .from('merchants')
        .select('onboarding_complete, onboarding_completed')
        .eq('id', user.id)
        .single();

      const onboardingCompleted = merchantData?.onboarding_completed ?? merchantData?.onboarding_complete ?? false;
      const defaultPostLogin = onboardingCompleted
        ? DEFAULT_DASHBOARD
        : `/${routing.defaultLocale}/onboarding/profile`;
      const redirectPath = safeNext !== DEFAULT_DASHBOARD ? safeNext : defaultPostLogin;

      return NextResponse.redirect(`${origin}${redirectPath}`);
    }
  }

  // return the user to an error page with instructions
  return NextResponse.redirect(`${origin}/auth/auth-code-error`);
}
