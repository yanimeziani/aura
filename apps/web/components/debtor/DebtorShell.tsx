'use client';

import { useTranslations } from 'next-intl';
import { Lock } from 'lucide-react';

interface Props {
  children: React.ReactNode;
  merchantName?: string;
}

export default function DebtorShell({ children, merchantName }: Props) {
  const t = useTranslations('DebtorShell');

  return (
    <div data-theme="cupcake" className="min-h-screen bg-[#faf9f7] font-[Inter,system-ui,sans-serif] text-[#2d2d2d]">
      {children}
      <footer className="border-t border-[#e8e4df] bg-[#f5f3f0] px-6 py-5">
        <div className="mx-auto flex max-w-lg flex-col items-center gap-3 text-center">
          <div className="flex items-center gap-2 text-[#999]">
            <Lock className="h-3 w-3" />
            <span className="text-[11px] font-medium">
              {t('securedBy')}
            </span>
          </div>
          {merchantName && (
            <p className="text-[11px] text-[#b0a99f]">
              {t('onBehalfOf', { merchant: merchantName })}
              <br />
              {t('poweredBy')}
            </p>
          )}
        </div>
      </footer>
    </div>
  );
}
