'use client';

import { useTranslations } from 'next-intl';
import { ReactNode } from 'react';
import { BarChart3 } from 'lucide-react';

interface Props {
  children: ReactNode;
}

/** Single common region for sidebar content (Laws of UX: Chunking, Law of Common Region). */
export default function InsightsPanel({ children }: Props) {
  const t = useTranslations('Dashboard');

  return (
    <section aria-labelledby="insights-heading" className="space-y-4">
      <div className="flex items-center gap-2">
        <div className="flex h-8 w-8 shrink-0 items-center justify-center rounded-lg bg-base-300/50 text-base-content/50">
          <BarChart3 className="h-4 w-4" />
        </div>
        <h2 id="insights-heading" className="text-sm font-bold uppercase tracking-wider text-base-content/60">
          {t('insights')}
        </h2>
      </div>
      <div className="space-y-4">{children}</div>
    </section>
  );
}
