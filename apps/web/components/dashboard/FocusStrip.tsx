'use client';

import { useTranslations } from 'next-intl';
import { Link } from '@/i18n/navigation';
import { ArrowRight, Target } from 'lucide-react';
import type { DebtorRow } from './dashboard-types';
import { getNextAction } from '@/lib/next-action';

interface Props {
  nextDebtor: DebtorRow | null;
  actionableCount: number;
}

export default function FocusStrip({ nextDebtor, actionableCount }: Props) {
  const t = useTranslations('Dashboard');

  if (actionableCount === 0) return null;

  const nextAction = nextDebtor ? getNextAction(nextDebtor) : null;
  const actionLabel =
    nextAction?.key === 'send_outreach'
      ? t('focusContact')
      : nextAction?.key === 'follow_up'
        ? t('focusFollowUp')
        : t('focusReview');

  return (
    <div className="rounded-xl border border-primary/20 bg-primary/5 px-3 py-3 sm:px-5 sm:py-4 flex flex-col sm:flex-row flex-wrap items-stretch sm:items-center justify-between gap-3">
      <div className="flex items-center gap-3 min-w-0 flex-1">
        <div className="flex h-9 w-9 sm:h-10 sm:w-10 shrink-0 items-center justify-center rounded-lg bg-primary/10">
          <Target className="h-4 w-4 sm:h-5 sm:w-5 text-primary" />
        </div>
        <div className="min-w-0 flex-1">
          <p className="text-[11px] font-semibold uppercase tracking-wider text-base-content/50">
            {t('focusToday')}
          </p>
          <p className="font-semibold truncate text-sm sm:text-base">
            {nextDebtor
              ? `${nextDebtor.name} · ${nextDebtor.currency} ${nextDebtor.total_debt.toLocaleString()}`
              : t('focusCount', { count: actionableCount })}
          </p>
        </div>
      </div>
      {nextDebtor && (
        <Link
          href={`#debtor-${nextDebtor.id}`}
          className="btn btn-primary btn-sm gap-1.5 shrink-0 w-full sm:w-auto min-h-[44px] touch-manipulation justify-center"
        >
          {actionLabel}
          <ArrowRight className="h-3.5 w-3.5" />
        </Link>
      )}
    </div>
  );
}
