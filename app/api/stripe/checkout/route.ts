import Stripe from 'stripe';
import { supabaseAdmin } from '@/lib/supabase-admin';

const stripe = new Stripe(process.env.STRIPE_SECRET_KEY!, {
  apiVersion: '2026-01-28.clover',
});

export async function POST(req: Request) {
  const { debtorId, amount, currency = 'usd' } = await req.json();

  // Validate inputs
  if (!debtorId || typeof debtorId !== 'string') {
    return new Response('Invalid request', { status: 400 });
  }
  if (typeof amount !== 'number' || amount <= 0 || !isFinite(amount)) {
    return new Response('Invalid amount', { status: 400 });
  }

  const { data: debtor, error: debtorError } = await supabaseAdmin
    .from('debtors')
    .select('*, merchant:merchants(*)')
    .eq('id', debtorId)
    .single();

  if (debtorError || !debtor) {
    console.error('Checkout lookup error:', debtorError);
    return new Response('Debtor or merchant record not found', { status: 404 });
  }

  // eslint-disable-next-line @typescript-eslint/no-explicit-any
  const merchant = debtor.merchant as any; // Cast for access

  const totalDebt = Number(debtor.total_debt);
  if (!Number.isFinite(totalDebt) || totalDebt <= 0) {
    return new Response('Invalid debtor balance', { status: 400 });
  }

  const settlementFloorRaw = Number(merchant?.settlement_floor);
  const normalizedSettlementFloor = Number.isFinite(settlementFloorRaw)
    ? settlementFloorRaw
    : 0.8;
  const settlementFloorRatio = Math.min(1, Math.max(0.7, normalizedSettlementFloor));

  // Server-side validation: amount must not be less than the settlement floor
  const settlementFloor = totalDebt * settlementFloorRatio;
  if (amount < settlementFloor * 0.99) {
    // 1% tolerance for floating point rounding
    return new Response('Amount below settlement floor', { status: 400 });
  }
  if (amount > totalDebt * 1.01) {
    return new Response('Amount exceeds debt', { status: 400 });
  }

  // Stripe Checkout Configuration
  const sessionOptions: Stripe.Checkout.SessionCreateParams = {
    payment_method_types: ['card'],
    line_items: [
      {
        price_data: {
          currency: currency,
          product_data: {
            name: `Debt Settlement - ${merchant.name}`,
          },
          unit_amount: Math.round(amount * 100),
        },
        quantity: 1,
      },
    ],
    mode: 'payment',
    success_url: `${process.env.NEXT_PUBLIC_URL}/pay/${debtorId}/success?session_id={CHECKOUT_SESSION_ID}`,
    cancel_url: `${process.env.NEXT_PUBLIC_URL}/chat/${debtorId}`,
    metadata: {
      debtor_id: debtorId,
      merchant_id: debtor.merchant_id,
    },
  };

  // If the merchant has a connected account AND has completed onboarding, we use Destination Charges
  if (merchant.stripe_account_id && merchant.stripe_onboarding_complete) {
    sessionOptions.payment_intent_data = {
      application_fee_amount: Math.round(amount * 100 * 0.05), // 5% Meziani AI Gateway Fee
      transfer_data: {
        destination: merchant.stripe_account_id,
      },
      // This makes the merchant the 'Merchant of Record'
      on_behalf_of: merchant.stripe_account_id,
    };
  }

  const session = await stripe.checkout.sessions.create(sessionOptions);

  return new Response(JSON.stringify({ url: session.url }), {
    headers: { 'Content-Type': 'application/json' },
  });
}
