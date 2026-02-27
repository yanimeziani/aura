'use client';

import { Download } from 'lucide-react';
import { Link } from '@/i18n/navigation';
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
  return (
    <div className="flex flex-wrap items-center gap-2">
      <form method="get" className="flex flex-wrap items-center gap-2">
        <input type="hidden" name="force_dashboard" value="true" />
        <select
          name="status"
          defaultValue={statusFilter}
          className="select select-bordered select-xs"
        >
          <option value="all">All status</option>
          {COLLECTION_STATUSES.map((s) => (
            <option key={s} value={s}>
              {s.replace(/_/g, ' ')}
            </option>
          ))}
        </select>
        <select
          name="overdue"
          defaultValue={overdueFilter}
          className="select select-bordered select-xs"
        >
          <option value="all">All overdue</option>
          <option value="0_30">0–30d</option>
          <option value="31_60">31–60d</option>
          <option value="61_plus">61+d</option>
        </select>
        <select
          name="amount"
          defaultValue={amountFilter}
          className="select select-bordered select-xs"
        >
          <option value="all">All amount</option>
          <option value="lt_200">&lt;200</option>
          <option value="200_999">200–999</option>
          <option value="1000_plus">1000+</option>
        </select>
        <select
          name="sort"
          defaultValue={sortBy}
          className="select select-bordered select-xs"
        >
          <option value="score_desc">Score</option>
          <option value="amount_desc">Amount</option>
          <option value="overdue_desc">Overdue</option>
          <option value="created_desc">Newest</option>
        </select>
        <button className="btn btn-ghost btn-xs">Apply</button>
      </form>

      <div className="flex items-center gap-1.5">
        <ImportDebtors />
        <Link
          href="/api/recovery/export"
          prefetch={false}
          className="btn btn-ghost btn-xs gap-1"
        >
          <Download className="h-3 w-3" />
          CSV
        </Link>
        <Link
          href="/api/recovery/audit-export"
          prefetch={false}
          className="btn btn-ghost btn-xs gap-1"
        >
          <Download className="h-3 w-3" />
          Audit
        </Link>
      </div>
    </div>
  );
}
