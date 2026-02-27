'use server';

import Stripe from 'stripe';
import { supabaseAdmin } from '@/lib/supabase-admin';
import { redirect } from 'next/navigation';
import { ensureMerchant } from '@/lib/merchant';

const stripe = new Stripe(process.env.STRIPE_SECRET_KEY!);

const PLAN_PRICE_MAP: Record<string, string> = {
  starter: process.env.STRIPE_PRICE_STARTER || '',
  growth: process.env.STRIPE_PRICE_GROWTH || '',
  scale: process.env.STRIPE_PRICE_SCALE || '',
};

export async function createSubscriptionCheckout(formData: FormData) {
  const merchantId = await ensureMerchant();
  if (!merchantId) throw new Error('Unauthorized');

  const plan = String(formData.get('plan') || 'starter');
  const priceId = PLAN_PRICE_MAP[plan];

  if (!priceId) {
    throw new Error(`No Stripe Price configured for plan "${plan}". Set STRIPE_PRICE_${plan.toUpperCase()} env var.`);
  }

  const { data: merchant } = await supabaseAdmin
    .from('merchants')
    .select('email, stripe_customer_id')
    .eq('id', merchantId)
    .single();

  if (!merchant) throw new Error('Merchant not found');

  let customerId = merchant.stripe_customer_id;
  if (!customerId) {
    const customer = await stripe.customers.create({
      email: merchant.email,
      metadata: { merchant_id: merchantId },
    });
    customerId = customer.id;
    await supabaseAdmin
      .from('merchants')
      .update({ stripe_customer_id: customerId })
      .eq('id', merchantId);
  }

  const baseUrl = process.env.NEXT_PUBLIC_URL || `https://${process.env.VERCEL_URL}` || 'https://www.dragun.app';

  const session = await stripe.checkout.sessions.create({
    customer: customerId,
    mode: 'subscription',
    line_items: [{ price: priceId, quantity: 1 }],
    success_url: `${baseUrl}/en/dashboard?subscription_success=true`,
    cancel_url: `${baseUrl}/en/dashboard`,
    metadata: { merchant_id: merchantId, plan },
    subscription_data: {
      metadata: { merchant_id: merchantId, plan },
    },
  });

  redirect(session.url!);
}
