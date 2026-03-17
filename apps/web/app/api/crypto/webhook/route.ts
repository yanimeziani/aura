/**
 * POST /api/crypto/webhook
 * Coinbase Commerce webhook — confirms charges and credits the merchant.
 */
import { NextRequest, NextResponse } from 'next/server';
import { supabaseAdmin } from '@/lib/supabase-admin';
import { verifyCoinbaseSignature } from '@/lib/crypto';
import { addCredits, type Token } from '@/lib/credits';

export async function POST(req: NextRequest) {
  const rawBody = await req.text();
  const signature = req.headers.get('x-cc-webhook-signature') ?? '';

  if (!verifyCoinbaseSignature(rawBody, signature)) {
    return NextResponse.json({ error: 'Invalid signature' }, { status: 401 });
  }

  const event = JSON.parse(rawBody);
  const type = event.type as string;
  const charge = event.data;

  if (!charge?.id) {
    return NextResponse.json({ error: 'Missing charge id' }, { status: 400 });
  }

  // Look up our stored charge
  const { data: storedCharge } = await supabaseAdmin
    .from('crypto_charges')
    .select('*')
    .eq('coinbase_charge_id', charge.id)
    .maybeSingle();

  if (!storedCharge) {
    console.warn(`Unknown coinbase charge: ${charge.id}`);
    return NextResponse.json({ received: true });
  }

  if (type === 'charge:confirmed' || type === 'charge:resolved') {
    // Already confirmed? Skip
    if (storedCharge.status === 'confirmed' || storedCharge.status === 'resolved') {
      return NextResponse.json({ received: true });
    }

    // Get tx hash from payments array
    const payments = charge.payments ?? [];
    const txHash = payments[0]?.transaction_id ?? charge.id;

    // Update charge status
    await supabaseAdmin
      .from('crypto_charges')
      .update({
        status: 'confirmed',
        tx_hash: txHash,
        confirmed_at: new Date().toISOString(),
        confirmations: payments[0]?.block?.confirmations ?? 1,
      })
      .eq('id', storedCharge.id);

    // Credit the merchant
    await addCredits({
      merchantId: storedCharge.merchant_id,
      amountUsd: storedCharge.amount_usd,
      token: storedCharge.token as Token,
      tokenAmount: parseFloat(payments[0]?.value?.crypto?.amount ?? storedCharge.amount_usd),
      txHash,
      source: 'coinbase',
      description: `Coinbase charge ${charge.id} confirmed`,
    });

    console.log(`Credited $${storedCharge.amount_usd} to merchant ${storedCharge.merchant_id}`);
  }

  if (type === 'charge:failed' || type === 'charge:expired') {
    await supabaseAdmin
      .from('crypto_charges')
      .update({ status: type === 'charge:failed' ? 'failed' : 'expired' })
      .eq('id', storedCharge.id);
  }

  return NextResponse.json({ received: true });
}
