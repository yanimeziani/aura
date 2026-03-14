'use client';

import { useTranslations } from 'next-intl';
import type { DebtorRow } from './dashboard-types';
import { getRecoveryScore } from '@/lib/recovery-score';

interface Props {
  debtors: DebtorRow[];
}

export default function TopDebtors({ debtors }: Props) {
  const t = useTranslations('Dashboard');
  return (
    <div className="card bg-base-200/50 border border-base-300/50 shadow-warm">
      <div className="card-body p-5">
        <div className="flex items-center justify-between mb-3">
          <h2 className="font-bold">{t('priorityQueue')}</h2>
          <span className="text-label">{t('topN', { count: 8 })}</span>
        </div>
        <div className="space-y-1.5">
          {debtors.slice(0, 8).map((d, idx) => (
            <div
              key={d.id}
              className="flex items-center justify-between rounded-lg bg-base-100 px-3 py-2 border border-base-300/30"
            >
              <div className="flex items-center gap-2.5 min-w-0">
                <span className="text-xs font-bold text-base-content/30 tabular-nums w-5 text-right shrink-0">
                  {idx + 1}
                </span>
                <div className="min-w-0">
                  <p className="text-sm font-semibold truncate">{d.name}</p>
                  <p className="text-[11px] text-base-content/40">
                    {d.currency} {d.total_debt.toLocaleString()} · {d.days_overdue ?? 0}d
                  </p>
                </div>
              </div>
              <div className="badge badge-ghost badge-sm font-bold tabular-nums">
                {getRecoveryScore(d)}
              </div>
            </div>
          ))}
        </div>
      </div>
    </div>
  );
}
