/**
 * Credit system: deposit crypto → get USD-normalised credits → burn on LLM usage.
 * Sources: Coinbase Commerce (hosted checkout) + on-chain self-custody wallets.
 */
import { supabaseAdmin } from './supabase-admin';

export type Token = 'usdc' | 'btc' | 'eth';
export type EntryType = 'deposit' | 'burn' | 'refund' | 'bonus';
export type ChargeSource = 'coinbase' | 'onchain' | 'stripe' | 'system';

// Cost per 1K tokens (input/output) by model tier — update as pricing changes
const MODEL_COSTS: Record<string, { input: number; output: number }> = {
  'llama-3.3-70b-versatile':   { input: 0.00059, output: 0.00079 },
  'llama-3.1-8b-instant':      { input: 0.00005, output: 0.00008 },
  'mixtral-8x7b-32768':        { input: 0.00024, output: 0.00024 },
  'default':                    { input: 0.0006,  output: 0.0008  },
};

export function estimateCost(model: string, tokensIn: number, tokensOut: number): number {
  const costs = MODEL_COSTS[model] ?? MODEL_COSTS['default'];
  return (tokensIn / 1000) * costs.input + (tokensOut / 1000) * costs.output;
}

export async function getBalance(merchantId: string): Promise<number> {
  const { data } = await supabaseAdmin
    .from('merchants')
    .select('credit_balance_usd')
    .eq('id', merchantId)
    .single();
  return data?.credit_balance_usd ?? 0;
}

export async function addCredits(params: {
  merchantId: string;
  amountUsd: number;
  token: Token;
  tokenAmount: number;
  txHash?: string;
  source: ChargeSource;
  description?: string;
}): Promise<{ balance: number }> {
  const currentBalance = await getBalance(params.merchantId);
  const newBalance = currentBalance + params.amountUsd;

  // Insert ledger entry
  const { error: ledgerError } = await supabaseAdmin
    .from('credit_ledger')
    .insert({
      merchant_id: params.merchantId,
      entry_type: 'deposit' as EntryType,
      amount_usd: params.amountUsd,
      token: params.token,
      token_amount: params.tokenAmount,
      tx_hash: params.txHash,
      source: params.source,
      description: params.description ?? `${params.token.toUpperCase()} deposit`,
      balance_after: newBalance,
    });

  if (ledgerError) throw new Error(`Ledger insert failed: ${ledgerError.message}`);

  // Update materialised balance
  const { error: balanceError } = await supabaseAdmin
    .from('merchants')
    .update({ credit_balance_usd: newBalance })
    .eq('id', params.merchantId);

  if (balanceError) throw new Error(`Balance update failed: ${balanceError.message}`);

  return { balance: newBalance };
}

export async function burnCredits(params: {
  merchantId: string;
  model: string;
  tokensIn: number;
  tokensOut: number;
  endpoint?: string;
  latencyMs?: number;
}): Promise<{ allowed: boolean; cost: number; balance: number }> {
  const cost = estimateCost(params.model, params.tokensIn, params.tokensOut);
  const currentBalance = await getBalance(params.merchantId);

  if (currentBalance < cost) {
    return { allowed: false, cost, balance: currentBalance };
  }

  const newBalance = currentBalance - cost;

  // Insert burn entry
  await supabaseAdmin.from('credit_ledger').insert({
    merchant_id: params.merchantId,
    entry_type: 'burn' as EntryType,
    amount_usd: -cost,
    token: 'fiat',
    token_amount: cost,
    source: 'system' as ChargeSource,
    description: `LLM usage: ${params.model} (${params.tokensIn}in/${params.tokensOut}out)`,
    balance_after: newBalance,
  });

  // Log usage
  await supabaseAdmin.from('usage_log').insert({
    merchant_id: params.merchantId,
    model: params.model,
    tokens_in: params.tokensIn,
    tokens_out: params.tokensOut,
    cost_usd: cost,
    endpoint: params.endpoint,
    latency_ms: params.latencyMs,
  });

  // Update materialised balance
  await supabaseAdmin
    .from('merchants')
    .update({ credit_balance_usd: newBalance })
    .eq('id', params.merchantId);

  return { allowed: true, cost, balance: newBalance };
}

export async function checkCanAfford(merchantId: string, estimatedTokens: number = 4000): Promise<boolean> {
  const balance = await getBalance(merchantId);
  const worstCaseCost = estimateCost('default', estimatedTokens, estimatedTokens);
  return balance >= worstCaseCost;
}

export async function getUsageHistory(merchantId: string, limit: number = 50) {
  const { data } = await supabaseAdmin
    .from('usage_log')
    .select('*')
    .eq('merchant_id', merchantId)
    .order('created_at', { ascending: false })
    .limit(limit);
  return data ?? [];
}

export async function getLedgerHistory(merchantId: string, limit: number = 50) {
  const { data } = await supabaseAdmin
    .from('credit_ledger')
    .select('*')
    .eq('merchant_id', merchantId)
    .order('created_at', { ascending: false })
    .limit(limit);
  return data ?? [];
}
