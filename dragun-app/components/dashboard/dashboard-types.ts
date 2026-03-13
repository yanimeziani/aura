export type DebtorRow = {
  id: string;
  name: string;
  email: string;
  phone?: string | null;
  currency: string;
  total_debt: number;
  status: string;
  last_contacted: string | null;
  days_overdue?: number | null;
  created_at: string;
  /** Precomputed portal URL with token (set by server for client components) */
  portalChatUrl?: string;
};

export type RecoveryActionRow = {
  debtor_id: string;
  action_type: string;
  status_after: string;
  note: string | null;
  created_at: string;
};
