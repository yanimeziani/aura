'use client';

import { useState, useRef, useEffect } from 'react';
import { useTranslations } from 'next-intl';
import { Filter, Download, ChevronDown, FileDown } from 'lucide-react';
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
  const [filterOpen, setFilterOpen] = useState(false);
  const [exportOpen, setExportOpen] = useState(false);
  const filterRef = useRef<HTMLDivElement>(null);
  const exportRef = useRef<HTMLDivElement>(null);

  useEffect(() => {
    function closeFilter(e: MouseEvent) {
      if (filterRef.current && !filterRef.current.contains(e.target as Node))
        setFilterOpen(false);
    }
    function closeExport(e: MouseEvent) {
      if (exportRef.current && !exportRef.current.contains(e.target as Node))
        setExportOpen(false);
    }
    document.addEventListener('mousedown', closeFilter);
    document.addEventListener('mousedown', closeExport);
    return () => {
      document.removeEventListener('mousedown', closeFilter);
      document.removeEventListener('mousedown', closeExport);
    };
  }, []);

  return (
    <div className="flex flex-wrap items-center gap-2">
      <div ref={filterRef} className="relative">
        <button
          type="button"
          onClick={() => setFilterOpen((o) => !o)}
          className="btn btn-ghost btn-sm gap-1.5 min-h-11 border border-base-300/60"
          aria-expanded={filterOpen}
          aria-haspopup="true"
        >
          <Filter className="h-3.5 w-3.5" />
          <span>{t('filter')}</span>
          <ChevronDown className={`h-3.5 w-3.5 transition-transform ${filterOpen ? 'rotate-180' : ''}`} />
        </button>
        {filterOpen && (
          <div className="absolute right-0 z-40 mt-1.5 w-64 rounded-xl border border-base-300 bg-base-200 p-4 shadow-xl">
            <form method="get" className="space-y-3">
              <input type="hidden" name="force_dashboard" value="true" />
              <label className="block">
                <span className="text-[11px] font-semibold uppercase tracking-wider text-base-content/50">{t('allStatus')}</span>
                <select
                  name="status"
                  defaultValue={statusFilter}
                  className="select select-bordered select-sm w-full mt-1"
                >
                  <option value="all">{t('allStatus')}</option>
                  {COLLECTION_STATUSES.map((s) => (
                    <option key={s} value={s}>{s.replace(/_/g, ' ')}</option>
                  ))}
                </select>
              </label>
              <label className="block">
                <span className="text-[11px] font-semibold uppercase tracking-wider text-base-content/50">Overdue</span>
                <select
                  name="overdue"
                  defaultValue={overdueFilter}
                  className="select select-bordered select-sm w-full mt-1"
                >
                  <option value="all">{t('allOverdue')}</option>
                  <option value="0_30">0–30d</option>
                  <option value="31_60">31–60d</option>
                  <option value="61_plus">61+d</option>
                </select>
              </label>
              <label className="block">
                <span className="text-[11px] font-semibold uppercase tracking-wider text-base-content/50">Amount</span>
                <select
                  name="amount"
                  defaultValue={amountFilter}
                  className="select select-bordered select-sm w-full mt-1"
                >
                  <option value="all">{t('allAmount')}</option>
                  <option value="lt_200">&lt;200</option>
                  <option value="200_999">200–999</option>
                  <option value="1000_plus">1000+</option>
                </select>
              </label>
              <label className="block">
                <span className="text-[11px] font-semibold uppercase tracking-wider text-base-content/50">Sort</span>
                <select
                  name="sort"
                  defaultValue={sortBy}
                  className="select select-bordered select-sm w-full mt-1"
                >
                  <option value="score_desc">{t('sortScore')}</option>
                  <option value="amount_desc">{t('sortAmount')}</option>
                  <option value="overdue_desc">{t('sortOverdue')}</option>
                  <option value="created_desc">{t('sortNewest')}</option>
                </select>
              </label>
              <button type="submit" className="btn btn-primary btn-sm w-full">
                {t('apply')}
              </button>
            </form>
          </div>
        )}
      </div>

      <div ref={exportRef} className="relative">
        <button
          type="button"
          onClick={() => setExportOpen((o) => !o)}
          className="btn btn-ghost btn-sm gap-1.5 min-h-11 border border-base-300/60"
          aria-expanded={exportOpen}
          aria-haspopup="true"
        >
          <FileDown className="h-3.5 w-3.5" />
          <span className="hidden sm:inline">{t('export')}</span>
          <ChevronDown className={`h-3.5 w-3.5 transition-transform ${exportOpen ? 'rotate-180' : ''}`} />
        </button>
        {exportOpen && (
          <div className="absolute right-0 z-40 mt-1.5 w-52 rounded-xl border border-base-300 bg-base-200 py-1 shadow-xl">
            <a
              href="/api/recovery/export"
              download
              rel="noopener noreferrer"
              className="flex items-center gap-2 px-4 py-2.5 text-sm hover:bg-base-300/50 transition-colors"
              title={t('exportCsvDesc')}
            >
              <Download className="h-3.5 w-3.5" />
              {t('exportCsv')}
            </a>
            <a
              href="/api/recovery/audit-export"
              download
              rel="noopener noreferrer"
              className="flex items-center gap-2 px-4 py-2.5 text-sm hover:bg-base-300/50 transition-colors"
              title={t('exportAuditDesc')}
            >
              <Download className="h-3.5 w-3.5" />
              {t('exportAudit')}
            </a>
          </div>
        )}
      </div>

      <ImportDebtors />
    </div>
  );
}
