'use client';

import { useState, useRef, useEffect } from 'react';
import { useTranslations } from 'next-intl';
import { Settings, FileText, LogOut, ChevronDown, ShieldCheck, Wallet } from 'lucide-react';
import { createStripeConnectAccount, createStripeLoginLink } from '@/app/actions/stripe-connect';
import { signOut } from '@/app/actions/auth';
import SettingsModal from '@/components/dashboard/SettingsModal';
import KnowledgeModal from '@/components/dashboard/KnowledgeModal';

interface MerchantForSettings {
  name: string;
  strictness_level: number;
  settlement_floor: number;
  data_retention_days?: number | null;
  currency_preference?: string | null;
  phone?: string | null;
}

interface Props {
  merchantName: string;
  hasStripeAccount: boolean;
  isOnboardingComplete: boolean;
  locale: string;
  merchant?: MerchantForSettings | null;
  contract?: { file_name: string } | null;
}

export default function DashboardTopNav({
  merchantName,
  hasStripeAccount,
  isOnboardingComplete,
  locale,
  merchant = null,
  contract = null,
}: Props) {
  const t = useTranslations('Dashboard');
  const [open, setOpen] = useState(false);
  const [settingsOpen, setSettingsOpen] = useState(false);
  const [knowledgeOpen, setKnowledgeOpen] = useState(false);
  const dropdownRef = useRef<HTMLDivElement>(null);

  useEffect(() => {
    function onClickOutside(e: MouseEvent) {
      if (dropdownRef.current && !dropdownRef.current.contains(e.target as Node)) setOpen(false);
    }
    function onEscape(e: KeyboardEvent) {
      if (e.key === 'Escape') setOpen(false);
    }
    document.addEventListener('mousedown', onClickOutside);
    document.addEventListener('keydown', onEscape);
    return () => {
      document.removeEventListener('mousedown', onClickOutside);
      document.removeEventListener('keydown', onEscape);
    };
  }, []);

  const initials = merchantName.substring(0, 2).toUpperCase();

  return (
    <div className="flex items-center gap-3">
      <div className="hidden h-10 items-center rounded-full border border-base-300 bg-base-200 px-3 text-[10px] font-semibold uppercase tracking-[0.14em] text-base-content/60 sm:flex">
        <div className="mr-2 h-1.5 w-1.5 rounded-full bg-success" />
        {merchantName}
      </div>

      <div ref={dropdownRef} className="relative">
        <button
          onClick={() => setOpen((v) => !v)}
          className="group flex h-10 items-center gap-2 rounded-xl border border-base-300 bg-base-200 px-2 outline-none transition-colors hover:bg-base-300"
          aria-haspopup="true"
          aria-expanded={open}
          aria-label="Open account menu"
        >
          <div className="flex h-8 w-8 items-center justify-center rounded-lg border border-base-300 bg-base-100 text-[10px] font-black tracking-tight">
            {initials}
          </div>
          <ChevronDown className={`h-3.5 w-3.5 text-base-content/50 transition-transform ${open ? 'rotate-180' : ''}`} />
        </button>

        {open && (
          <div className="absolute right-0 z-50 mt-2 w-56 min-w-48 max-w-72 overflow-hidden rounded-2xl border border-base-300 bg-base-200 py-1 shadow-xl">
            <div className="border-b border-base-300 px-4 py-3">
              <p className="mb-1 text-[11px] font-semibold uppercase tracking-[0.12em]">{merchantName}</p>
              <div className="flex items-center gap-1.5">
                <ShieldCheck className="h-3.5 w-3.5 text-base-content/50" />
                <p className="text-[10px] font-medium uppercase tracking-[0.12em] text-base-content/50">{t('merchant')}</p>
              </div>
            </div>

            <div className="space-y-1 p-1.5">
              {merchant && (
                <button
                  type="button"
                  onClick={() => {
                    setOpen(false);
                    setSettingsOpen(true);
                  }}
                  className="flex min-h-11 w-full items-center gap-2 rounded-xl px-3 py-2.5 text-left text-[11px] font-semibold uppercase tracking-[0.12em] text-base-content/60 transition-colors hover:bg-base-300 hover:text-base-content"
                >
                  <Settings className="h-4 w-4" />
                  <span>{t('agentParams')}</span>
                </button>
              )}

              {contract !== undefined && (
                <button
                  type="button"
                  onClick={() => {
                    setOpen(false);
                    setKnowledgeOpen(true);
                  }}
                  className="flex min-h-11 w-full items-center gap-2 rounded-xl px-3 py-2.5 text-left text-[11px] font-semibold uppercase tracking-[0.12em] text-base-content/60 transition-colors hover:bg-base-300 hover:text-base-content"
                >
                  <FileText className="h-4 w-4" />
                  <span>{t('ragContext')}</span>
                </button>
              )}

              {isOnboardingComplete ? (
                <form action={createStripeLoginLink}>
                  <button className="flex min-h-11 w-full items-center gap-2 rounded-xl px-3 py-2.5 text-[11px] font-semibold uppercase tracking-[0.12em] text-base-content/60 transition-colors hover:bg-base-300 hover:text-base-content">
                    <Wallet className="h-4 w-4" />
                    <span>{t('stripeDashboard')}</span>
                  </button>
                </form>
              ) : hasStripeAccount ? (
                <form action={createStripeConnectAccount}>
                  <input type="hidden" name="locale" value={locale} />
                  <button className="flex min-h-11 w-full items-center gap-2 rounded-xl px-3 py-2.5 text-[11px] font-semibold uppercase tracking-[0.12em] text-base-content/60 transition-colors hover:bg-base-300 hover:text-base-content">
                    <Wallet className="h-4 w-4" />
                    <span>{t('resumeSetup')}</span>
                  </button>
                </form>
              ) : (
                <form action={createStripeConnectAccount}>
                  <input type="hidden" name="locale" value={locale} />
                  <button className="flex min-h-11 w-full items-center gap-2 rounded-xl px-3 py-2.5 text-[11px] font-semibold uppercase tracking-[0.12em] text-base-content transition-colors hover:bg-base-300">
                    <Wallet className="h-4 w-4" />
                    <span>{t('connectStripe')}</span>
                  </button>
                </form>
              )}

              <div className="my-1 h-px bg-base-300" />

              <button
                onClick={async () => {
                  await signOut();
                  window.location.href = '/';
                }}
                className="flex min-h-11 w-full items-center gap-2 rounded-xl px-3 py-2.5 text-[11px] font-semibold uppercase tracking-[0.12em] text-base-content/60 transition-colors hover:bg-base-300 hover:text-base-content"
              >
                <LogOut className="h-4 w-4" />
                <span>{t('backToSite')}</span>
              </button>
            </div>
          </div>
        )}
      </div>

      {merchant && (
        <SettingsModal
          open={settingsOpen}
          onClose={() => setSettingsOpen(false)}
          merchant={merchant}
        />
      )}
      {contract !== undefined && (
        <KnowledgeModal
          open={knowledgeOpen}
          onClose={() => setKnowledgeOpen(false)}
          contract={contract}
        />
      )}
    </div>
  );
}
