'use client';

import { FileText } from 'lucide-react';
import { useTranslations } from 'next-intl';

interface Props {
  chunks: string[];
}

export default function SuggestedCitations({ chunks }: Props) {
  const t = useTranslations('Dashboard');
  if (!chunks?.length) return null;

  return (
    <div className="card bg-base-200/50 border border-base-300/50 shadow-warm overflow-hidden">
      <div className="flex items-center gap-3 border-b border-base-300/50 p-4">
        <div className="flex h-9 w-9 items-center justify-center rounded-lg bg-base-300/50">
          <FileText className="h-4 w-4 text-base-content/60" />
        </div>
        <div>
          <h2 className="font-bold text-sm">{t('suggestedCitations')}</h2>
          <p className="text-[11px] text-base-content/40">
            {t('suggestedCitationsHint')}
          </p>
        </div>
      </div>
      <div className="p-4 space-y-3">
        {chunks.slice(0, 3).map((text, i) => (
          <p
            key={i}
            className="text-xs text-base-content/70 leading-relaxed pl-3 border-l-2 border-primary/20"
          >
            {text.length > 180 ? `${text.slice(0, 180).trim()}…` : text}
          </p>
        ))}
      </div>
    </div>
  );
}
