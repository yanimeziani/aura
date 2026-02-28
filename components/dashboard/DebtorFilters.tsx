'use client';

import { useTranslations } from 'next-intl';
import { Download } from 'lucide-react';
import { COLLECTION_STATUSES } from '@/lib/recovery-types';
import ImportDebtors from './ImportDebtors';

interface Props {
  statusFilter: string;
  overdueFilter: string;
  amountFilter: string;
  sortBy: string;
}

export default function DebtorFilters({
  statusFilter,
  overdueFilter,
  amountFilter,
  sortBy,
}: Props) {
  const t = useTranslations('Dashboard');

  return (
    <div className="flex flex-col gap-3 sm:flex-row sm:flex-wrap sm:items-center sm:gap-4">
      <form method="get" className="flex flex-wrap items-center gap-2">
        <input type="hidden" name="force_dashboard" value="true" />
        <select
          name="status"
          defaultValue={statusFilter}
          className="select select-bordered select-sm"
        >
          <option value="all">{t('allStatus')}</option>
          {COLLECTION_STATUSES.map((s) => (
            <option key={s} value={s}>
              {s.replace(/_/g, ' ')}
            </option>
          ))}
        </select>
        <select
          name="overdue"
          defaultValue={overdueFilter}
          className="select select-bordered select-sm"
        >
          <option value="all">{t('allOverdue')}</option>
          <option value="0_30">0–30d</option>
          <option value="31_60">31–60d</option>
          <option value="61_plus">61+d</option>
        </select>
        <select
          name="amount"
          defaultValue={amountFilter}
          className="select select-bordered select-sm"
        >
          <option value="all">{t('allAmount')}</option>
          <option value="lt_200">&lt;200</option>
          <option value="200_999">200–999</option>
          <option value="1000_plus">1000+</option>
        </select>
        <select
          name="sort"
          defaultValue={sortBy}
          className="select select-bordered select-sm"
        >
          <option value="score_desc">{t('sortScore')}</option>
          <option value="amount_desc">{t('sortAmount')}</option>
          <option value="overdue_desc">{t('sortOverdue')}</option>
          <option value="created_desc">{t('sortNewest')}</option>
        </select>
        <button type="submit" className="btn btn-ghost btn-sm">
          {t('apply')}
        </button>
      </form>

      <div className="flex flex-wrap items-center gap-2 border-l border-base-300/60 pl-3 sm:pl-4">
        <span className="sr-only">{t('dataAndExport')}</span>
        <ImportDebtors />
        <a
          href="/api/recovery/export"
          className="btn btn-ghost btn-sm gap-1.5"
          download
          rel="noopener noreferrer"
          title={t('exportCsvDesc')}
        >
          <Download className="h-3.5 w-3.5 shrink-0" aria-hidden />
          {t('exportCsv')}
        </a>
        <a
          href="/api/recovery/audit-export"
          className="btn btn-ghost btn-sm gap-1.5"
          download
          rel="noopener noreferrer"
          title={t('exportAuditDesc')}
        >
          <Download className="h-3.5 w-3.5 shrink-0" aria-hidden />
          {t('exportAudit')}
        </a>
      </div>
    </div>
  );
}
