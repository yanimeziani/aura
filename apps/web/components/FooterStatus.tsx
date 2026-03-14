'use client';

import { useEffect, useState } from 'react';
import { useTranslations } from 'next-intl';

type Status = 'loading' | 'operational' | 'degraded';

export default function FooterStatus() {
  const t = useTranslations('Footer');
  const [status, setStatus] = useState<Status>('loading');

  useEffect(() => {
    let cancelled = false;
    fetch('/api/health')
      .then((res) => {
        if (cancelled) return;
        setStatus(res.ok ? 'operational' : 'degraded');
      })
      .catch(() => {
        if (!cancelled) setStatus('degraded');
      });
    return () => {
      cancelled = true;
    };
  }, []);

  if (status === 'loading') {
    return (
      <div className="mt-8 rounded-xl border border-base-300/50 bg-base-100 p-4">
        <p className="text-[10px] font-bold uppercase tracking-wider text-base-content/30 mb-1">
          {t('statusLabel')}
        </p>
        <div className="flex items-center gap-2">
          <span className="relative flex h-2 w-2">
            <span className="relative inline-flex h-2 w-2 rounded-full bg-base-content/30" />
          </span>
          <span className="text-xs font-medium text-base-content/50">{t('statusChecking')}</span>
        </div>
      </div>
    );
  }

  if (status === 'degraded') {
    return (
      <div className="mt-8 rounded-xl border border-base-300/50 bg-base-100 p-4">
        <p className="text-[10px] font-bold uppercase tracking-wider text-base-content/30 mb-1">
          {t('statusLabel')}
        </p>
        <div className="flex items-center gap-2">
          <span className="relative flex h-2 w-2">
            <span className="relative inline-flex h-2 w-2 rounded-full bg-error" />
          </span>
          <span className="text-xs font-medium text-error">{t('statusDegraded')}</span>
        </div>
      </div>
    );
  }

  return (
    <div className="mt-8 rounded-xl border border-base-300/50 bg-base-100 p-4">
      <p className="text-[10px] font-bold uppercase tracking-wider text-base-content/30 mb-1">
        {t('statusLabel')}
      </p>
      <div className="flex items-center gap-2">
        <span className="relative flex h-2 w-2">
          <span className="absolute inline-flex h-full w-full animate-ping rounded-full bg-success opacity-75" />
          <span className="relative inline-flex h-2 w-2 rounded-full bg-success" />
        </span>
        <span className="text-xs font-medium text-success">{t('allOperational')}</span>
      </div>
    </div>
  );
}
