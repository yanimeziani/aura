import Stripe from 'stripe';
import { supabaseAdmin } from '@/lib/supabase-admin';
import { stripe } from '@/lib/stripe';

const PLATFORM_FEE_PERCENT = 0.05;

export async function POST(req: Request) {
  const { debtorId, amount, currency = 'usd' } = await req.json();

  if (!debtorId || typeof debtorId !== 'string') {
    return Response.json({ error: 'Invalid request' }, { status: 400 });
  }
  if (typeof amount !== 'number' || amount <= 0 || !isFinite(amount)) {
    return Response.json({ error: 'Invalid amount' }, { status: 400 });
  }

  const { data: debtor, error: debtorError } = await supabaseAdmin
    .from('debtors')
    .select('*, merchant:merchants(*)')
    .eq('id', debtorId)
    .single();

  if (debtorError || !debtor) {
    return Response.json({ error: 'Debtor or merchant not found' }, { status: 404 });
  }

  if (debtor.status === 'paid') {
    return Response.json({ error: 'This account has already been settled' }, { status: 400 });
  }

  // eslint-disable-next-line @typescript-eslint/no-explicit-any
  const merchant = debtor.merchant as any;

  const totalDebt = Number(debtor.total_debt);
  if (!Number.isFinite(totalDebt) || totalDebt <= 0) {
    return Response.json({ error: 'Invalid debtor balance' }, { status: 400 });
  }

  const settlementFloorRaw = Number(merchant?.settlement_floor);
  const normalizedFloor = Number.isFinite(settlementFloorRaw) ? settlementFloorRaw : 0.8;
  const settlementFloorRatio = Math.min(1, Math.max(0.7, normalizedFloor));

  const isInstallment = amount < totalDebt * 0.95;
  const isFullOrSettlement = !isInstallment;

  if (isFullOrSettlement) {
    const settlementMin = totalDebt * settlementFloorRatio;
    if (amount < settlementMin * 0.99) {
      return Response.json({ error: 'Amount below settlement floor' }, { status: 400 });
    }
    if (amount > totalDebt * 1.01) {
      return Response.json({ error: 'Amount exceeds debt' }, { status: 400 });
    }
  }

  const normalizedCurrency = currency.toLowerCase();
  const amountCents = Math.round(amount * 100);
  const feeCents = Math.round(amountCents * PLATFORM_FEE_PERCENT);
  const baseUrl = process.env.NEXT_PUBLIC_URL || `https://${process.env.VERCEL_URL}` || 'https://www.dragun.app';

  const paymentType = isInstallment ? 'installment' : (amount < totalDebt * 0.99 ? 'settlement' : 'full');

  const sessionOptions: Stripe.Checkout.SessionCreateParams = {
    payment_method_types: ['card'],
    line_items: [
      {
        price_data: {
          currency: normalizedCurrency,
          product_data: {
            name: `Debt ${paymentType === 'installment' ? 'Installment' : paymentType === 'settlement' ? 'Settlement' : 'Payment'} - ${merchant.name}`,
            description: `Account ref: ${debtor.name} | ${paymentType} payment`,
          },
          unit_amount: amountCents,
        },
        quantity: 1,
      },
    ],
    mode: 'payment',
    success_url: `${baseUrl}/pay/${debtorId}/success?session_id={CHECKOUT_SESSION_ID}`,
    cancel_url: `${baseUrl}/chat/${debtorId}`,
    metadata: {
      debtor_id: debtorId,
      merchant_id: debtor.merchant_id,
      payment_type: paymentType,
      original_debt: String(totalDebt),
      platform_fee_cents: String(feeCents),
    },
  };

  if (merchant.stripe_account_id && merchant.stripe_onboarding_complete) {
    sessionOptions.payment_intent_data = {
      application_fee_amount: feeCents,
      transfer_data: {
        destination: merchant.stripe_account_id,
      },
      on_behalf_of: merchant.stripe_account_id,
    };
  }

  try {
    const session = await stripe.checkout.sessions.create(sessionOptions);
    return Response.json({ url: session.url });
  } catch (err) {
    console.error('Stripe checkout creation failed:', err);
    return Response.json({ error: 'Payment processing error. Please try again.' }, { status: 500 });
  }
}
