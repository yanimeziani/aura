/**
 * Hybrid crypto payment layer:
 * 1. Coinbase Commerce API — hosted checkout for USDC/BTC/ETH
 * 2. Local self-custody wallets — direct on-chain deposits
 */
import { supabaseAdmin } from './supabase-admin';
import type { Token } from './credits';

// --- Coinbase Commerce API ---

const COINBASE_API_KEY = process.env.COINBASE_COMMERCE_API_KEY!;
const COINBASE_WEBHOOK_SECRET = process.env.COINBASE_COMMERCE_WEBHOOK_SECRET!;
const COINBASE_API = 'https://api.commerce.coinbase.com';

export { COINBASE_WEBHOOK_SECRET };

interface CoinbaseCharge {
  id: string;
  hosted_url: string;
  pricing: Record<string, { amount: string; currency: string }>;
  addresses: Record<string, string>;
  timeline: Array<{ status: string; time: string }>;
}

export async function createCoinbaseCharge(params: {
  merchantId: string;
  amountUsd: number;
  token: Token;
  description?: string;
  redirectUrl?: string;
}): Promise<{ chargeId: string; hostedUrl: string; addresses: Record<string, string> }> {
  const res = await fetch(`${COINBASE_API}/charges`, {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      'X-CC-Api-Key': COINBASE_API_KEY,
      'X-CC-Version': '2018-03-22',
    },
    body: JSON.stringify({
      name: `LLM Credits — $${params.amountUsd}`,
      description: params.description ?? 'Purchase LLM usage credits via Dragun',
      pricing_type: 'fixed_price',
      local_price: { amount: params.amountUsd.toString(), currency: 'USD' },
      metadata: {
        merchant_id: params.merchantId,
        token: params.token,
      },
      redirect_url: params.redirectUrl,
    }),
  });

  if (!res.ok) {
    const err = await res.text();
    throw new Error(`Coinbase Commerce error: ${res.status} ${err}`);
  }

  const { data } = (await res.json()) as { data: CoinbaseCharge };

  // Persist charge
  await supabaseAdmin.from('crypto_charges').insert({
    merchant_id: params.merchantId,
    coinbase_charge_id: data.id,
    amount_usd: params.amountUsd,
    token: params.token,
    status: 'pending',
    hosted_url: data.hosted_url,
  });

  return {
    chargeId: data.id,
    hostedUrl: data.hosted_url,
    addresses: data.addresses,
  };
}

export async function getCoinbaseCharge(chargeId: string): Promise<CoinbaseCharge> {
  const res = await fetch(`${COINBASE_API}/charges/${chargeId}`, {
    headers: {
      'X-CC-Api-Key': COINBASE_API_KEY,
      'X-CC-Version': '2018-03-22',
    },
  });
  if (!res.ok) throw new Error(`Coinbase fetch failed: ${res.status}`);
  const { data } = (await res.json()) as { data: CoinbaseCharge };
  return data;
}

// Verify Coinbase Commerce webhook signature
export function verifyCoinbaseSignature(payload: string, signature: string): boolean {
  const crypto = require('crypto');
  const expected = crypto
    .createHmac('sha256', COINBASE_WEBHOOK_SECRET)
    .update(payload)
    .digest('hex');
  return crypto.timingSafeEqual(Buffer.from(expected), Buffer.from(signature));
}

// --- Local self-custody wallet ---

// Pre-configured deposit addresses (set in env or vault)
const LOCAL_WALLETS: Record<Token, string> = {
  usdc: process.env.LOCAL_WALLET_USDC ?? '',
  btc: process.env.LOCAL_WALLET_BTC ?? '',
  eth: process.env.LOCAL_WALLET_ETH ?? '',
};

export function getDepositAddress(token: Token): string {
  const addr = LOCAL_WALLETS[token];
  if (!addr) throw new Error(`No local wallet configured for ${token}`);
  return addr;
}

export async function registerLocalDeposit(params: {
  merchantId: string;
  token: Token;
  tokenAmount: number;
  amountUsd: number;
  txHash: string;
}): Promise<void> {
  // Record the charge
  await supabaseAdmin.from('crypto_charges').insert({
    merchant_id: params.merchantId,
    amount_usd: params.amountUsd,
    token: params.token,
    status: 'pending',
    local_address: LOCAL_WALLETS[params.token],
    tx_hash: params.txHash,
  });
}

export async function confirmCharge(chargeId: string, txHash: string): Promise<void> {
  await supabaseAdmin
    .from('crypto_charges')
    .update({
      status: 'confirmed',
      tx_hash: txHash,
      confirmed_at: new Date().toISOString(),
    })
    .eq('id', chargeId);
}

// --- Price feeds (simple, for USD conversion) ---

interface PriceCache {
  prices: Record<Token, number>;
  fetchedAt: number;
}

let priceCache: PriceCache = { prices: { usdc: 1, btc: 0, eth: 0 }, fetchedAt: 0 };
const CACHE_TTL_MS = 60_000; // 1 minute

export async function getTokenPriceUsd(token: Token): Promise<number> {
  if (token === 'usdc') return 1;

  const now = Date.now();
  if (now - priceCache.fetchedAt < CACHE_TTL_MS && priceCache.prices[token] > 0) {
    return priceCache.prices[token];
  }

  try {
    const ids = token === 'btc' ? 'bitcoin' : 'ethereum';
    const res = await fetch(
      `https://api.coingecko.com/api/v3/simple/price?ids=${ids}&vs_currencies=usd`,
      { signal: AbortSignal.timeout(5000) }
    );
    if (res.ok) {
      const data = await res.json();
      const price = data[ids]?.usd ?? 0;
      priceCache.prices[token] = price;
      priceCache.fetchedAt = now;
      return price;
    }
  } catch {
    // Fall through to cached or zero
  }

  return priceCache.prices[token] ?? 0;
}

export async function tokenToUsd(token: Token, amount: number): Promise<number> {
  const price = await getTokenPriceUsd(token);
  return amount * price;
}
