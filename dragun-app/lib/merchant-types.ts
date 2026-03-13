/** Merchant row as returned from Supabase join (e.g. debtor.merchant). */
export interface MerchantBasic {
  name: string;
  email?: string;
}

/** Merchant fields required for chat system prompt and RAG. */
export interface MerchantForChat {
  id: string;
  name: string;
  strictness_level: number;
  settlement_floor: number;
}
