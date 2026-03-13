'use server';

import { supabaseAdmin } from '@/lib/supabase-admin';
import { redirect } from 'next/navigation';
import { headers } from 'next/headers';
import { ensureMerchant } from '@/lib/merchant';
import { stripe } from '@/lib/stripe';

function sanitizeLocale(value: unknown) {
  return value === 'fr' ? 'fr' : 'en';
}

async function resolveBaseUrl(): Promise<string> {
  const configured = process.env.NEXT_PUBLIC_URL;
  if (configured) {
    try {
      const parsed = new URL(configured);
      if (parsed.protocol === 'https:' || parsed.protocol === 'http:' || parsed.hostname === 'localhost' || parsed.hostname === '127.0.0.1') {
        return parsed.origin;
      }
    } catch {
      // Fall through to fallbacks.
    }
  }

  const h = await headers();
  const origin = h.get('origin');
  if (origin) {
    try {
      return new URL(origin).origin;
    } catch {
      // Fall through.
    }
  }

  const host = h.get('x-forwarded-host') ?? h.get('host');
  const proto = h.get('x-forwarded-proto') ?? 'https';
  if (host) {
    return `${proto}://${host}`;
  }

  // Fallback for Vercel/serverless when headers are missing
  const vercelUrl = process.env.VERCEL_URL;
  if (vercelUrl) {
    return `https://${vercelUrl}`;
  }

  return 'https://www.dragun.app';
}

export async function createStripeConnectAccount(formData?: FormData) {
  const merchantId = await ensureMerchant();
  if (!merchantId) throw new Error('Unauthorized');
  const locale = sanitizeLocale(formData?.get('locale'));
  const baseUrl = await resolveBaseUrl();
  const dashboardPath = `/${locale}/dashboard`;

  // 1. Get current merchant data
  const { data: merchant, error: merchantError } = await supabaseAdmin
    .from('merchants')
    .select('*')
    .eq('id', merchantId)
    .single();

  if (merchantError || !merchant) {
    console.error('Merchant lookup error:', merchantError);
    throw new Error('Merchant profile initialization failed. Please try again.');
  }

  let accountId = merchant.stripe_account_id;

  // 2. Create Stripe account if it doesn't exist
  if (!accountId) {
    const account = await stripe.accounts.create({
      type: 'express',
      email: merchant.email,
      capabilities: {
        card_payments: { requested: true },
        transfers: { requested: true },
      },
      business_type: 'individual',
      settings: {
        payouts: {
          schedule: {
            interval: 'manual',
          },
        },
      },
    });
    accountId = account.id;

    // Save to DB
    await supabaseAdmin
      .from('merchants')
      .update({ stripe_account_id: accountId })
      .eq('id', merchantId);
  }

  // 3. Create Account Link for onboarding
  const accountLink = await stripe.accountLinks.create({
    account: accountId,
    refresh_url: `${baseUrl}${dashboardPath}`,
    return_url: `${baseUrl}${dashboardPath}?stripe_success=true`,
    type: 'account_onboarding',
  });

  redirect(accountLink.url);
}

export async function createStripeLoginLink() {
  const merchantId = await ensureMerchant();
  if (!merchantId) throw new Error('Unauthorized');

  const { data: merchant, error: merchantError } = await supabaseAdmin
    .from('merchants')
    .select('stripe_account_id')
    .eq('id', merchantId)
    .single();

  if (merchantError || !merchant?.stripe_account_id) {
    console.error('Stripe Login Link Error:', merchantError);
    throw new Error('No Connect account found');
  }

  const loginLink = await stripe.accounts.createLoginLink(merchant.stripe_account_id);
  redirect(loginLink.url);
}
