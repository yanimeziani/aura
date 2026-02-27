import Stripe from 'stripe';
import { supabaseAdmin } from '@/lib/supabase-admin';
import { headers } from 'next/headers';
import { getDebtorLimit, type PlanTier } from '@/lib/paywall';
import { stripe } from '@/lib/stripe';
const webhookSecret = process.env.STRIPE_WEBHOOK_SECRET!;

async function handleCheckoutCompleted(session: Stripe.Checkout.Session) {
  if (session.mode === 'subscription') {
    const merchantId = session.metadata?.merchant_id;
    const plan = (session.metadata?.plan || 'starter') as PlanTier;
    if (!merchantId) return;

    const subscriptionId = typeof session.subscription === 'string'
      ? session.subscription
      : session.subscription?.id;

    if (subscriptionId) {
      const sub = await stripe.subscriptions.retrieve(subscriptionId, { expand: ['items.data'] });
      const firstItem = sub.items?.data?.[0];
      const periodEnd = firstItem?.current_period_end;
      const activeUntil = periodEnd
        ? new Date(periodEnd * 1000).toISOString()
        : new Date(Date.now() + 30 * 24 * 60 * 60 * 1000).toISOString();

      await supabaseAdmin
        .from('merchants')
        .update({
          plan,
          plan_active_until: activeUntil,
          debtor_limit: getDebtorLimit(plan),
          stripe_customer_id: typeof session.customer === 'string' ? session.customer : session.customer?.id,
        })
        .eq('id', merchantId);
    }
    return;
  }

  const debtorId = session.metadata?.debtor_id;
  if (!debtorId) return;

  const { data: existing } = await supabaseAdmin
    .from('payments')
    .select('id')
    .eq('stripe_session_id', session.id)
    .maybeSingle();

  if (existing) return;

  const paymentType = session.metadata?.payment_type || 'full';
  const amountPaid = session.amount_total ? session.amount_total / 100 : 0;
  const feeCents = parseInt(session.metadata?.platform_fee_cents || '0', 10);
  const platformFee = feeCents / 100;

  const { error: paymentError } = await supabaseAdmin
    .from('payments')
    .insert({
      debtor_id: debtorId,
      amount: amountPaid,
      status: 'success',
      stripe_session_id: session.id,
      payment_type: paymentType,
      platform_fee: platformFee,
    });

  if (paymentError) {
    if (paymentError.code === '23505') return;
    console.error('Error recording payment:', paymentError);
    throw new Error('Database error recording payment');
  }

  const newStatus = paymentType === 'installment' ? 'promise_to_pay' : 'paid';

  const { error: debtorError } = await supabaseAdmin
    .from('debtors')
    .update({
      status: newStatus,
      last_contacted: new Date().toISOString(),
      ...(newStatus === 'paid' ? { total_debt: 0 } : {}),
    })
    .eq('id', debtorId);

  if (debtorError) {
    console.error('Error updating debtor:', debtorError);
    throw new Error('Database error updating debtor');
  }
}

async function handleSubscriptionUpdated(subscription: Stripe.Subscription) {
  const merchantId = subscription.metadata?.merchant_id;
  if (!merchantId) return;

  const plan = (subscription.metadata?.plan || 'starter') as PlanTier;
  const isActive = subscription.status === 'active' || subscription.status === 'trialing';
  const firstItem = subscription.items?.data?.[0];
  const periodEnd = firstItem?.current_period_end;
  const activeUntil = periodEnd
    ? new Date(periodEnd * 1000).toISOString()
    : new Date(Date.now() + 30 * 24 * 60 * 60 * 1000).toISOString();

  await supabaseAdmin
    .from('merchants')
    .update({
      plan: isActive ? plan : 'free',
      plan_active_until: isActive ? activeUntil : null,
      debtor_limit: isActive ? getDebtorLimit(plan) : 3,
    })
    .eq('id', merchantId);
}

async function handleSubscriptionDeleted(subscription: Stripe.Subscription) {
  const merchantId = subscription.metadata?.merchant_id;
  if (!merchantId) return;

  await supabaseAdmin
    .from('merchants')
    .update({ plan: 'free', plan_active_until: null, debtor_limit: 3 })
    .eq('id', merchantId);
}

async function handleAccountUpdated(account: Stripe.Account) {
  const onboardingComplete = !!account.charges_enabled && !!account.payouts_enabled;

  const { error } = await supabaseAdmin
    .from('merchants')
    .update({ stripe_onboarding_complete: onboardingComplete })
    .eq('stripe_account_id', account.id);

  if (error) {
    console.error('Error updating merchant onboarding status:', error);
    throw new Error('Database error');
  }
}

export async function POST(req: Request) {
  const body = await req.text();
  const signature = (await headers()).get('stripe-signature') as string;

  let event: Stripe.Event;

  try {
    if (!webhookSecret) {
      console.error('Missing STRIPE_WEBHOOK_SECRET');
      return new Response('Webhook secret not configured', { status: 500 });
    }
    event = stripe.webhooks.constructEvent(body, signature, webhookSecret);
  // eslint-disable-next-line @typescript-eslint/no-explicit-any
  } catch (err: any) {
    console.error(`Webhook signature verification failed: ${err.message}`);
    return new Response(`Webhook Error: ${err.message}`, { status: 400 });
  }

  try {
    switch (event.type) {
      case 'checkout.session.completed':
        await handleCheckoutCompleted(event.data.object as Stripe.Checkout.Session);
        break;
      case 'customer.subscription.updated':
        await handleSubscriptionUpdated(event.data.object as Stripe.Subscription);
        break;
      case 'customer.subscription.deleted':
        await handleSubscriptionDeleted(event.data.object as Stripe.Subscription);
        break;
      case 'account.updated':
        await handleAccountUpdated(event.data.object as Stripe.Account);
        break;
    }
  } catch (error) {
    console.error(`Webhook handler error for ${event.type}:`, error);
    return new Response('Handler error', { status: 500 });
  }

  return new Response(JSON.stringify({ received: true }), { status: 200 });
}
