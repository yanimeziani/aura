'use client';

import { useTranslations } from 'next-intl';
import { TrendingUp, Activity, PieChart } from 'lucide-react';
import type { RecoveryActionRow } from './dashboard-types';

interface Props {
  recoveryRate: number;
  totalPortfolio: number;
  totalRecovered: number;
  statusCounts: Record<string, number>;
  recentActions: RecoveryActionRow[];
  debtorNames: Record<string, string>;
}

const STATUS_COLORS: Record<string, string> = {
  pending: 'bg-base-content/20',
  contacted: 'bg-primary',
  promise_to_pay: 'bg-info',
  no_answer: 'bg-base-content/30',
  escalated: 'bg-warning',
  paid: 'bg-success',
};

const ACTION_ICONS: Record<string, string> = {
  status_update: 'badge-ghost',
  call: 'badge-primary',
  sms: 'badge-info',
  follow_up_scheduled: 'badge-warning',
  email_initial: 'badge-primary',
  email_follow_up: 'badge-secondary',
};

function timeAgo(dateStr: string): string {
  const diff = Date.now() - new Date(dateStr).getTime();
  const mins = Math.floor(diff / 60000);
  if (mins < 1) return 'just now';
  if (mins < 60) return `${mins}m ago`;
  const hrs = Math.floor(mins / 60);
  if (hrs < 24) return `${hrs}h ago`;
  const days = Math.floor(hrs / 24);
  return `${days}d ago`;
}

export default function RecoveryAnalytics({
  recoveryRate,
  totalPortfolio,
  totalRecovered,
  statusCounts,
  recentActions,
  debtorNames,
}: Props) {
  const t = useTranslations('Dashboard');
  const totalDebtors = Object.values(statusCounts).reduce((a, b) => a + b, 0);

  const orderedStatuses = ['paid', 'promise_to_pay', 'contacted', 'pending', 'no_answer', 'escalated'];
  const statusEntries = orderedStatuses
    .filter((s) => (statusCounts[s] ?? 0) > 0)
    .map((s) => ({
      status: s,
      count: statusCounts[s] ?? 0,
      pct: totalDebtors > 0 ? Math.round(((statusCounts[s] ?? 0) / totalDebtors) * 100) : 0,
      color: STATUS_COLORS[s] || 'bg-base-content/20',
    }));

  return (
    <div className="space-y-6">
      {/* Recovery Rate */}
      <div className="card bg-base-200/50 border border-base-300/50 shadow-warm">
        <div className="card-body p-5">
          <div className="flex items-center gap-3 mb-4">
            <div className="flex h-9 w-9 items-center justify-center rounded-lg bg-success/10">
              <TrendingUp className="h-4 w-4 text-success" />
            </div>
            <h2 className="font-bold">{t('analyticsRecoveryRate')}</h2>
          </div>

          <div className="flex items-end gap-2 mb-3">
            <span className="text-4xl font-bold tracking-tight">{recoveryRate}%</span>
            <span className="text-sm text-base-content/40 pb-1">{t('analyticsOfPortfolio')}</span>
          </div>

          <div className="w-full bg-base-300/50 rounded-full h-3 overflow-hidden">
            <div
              className="bg-success h-3 rounded-full transition-all duration-700"
              style={{ width: `${Math.min(100, recoveryRate)}%` }}
            />
          </div>

          <div className="flex justify-between mt-2 text-xs text-base-content/40">
            <span>${totalRecovered.toLocaleString()} {t('analyticsRecovered')}</span>
            <span>${totalPortfolio.toLocaleString()} {t('analyticsTotal')}</span>
          </div>
        </div>
      </div>

      {/* Status Distribution */}
      <div className="card bg-base-200/50 border border-base-300/50 shadow-warm">
        <div className="card-body p-5">
          <div className="flex items-center gap-3 mb-4">
            <div className="flex h-9 w-9 items-center justify-center rounded-lg bg-base-300/50">
              <PieChart className="h-4 w-4 text-base-content/60" />
            </div>
            <h2 className="font-bold">{t('analyticsStatusBreakdown')}</h2>
          </div>

          {/* Stacked bar */}
          <div className="w-full flex h-4 rounded-full overflow-hidden gap-0.5 mb-4">
            {statusEntries.map((s) => (
              <div
                key={s.status}
                className={`${s.color} transition-all duration-500`}
                style={{ width: `${s.pct}%`, minWidth: s.pct > 0 ? '4px' : '0' }}
                title={`${s.status.replace(/_/g, ' ')}: ${s.count}`}
              />
            ))}
          </div>

          <div className="space-y-2">
            {statusEntries.map((s) => (
              <div key={s.status} className="flex items-center justify-between">
                <div className="flex items-center gap-2">
                  <div className={`h-2.5 w-2.5 rounded-full ${s.color}`} />
                  <span className="text-sm capitalize">{s.status.replace(/_/g, ' ')}</span>
                </div>
                <div className="flex items-center gap-2">
                  <span className="text-sm font-bold tabular-nums">{s.count}</span>
                  <span className="text-xs text-base-content/40 tabular-nums w-8 text-right">{s.pct}%</span>
                </div>
              </div>
            ))}
          </div>
        </div>
      </div>

      {/* Recent Activity */}
      <div className="card bg-base-200/50 border border-base-300/50 shadow-warm">
        <div className="card-body p-5">
          <div className="flex items-center gap-3 mb-4">
            <div className="flex h-9 w-9 items-center justify-center rounded-lg bg-base-300/50">
              <Activity className="h-4 w-4 text-base-content/60" />
            </div>
            <h2 className="font-bold">{t('analyticsRecentActivity')}</h2>
          </div>

          {recentActions.length === 0 ? (
            <p className="text-sm text-base-content/40 text-center py-4">
              {t('analyticsNoActivity')}
            </p>
          ) : (
            <div className="space-y-2">
              {recentActions.map((action) => (
                <div
                  key={action.created_at + action.debtor_id}
                  className="flex items-start gap-3 rounded-lg bg-base-100 px-3 py-2.5 border border-base-300/30"
                >
                  <div className="mt-0.5">
                    <span className={`badge badge-xs ${ACTION_ICONS[action.action_type] || 'badge-ghost'}`} />
                  </div>
                  <div className="min-w-0 flex-1">
                    <p className="text-sm font-medium truncate">
                      {debtorNames[action.debtor_id] || action.debtor_id.slice(0, 8)}
                    </p>
                    <p className="text-[11px] text-base-content/40">
                      {action.action_type.replace(/_/g, ' ')} → {action.status_after.replace(/_/g, ' ')}
                      {action.note && (
                        <span className="ml-1 italic">· {action.note}</span>
                      )}
                    </p>
                  </div>
                  <span className="text-[10px] text-base-content/30 whitespace-nowrap shrink-0">
                    {timeAgo(action.created_at)}
                  </span>
                </div>
              ))}
            </div>
          )}
        </div>
      </div>
    </div>
  );
}
