/**
 * Central RAG (Retrieval Augmented Generation) service.
 * Single place for contract/knowledge retrieval — used by chat, outreach, pay page, dashboard.
 */

import { supabaseAdmin } from '@/lib/supabase-admin';
import { generateEmbedding } from '@/lib/ai-provider';

export type RagOptions = {
  /** Max number of chunks to retrieve (default 5 for chat, 2 for outreach) */
  matchCount?: number;
  /** Similarity threshold 0–1 (default 0.5) */
  matchThreshold?: number;
  /** Cap total context length for emails/snippets (default no cap) */
  maxContextChars?: number;
  /** Optional: merge with platform fallback (e.g. compliance phrasing) */
  fallbackContext?: string;
};

const DEFAULT_OPTIONS: Required<Omit<RagOptions, 'maxContextChars' | 'fallbackContext'>> = {
  matchCount: 5,
  matchThreshold: 0.5,
};

/**
 * Get the latest contract id for a merchant (single source today; extensible to multiple later).
 */
export async function getMerchantContractId(merchantId: string): Promise<string | null> {
  const { data } = await supabaseAdmin
    .from('contracts')
    .select('id')
    .eq('merchant_id', merchantId)
    .order('created_at', { ascending: false })
    .limit(1)
    .single();
  return data?.id ?? null;
}

/**
 * Retrieve relevant contract context for a natural-language query.
 * Used by: chat (per message), outreach (payment/agreement terms), pay page, dashboard citations.
 */
export async function getRagContext(
  merchantId: string,
  query: string,
  options: RagOptions = {}
): Promise<{ context: string; chunks: string[] }> {
  const opts = { ...DEFAULT_OPTIONS, ...options };
  const contractId = await getMerchantContractId(merchantId);
  if (!contractId) {
    const fallback = opts.fallbackContext ?? '';
    return { context: fallback, chunks: [] };
  }

  try {
    const queryEmbedding = await generateEmbedding(query);
    if (!queryEmbedding || queryEmbedding.length === 0) {
      return { context: opts.fallbackContext ?? '', chunks: [] };
    }

    const { data: matches, error } = await supabaseAdmin.rpc('match_contract_embeddings', {
      query_embedding: queryEmbedding,
      match_threshold: opts.matchThreshold,
      match_count: opts.matchCount,
      p_contract_id: contractId,
    });

    if (error || !matches || (matches as unknown[]).length === 0) {
      return { context: opts.fallbackContext ?? '', chunks: [] };
    }

    const chunks = (matches as Array<{ content: string }>).map((m) => m.content).filter(Boolean);
    let context = chunks.join('\n---\n');
    if (opts.maxContextChars != null && context.length > opts.maxContextChars) {
      context = context.slice(0, opts.maxContextChars).trim();
      const lastSpace = context.lastIndexOf(' ');
      if (lastSpace > opts.maxContextChars * 0.7) context = context.slice(0, lastSpace);
      context += '…';
    }
    if (opts.fallbackContext && context.length === 0) context = opts.fallbackContext;
    return { context, chunks };
  } catch (e) {
    console.error('[RAG] getRagContext failed', e);
    return { context: opts.fallbackContext ?? '', chunks: [] };
  }
}

/** One-liner for emails/pay page: "According to your agreement…" (single best chunk, capped). */
export async function getRagSnippet(
  merchantId: string,
  query: string,
  maxChars = 280
): Promise<string> {
  const { context } = await getRagContext(merchantId, query, {
    matchCount: 1,
    matchThreshold: 0.45,
    maxContextChars: maxChars,
  });
  if (!context.trim()) return '';
  return context.trim();
}

/** Query presets for different user journeys (consistent, tunable). */
export const RAG_QUERIES = {
  /** Debtor chat: use the actual last message for relevance. */
  chat: (lastMessage: string) => lastMessage,
  /** Outreach: payment terms, due date, agreement. */
  outreach: 'payment terms due date late fees agreement obligation',
  /** Pay page: short authority line. */
  payPage: 'payment obligation agreement terms balance due',
  /** Dashboard: suggested citations for operator. */
  dashboardSuggest: 'payment terms settlement late fees contact obligation',
} as const;
