/**
 * GET /api/crypto/balance?merchant_id=xxx
 * Returns credit balance + recent ledger entries.
 */
import { NextRequest, NextResponse } from 'next/server';
import { getBalance, getLedgerHistory, getUsageHistory } from '@/lib/credits';

export async function GET(req: NextRequest) {
  const merchantId = req.nextUrl.searchParams.get('merchant_id');
  if (!merchantId) {
    return NextResponse.json({ error: 'merchant_id required' }, { status: 400 });
  }

  try {
    const [balance, ledger, usage] = await Promise.all([
      getBalance(merchantId),
      getLedgerHistory(merchantId, 20),
      getUsageHistory(merchantId, 20),
    ]);

    return NextResponse.json({
      balance_usd: balance,
      recent_deposits: ledger.filter(e => e.entry_type === 'deposit'),
      recent_burns: ledger.filter(e => e.entry_type === 'burn').slice(0, 10),
      recent_usage: usage,
    });
  } catch (err) {
    console.error('Balance fetch error:', err);
    return NextResponse.json({ error: 'Failed to fetch balance' }, { status: 500 });
  }
}
