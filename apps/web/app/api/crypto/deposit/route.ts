/**
 * POST /api/crypto/deposit
 * Manual on-chain deposit confirmation (for local wallet path).
 * An admin or automated watcher calls this after verifying the tx on-chain.
 * Body: { merchant_id, token, token_amount, amount_usd, tx_hash }
 */
import { NextRequest, NextResponse } from 'next/server';
import { supabaseAdmin } from '@/lib/supabase-admin';
import { addCredits, type Token } from '@/lib/credits';

const DEPOSIT_SECRET = process.env.CRYPTO_DEPOSIT_SECRET;

export async function POST(req: NextRequest) {
  // Protect this endpoint — only callable by the chain watcher or admin
  const auth = req.headers.get('x-deposit-secret');
  if (!DEPOSIT_SECRET || auth !== DEPOSIT_SECRET) {
    return NextResponse.json({ error: 'Unauthorized' }, { status: 401 });
  }

  try {
    const body = await req.json();
    const { merchant_id, token, token_amount, amount_usd, tx_hash } = body as {
      merchant_id: string;
      token: Token;
      token_amount: number;
      amount_usd: number;
      tx_hash: string;
    };

    if (!merchant_id || !token || !token_amount || !amount_usd || !tx_hash) {
      return NextResponse.json({ error: 'Missing required fields' }, { status: 400 });
    }

    // Check for duplicate tx
    const { data: existing } = await supabaseAdmin
      .from('crypto_charges')
      .select('id')
      .eq('tx_hash', tx_hash)
      .maybeSingle();

    if (existing) {
      return NextResponse.json({ error: 'Transaction already processed' }, { status: 409 });
    }

    // Record charge as confirmed
    await supabaseAdmin.from('crypto_charges').insert({
      merchant_id,
      amount_usd,
      token,
      status: 'confirmed',
      local_address: process.env[`LOCAL_WALLET_${token.toUpperCase()}`] ?? '',
      tx_hash,
      confirmed_at: new Date().toISOString(),
      confirmations: 1,
    });

    // Credit the merchant
    const result = await addCredits({
      merchantId: merchant_id,
      amountUsd: amount_usd,
      token,
      tokenAmount: token_amount,
      txHash: tx_hash,
      source: 'onchain',
      description: `On-chain ${token.toUpperCase()} deposit`,
    });

    return NextResponse.json({
      credited: true,
      amount_usd,
      token,
      token_amount,
      balance: result.balance,
    });
  } catch (err) {
    console.error('Deposit confirmation error:', err);
    return NextResponse.json({ error: 'Deposit failed' }, { status: 500 });
  }
}
