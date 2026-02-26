'use client';

import { useState, useRef, useEffect } from 'react';
import { useTranslations } from 'next-intl';
import { Settings, FileText, LogOut, ChevronDown, ShieldCheck, Wallet } from 'lucide-react';
import { createStripeConnectAccount, createStripeLoginLink } from '@/app/actions/stripe-connect';
import { signOut } from '@/app/actions/auth';

interface Props {
  merchantName: string;
  hasStripeAccount: boolean;
  isOnboardingComplete: boolean;
  locale: string;
}

export default function DashboardTopNav({ merchantName, hasStripeAccount, isOnboardingComplete, locale }: Props) {
  const t = useTranslations('Dashboard');
  const [open, setOpen] = useState(false);
  const dropdownRef = useRef<HTMLDivElement>(null);

  // Close on outside click
  useEffect(() => {
    function onClickOutside(e: MouseEvent) {
      if (dropdownRef.current && !dropdownRef.current.contains(e.target as Node)) {
        setOpen(false);
      }
    }
    document.addEventListener('mousedown', onClickOutside);
    return () => document.removeEventListener('mousedown', onClickOutside);
  }, []);

  const initials = merchantName.substring(0, 2).toUpperCase();

  return (
    <div className="flex items-center gap-4">
      <div className="hidden sm:flex items-center px-4 py-1.5 rounded-full bg-white/[0.03] border border-white/5 text-white/40 text-[10px] font-bold tracking-[0.1em] uppercase">
        <div className="w-1.5 h-1.5 rounded-full bg-[#D4AF37] mr-2 animate-pulse" />
        {merchantName}
      </div>

      {/* Avatar + Dropdown */}
      <div ref={dropdownRef} className="relative">
        <button
          onClick={() => setOpen((v) => !v)}
          className="flex items-center gap-2 group outline-none"
          aria-haspopup="true"
          aria-expanded={open}
        >
          <div className="relative">
            <div className="absolute inset-0 bg-[#D4AF37]/20 blur-md rounded-full opacity-0 group-hover:opacity-100 transition-opacity" />
            <div className="bg-gradient-to-br from-[#1a1a1a] to-[#0a0a0a] border border-white/10 text-[#D4AF37] rounded-xl w-9 h-9 flex items-center justify-center transition-all group-hover:border-[#D4AF37]/30 relative z-10 shadow-2xl">
              <span className="text-[10px] font-black tracking-tighter">{initials}</span>
            </div>
          </div>
          <ChevronDown
            className={`w-3.5 h-3.5 text-white/30 transition-transform duration-300 ${open ? 'rotate-180 text-[#D4AF37]' : 'group-hover:text-white/60'}`}
          />
        </button>

        {open && (
          <div className="absolute right-0 mt-3 w-56 bg-[#0a0a0a]/95 backdrop-blur-3xl border border-white/10 rounded-2xl shadow-[0_30px_60px_-15px_rgba(0,0,0,0.8)] z-50 overflow-hidden py-1.5 animate-in fade-in zoom-in-95 duration-200">
            {/* Header */}
            <div className="px-5 py-4 border-b border-white/5 bg-white/[0.02]">
              <p className="text-[11px] font-black text-white tracking-widest uppercase mb-0.5">{merchantName}</p>
              <div className="flex items-center gap-1.5">
                <ShieldCheck className="w-3 h-3 text-[#D4AF37]" />
                <p className="text-[9px] text-white/30 font-bold tracking-[0.1em] uppercase">{t('merchant')}</p>
              </div>
            </div>

            {/* Items */}
            <div className="p-1.5 space-y-1">
              <a
                href="#settings"
                onClick={() => setOpen(false)}
                className="flex items-center gap-3 px-4 py-3 text-[11px] font-bold text-white/40 hover:text-[#D4AF37] hover:bg-white/[0.03] rounded-xl transition-all group/item tracking-widest uppercase"
              >
                <Settings className="w-4 h-4 group-hover/item:rotate-90 transition-transform duration-500" />
                <span>{t('agentParams')}</span>
              </a>

              <a
                href="#knowledge"
                onClick={() => setOpen(false)}
                className="flex items-center gap-3 px-4 py-3 text-[11px] font-bold text-white/40 hover:text-[#D4AF37] hover:bg-white/[0.03] rounded-xl transition-all group/item tracking-widest uppercase"
              >
                <FileText className="w-4 h-4 group-hover/item:translate-x-0.5 transition-transform" />
                <span>{t('ragContext')}</span>
              </a>

              {isOnboardingComplete ? (
                <form action={createStripeLoginLink}>
                  <button
                    className="w-full flex items-center gap-3 px-4 py-3 text-[11px] font-bold text-white/40 hover:text-blue-400 hover:bg-white/[0.03] rounded-xl transition-all group/item tracking-widest uppercase"
                  >
                    <Wallet className="w-4 h-4" />
                    <span>Stripe Dashboard</span>
                  </button>
                </form>
              ) : hasStripeAccount ? (
                <form action={createStripeConnectAccount}>
                  <input type="hidden" name="locale" value={locale} />
                  <button
                    className="w-full flex items-center gap-3 px-4 py-3 text-[11px] font-bold text-amber-500 hover:bg-white/[0.03] rounded-xl transition-all group/item tracking-widest uppercase"
                  >
                    <Wallet className="w-4 h-4" />
                    <span>Resume Setup</span>
                  </button>
                </form>
              ) : (
                <form action={createStripeConnectAccount}>
                  <input type="hidden" name="locale" value={locale} />
                  <button
                    className="w-full flex items-center gap-3 px-4 py-3 text-[11px] font-bold text-[#D4AF37] hover:text-white hover:bg-[#D4AF37]/10 rounded-xl transition-all group/item tracking-widest uppercase"
                  >
                    <Wallet className="w-4 h-4" />
                    <span>Connect Stripe</span>
                  </button>
                </form>
              )}

              <div className="h-px bg-white/5 mx-2 my-1" />

              <button
                onClick={async () => {
                  await signOut();
                  window.location.href = '/';
                }}
                className="w-full flex items-center gap-3 px-4 py-3 text-[11px] font-bold text-white/20 hover:text-white/60 hover:bg-white/[0.03] rounded-xl transition-all tracking-widest uppercase"
              >
                <LogOut className="w-4 h-4" />
                <span>{t('backToSite')}</span>
              </button>
            </div>
          </div>
        )}
      </div>
    </div>
  );
}
