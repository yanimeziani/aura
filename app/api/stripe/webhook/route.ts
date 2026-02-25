import Stripe from 'stripe';
import { supabaseAdmin } from '@/lib/supabase-admin';
import { headers } from 'next/headers';

const stripe = new Stripe(process.env.STRIPE_SECRET_KEY!, {
  apiVersion: '2026-01-28.clover',
});

const webhookSecret = process.env.STRIPE_WEBHOOK_SECRET!;

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

  if (event.type === 'checkout.session.completed') {
    const session = event.data.object as Stripe.Checkout.Session;
    const debtorId = session.metadata?.debtor_id;
    
    if (debtorId) {
      // 1. Record Payment
      const { error: paymentError } = await supabaseAdmin
        .from('payments')
        .insert({
          debtor_id: debtorId,
          amount: session.amount_total ? session.amount_total / 100 : 0,
          status: 'success',
          stripe_session_id: session.id,
        });

      if (paymentError) {
        console.error('Error recording payment:', paymentError);
        return new Response('Database error', { status: 500 });
      }

      // 2. Update Debtor Status
      const { error: debtorError } = await supabaseAdmin
        .from('debtors')
        .update({ status: 'settled', last_contacted: new Date().toISOString() })
        .eq('id', debtorId);

      if (debtorError) {
        console.error('Error updating debtor:', debtorError);
        return new Response('Database error', { status: 500 });
      }
    }
  } else if (event.type === 'account.updated') {
    const account = event.data.object as Stripe.Account;
    const onboardingComplete = !!account.charges_enabled && !!account.payouts_enabled;

    const { error: merchantError } = await supabaseAdmin
      .from('merchants')
      .update({ stripe_onboarding_complete: onboardingComplete })
      .eq('stripe_account_id', account.id);

    if (merchantError) {
      console.error('Error updating merchant onboarding status:', merchantError);
      return new Response('Database error', { status: 500 });
    }
  }

  return new Response(JSON.stringify({ received: true }), { status: 200 });
}
