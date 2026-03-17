/**
 * POST /api/crypto/checkout
 * Create a Coinbase Commerce charge OR return local wallet deposit address.
 * Body: { merchant_id, amount_usd, token: 'usdc'|'btc'|'eth', method: 'coinbase'|'local' }
 */
import { NextRequest, NextResponse } from 'next/server';
import { createCoinbaseCharge, getDepositAddress, tokenToUsd } from '@/lib/crypto';
import type { Token } from '@/lib/credits';

const VALID_TOKENS: Token[] = ['usdc', 'btc', 'eth'];
const MIN_DEPOSIT = 1;     // $1 minimum
const MAX_DEPOSIT = 10000; // $10K max per charge

export async function POST(req: NextRequest) {
  try {
    const body = await req.json();
    const { merchant_id, amount_usd, token, method } = body as {
      merchant_id: string;
      amount_usd: number;
      token: Token;
      method: 'coinbase' | 'local';
    };

    if (!merchant_id || !amount_usd || !token || !method) {
      return NextResponse.json({ error: 'Missing required fields' }, { status: 400 });
    }

    if (!VALID_TOKENS.includes(token)) {
      return NextResponse.json({ error: 'Invalid token. Accepted: usdc, btc, eth' }, { status: 400 });
    }

    if (amount_usd < MIN_DEPOSIT || amount_usd > MAX_DEPOSIT) {
      return NextResponse.json({ error: `Amount must be between $${MIN_DEPOSIT} and $${MAX_DEPOSIT}` }, { status: 400 });
    }

    if (method === 'coinbase') {
      const charge = await createCoinbaseCharge({
        merchantId: merchant_id,
        amountUsd: amount_usd,
        token,
        redirectUrl: `${process.env.NEXT_PUBLIC_APP_URL ?? ''}/sovereign?tab=credits`,
      });

      return NextResponse.json({
        method: 'coinbase',
        charge_id: charge.chargeId,
        hosted_url: charge.hostedUrl,
        addresses: charge.addresses,
      });
    }

    if (method === 'local') {
      const address = getDepositAddress(token);
      const price = await tokenToUsd(token, 1);
      const tokenAmount = token === 'usdc' ? amount_usd : amount_usd / price;

      return NextResponse.json({
        method: 'local',
        token,
        deposit_address: address,
        amount_usd,
        token_amount: tokenAmount,
        price_per_token: price,
        note: 'Send exact amount to the deposit address. Credits will be added after confirmation.',
      });
    }

    return NextResponse.json({ error: 'Invalid method. Use: coinbase or local' }, { status: 400 });
  } catch (err) {
    console.error('Crypto checkout error:', err);
    return NextResponse.json({ error: 'Checkout failed' }, { status: 500 });
  }
}
