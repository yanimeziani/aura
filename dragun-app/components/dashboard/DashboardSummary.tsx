'use client';

import { useState } from 'react';
import { useTranslations } from 'next-intl';
import { BadgeDollarSign, TrendingUp, Target, ChevronDown, ChevronUp } from 'lucide-react';

interface PrimaryStat {
  label: string;
  value: string;
  sub: string;
  icon: 'outstanding' | 'recovered' | 'today';
}

interface SecondaryStat {
  label: string;
  value: string;
}

interface Props {
  primary: PrimaryStat[];
  secondary?: SecondaryStat[];
}

const ICONS = {
  outstanding: BadgeDollarSign,
  recovered: TrendingUp,
  today: Target,
};

export default function DashboardSummary({ primary, secondary = [] }: Props) {
  const t = useTranslations('Dashboard');
  const [expanded, setExpanded] = useState(false);
  const hasMore = secondary.length > 0;

  return (
    <div className="card bg-base-200/50 border border-base-300/50 shadow-warm overflow-hidden">
      <div className="card-body p-0">
        <div className="grid grid-cols-3 divide-x divide-base-300/50 min-w-0">
          {primary.map((stat) => {
            const Icon = ICONS[stat.icon];
            return (
              <div
                key={stat.label}
                className="px-2 py-4 sm:px-4 sm:py-5 md:px-5 md:py-6 flex flex-col min-w-0"
              >
                <div className="flex items-center gap-1.5 sm:gap-2 min-w-0">
                  <div className="flex h-7 w-7 sm:h-8 sm:w-8 shrink-0 items-center justify-center rounded-lg bg-base-300/50 text-base-content/50">
                    <Icon className="h-3.5 w-3.5 sm:h-4 sm:w-4" />
                  </div>
                  <p className="text-[10px] sm:text-[11px] font-semibold uppercase tracking-wider text-base-content/50 truncate">
                    {stat.label}
                  </p>
                </div>
                <p className="mt-1.5 sm:mt-2 text-lg sm:text-xl md:text-2xl font-bold tracking-tight truncate">
                  {stat.value}
                </p>
                <p className="mt-0.5 text-[10px] sm:text-[11px] text-base-content/40 truncate">
                  {stat.sub}
                </p>
              </div>
            );
          })}
        </div>

        {hasMore && (
          <>
            <div className="border-t border-base-300/50">
              <button
                type="button"
                onClick={() => setExpanded((e) => !e)}
                className="flex w-full items-center justify-center gap-1.5 py-3 text-[11px] font-semibold uppercase tracking-wider text-base-content/50 hover:bg-base-300/30 transition-colors"
                aria-expanded={expanded}
              >
                {expanded ? (
                  <>
                    <ChevronUp className="h-3.5 w-3.5" />
                    {t('less')}
                  </>
                ) : (
                  <>
                    <ChevronDown className="h-3.5 w-3.5" />
                    {t('moreMetrics')}
                  </>
                )}
              </button>
            </div>
            {expanded && (
              <div className="border-t border-base-300/50 px-4 py-4 sm:px-5 grid grid-cols-2 sm:grid-cols-3 gap-3 bg-base-300/20">
                {secondary.map((s) => (
                  <div key={s.label} className="flex justify-between items-baseline gap-2">
                    <span className="text-[11px] text-base-content/50 truncate">{s.label}</span>
                    <span className="text-sm font-semibold tabular-nums shrink-0">{s.value}</span>
                  </div>
                ))}
              </div>
            )}
          </>
        )}
      </div>
    </div>
  );
}
