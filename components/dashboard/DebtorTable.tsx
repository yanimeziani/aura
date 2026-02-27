import { Link } from '@/i18n/navigation';
import { ArrowUpRight } from 'lucide-react';
import type { DebtorRow, RecoveryActionRow } from './dashboard-types';
import DebtorActionForm from './DebtorActionForm';

function getStatusBadge(status: string) {
  const map: Record<string, string> = {
    paid: 'badge-success',
    escalated: 'badge-warning',
    promise_to_pay: 'badge-info',
    contacted: 'badge-primary',
    no_answer: 'badge-ghost',
  };
  return map[status] ?? 'badge-ghost';
}

function getStatusLabel(status: string) {
  const map: Record<string, string> = {
    contacted: 'Contacted',
    promise_to_pay: 'Promise',
    no_answer: 'No Answer',
    escalated: 'Escalated',
    paid: 'Paid',
  };
  return map[status] ?? 'Pending';
}

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

interface Props {
  debtors: DebtorRow[];
  actionTimeline: Record<string, RecoveryActionRow[]>;
  handleRecoveryAction: (formData: FormData) => Promise<void>;
  t: (key: string) => string;
}

export default function DebtorTable({
  debtors,
  actionTimeline,
  handleRecoveryAction,
  t,
}: Props) {
  if (!debtors.length) {
    return (
      <div className="py-16 text-center">
        <div className="mx-auto mb-4 flex h-14 w-14 items-center justify-center rounded-full border-2 border-dashed border-base-300 text-base-content/30">
          <span className="text-2xl">+</span>
        </div>
        <p className="font-semibold">{t('noRecoveries')}</p>
        <p className="mt-1 text-sm text-base-content/50">{t('noRecoveriesHint')}</p>
      </div>
    );
  }

  return (
    <>
      {/* Mobile cards */}
      <div className="space-y-3 p-4 md:hidden">
        {debtors.map((d) => (
          <div
            key={d.id}
            className="card bg-base-100 border border-base-300/50 shadow-warm"
          >
            <div className="card-body p-4 gap-3">
              <div className="flex items-start justify-between">
                <div>
                  <p className="font-semibold text-sm">{d.name}</p>
                  <p className="text-xs text-base-content/50">{d.email}</p>
                </div>
                <span className={`badge badge-sm ${getStatusBadge(d.status)}`}>
                  {getStatusLabel(d.status)}
                </span>
              </div>

              <div className="flex items-center justify-between">
                <p className="font-bold">
                  {d.currency} {d.total_debt.toLocaleString()}
                </p>
                <p className="text-xs text-base-content/40">
                  {d.days_overdue ?? 0}d overdue
                </p>
              </div>

              {actionTimeline[d.id]?.[0] && (
                <p className="text-[11px] text-base-content/40">
                  Last: {actionTimeline[d.id][0].action_type} →{' '}
                  {actionTimeline[d.id][0].status_after}
                </p>
              )}

              <div className="flex items-center gap-2 pt-1">
                <DebtorActionForm
                  debtor={d}
                  handleRecoveryAction={handleRecoveryAction}
                />
                <Link
                  href={`/chat/${d.id}`}
                  className="btn btn-sm btn-primary btn-outline gap-1 ml-auto"
                >
                  {t('joinAI')}
                  <ArrowUpRight className="h-3.5 w-3.5" />
                </Link>
              </div>
            </div>
          </div>
        ))}
      </div>

      {/* Desktop table */}
      <div className="hidden overflow-x-auto md:block">
        <table className="table table-sm">
          <thead>
            <tr className="text-label">
              <th>{t('debtorDetails')}</th>
              <th>{t('exposure')}</th>
              <th>{t('agentStatus')}</th>
              <th className="text-right">{t('protocol')}</th>
            </tr>
          </thead>
          <tbody>
            {debtors.map((d) => (
              <tr key={d.id} className="hover">
                <td>
                  <div>
                    <p className="font-semibold text-sm">{d.name}</p>
                    <p className="text-xs text-base-content/50">{d.email}</p>
                    {actionTimeline[d.id]?.[0] && (
                      <p className="mt-0.5 text-[11px] text-base-content/40">
                        Last: {actionTimeline[d.id][0].action_type} →{' '}
                        {actionTimeline[d.id][0].status_after}
                      </p>
                    )}
                  </div>
                </td>
                <td>
                  <p className="font-bold text-sm">
                    {d.currency} {d.total_debt.toLocaleString()}
                  </p>
                  <p className="text-xs text-base-content/40">
                    {d.days_overdue ?? 0}d · score {getRecoveryScore(d)}
                  </p>
                </td>
                <td>
                  <span className={`badge badge-sm ${getStatusBadge(d.status)}`}>
                    {getStatusLabel(d.status)}
                  </span>
                </td>
                <td className="text-right">
                  <div className="flex items-center justify-end gap-2">
                    <DebtorActionForm
                      debtor={d}
                      handleRecoveryAction={handleRecoveryAction}
                    />
                    <Link
                      href={`/chat/${d.id}`}
                      className="btn btn-sm btn-primary btn-outline gap-1"
                    >
                      {t('joinAI')}
                      <ArrowUpRight className="h-3.5 w-3.5" />
                    </Link>
                  </div>
                </td>
              </tr>
            ))}
          </tbody>
        </table>
      </div>
    </>
  );
}
