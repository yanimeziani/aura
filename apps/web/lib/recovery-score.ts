import type { DebtorRow } from '@/components/dashboard/dashboard-types';

export function getRecoveryScore(d: DebtorRow): number {
  const amountScore = Math.min(60, d.total_debt / 50);
  const overdueDays = Math.max(0, d.days_overdue ?? 0);
  const overdueScore = Math.min(30, overdueDays * 0.75);
  const contactPenalty = d.last_contacted ? 10 : 0;
  const statusBoost =
    d.status === 'promise_to_pay' ? 8 : d.status === 'escalated' ? 12 : 0;
  return Math.max(
    0,
    Math.round(amountScore + overdueScore + statusBoost - contactPenalty),
  );
}
