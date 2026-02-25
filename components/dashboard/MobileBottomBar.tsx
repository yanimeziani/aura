'use client';

import { useRef, useTransition } from 'react';
import { useTranslations } from 'next-intl';
import { BarChart3, Plus, Users, X, DollarSign, Mail, User } from 'lucide-react';

interface Props {
  addDebtorAction: (formData: FormData) => Promise<void>;
}

export default function MobileBottomBar({ addDebtorAction }: Props) {
  const t = useTranslations('Dashboard');
  const dialogRef = useRef<HTMLDialogElement>(null);
  const formRef = useRef<HTMLFormElement>(null);
  const [isPending, startTransition] = useTransition();

  function handleSubmit(formData: FormData) {
    startTransition(async () => {
      await addDebtorAction(formData);
      dialogRef.current?.close();
      formRef.current?.reset();
    });
  }

  return (
    <>
      {/* Add Debtor Modal */}
      <dialog ref={dialogRef} className="modal modal-bottom sm:modal-middle backdrop-blur-sm">
        <div className="modal-box bg-[#0a0a0a] border border-white/10 rounded-[2rem] p-0 overflow-hidden shadow-[0_30px_60px_-15px_rgba(0,0,0,0.9)]">
          <div className="p-8">
            <div className="flex items-center justify-between mb-8">
              <div className="flex items-center gap-3">
                <div className="w-12 h-12 bg-gradient-to-br from-[#1a1a1a] to-[#0a0a0a] border border-white/10 rounded-2xl flex items-center justify-center text-[#D4AF37] shadow-2xl relative group">
                  <div className="absolute inset-0 bg-[#D4AF37]/10 blur-xl opacity-0 group-hover:opacity-100 transition-opacity" />
                  <Plus className="w-6 h-6 relative z-10" />
                </div>
                <div>
                  <h3 className="font-black text-xl text-white tracking-tight leading-none mb-1">{t('addDebtor').toUpperCase()}</h3>
                  <p className="text-[10px] text-white/30 font-bold tracking-[0.2em] uppercase">INITIATE RECOVERY PROTOCOL</p>
                </div>
              </div>
              <button 
                onClick={() => dialogRef.current?.close()}
                className="w-10 h-10 rounded-full bg-white/[0.03] border border-white/5 flex items-center justify-center text-white/20 hover:text-white transition-colors"
              >
                <X className="w-5 h-5" />
              </button>
            </div>

            <form ref={formRef} action={handleSubmit} className="space-y-6">
              <div className="space-y-5">
                <div className="space-y-2">
                  <label className="text-[10px] uppercase tracking-[0.2em] text-white/30 font-bold ml-1">
                    {t('debtorName')}
                  </label>
                  <div className="relative group">
                    <div className="absolute left-4 top-1/2 -translate-y-1/2 text-white/20 group-focus-within:text-[#D4AF37] transition-colors">
                      <User className="w-4 h-4" />
                    </div>
                    <input
                      name="name"
                      required
                      type="text"
                      placeholder="Jane Smith"
                      className="w-full bg-white/[0.03] border border-white/5 text-white placeholder:text-white/10 text-sm rounded-2xl py-4 pl-12 pr-4 outline-none focus:border-[#D4AF37]/30 transition-all font-medium"
                    />
                  </div>
                </div>

                <div className="space-y-2">
                  <label className="text-[10px] uppercase tracking-[0.2em] text-white/30 font-bold ml-1">
                    {t('debtorEmail')}
                  </label>
                  <div className="relative group">
                    <div className="absolute left-4 top-1/2 -translate-y-1/2 text-white/20 group-focus-within:text-[#D4AF37] transition-colors">
                      <Mail className="w-4 h-4" />
                    </div>
                    <input
                      name="email"
                      required
                      type="email"
                      placeholder="jane@example.com"
                      className="w-full bg-white/[0.03] border border-white/5 text-white placeholder:text-white/10 text-sm rounded-2xl py-4 pl-12 pr-4 outline-none focus:border-[#D4AF37]/30 transition-all font-medium"
                    />
                  </div>
                </div>

                <div className="grid grid-cols-2 gap-4">
                  <div className="space-y-2">
                    <label className="text-[10px] uppercase tracking-[0.2em] text-white/30 font-bold ml-1">
                      {t('debtorDebt')}
                    </label>
                    <div className="relative group">
                      <div className="absolute left-4 top-1/2 -translate-y-1/2 text-white/20 group-focus-within:text-[#D4AF37] transition-colors">
                        <DollarSign className="w-4 h-4" />
                      </div>
                      <input
                        name="total_debt"
                        required
                        type="number"
                        min="0.01"
                        step="0.01"
                        placeholder="1500.00"
                        className="w-full bg-white/[0.03] border border-white/5 text-white placeholder:text-white/10 text-sm rounded-2xl py-4 pl-12 pr-4 outline-none focus:border-[#D4AF37]/30 transition-all font-medium"
                      />
                    </div>
                  </div>

                  <div className="space-y-2">
                    <label className="text-[10px] uppercase tracking-[0.2em] text-white/30 font-bold ml-1">
                      {t('debtorCurrency')}
                    </label>
                    <select
                      name="currency"
                      className="w-full h-[54px] bg-white/[0.03] border border-white/5 text-white text-sm rounded-2xl px-4 outline-none focus:border-[#D4AF37]/30 transition-all font-bold appearance-none cursor-pointer"
                    >
                      <option value="USD" className="bg-[#0a0a0a]">USD</option>
                      <option value="CAD" className="bg-[#0a0a0a]">CAD</option>
                    </select>
                  </div>
                </div>
              </div>

              <div className="flex gap-4 pt-4">
                <button
                  type="submit"
                  disabled={isPending}
                  className="flex-1 bg-white text-black hover:bg-[#D4AF37] hover:text-black font-black text-xs py-4 rounded-2xl transition-all active:scale-[0.98] disabled:opacity-50 disabled:cursor-not-allowed shadow-xl uppercase tracking-widest flex items-center justify-center gap-2"
                >
                  {isPending ? <span className="loading loading-spinner loading-xs" /> : (
                    <>
                      {t('addDebtorSubmit').toUpperCase()}
                    </>
                  )}
                </button>
              </div>
            </form>
          </div>
        </div>

        {/* Click outside to close */}
        <form method="dialog" className="modal-backdrop bg-black/80 backdrop-blur-md">
          <button type="submit">close</button>
        </form>
      </dialog>

      {/* Bottom Nav Bar */}
      <div className="fixed bottom-0 left-0 right-0 md:hidden w-full max-w-[100vw] bg-[#0a0a0a]/80 backdrop-blur-3xl border-t border-white/5 z-30 px-6 flex justify-between items-center h-20 shadow-[0_-20px_50px_rgba(0,0,0,0.8)] pb-[env(safe-area-inset-bottom)] pl-[env(safe-area-inset-left)] pr-[env(safe-area-inset-right)]">
        {/* Overview */}
        <a
          href="#top"
          className="flex flex-col items-center gap-1.5 text-[#D4AF37]"
        >
          <BarChart3 className="w-5 h-5" />
          <span className="text-[9px] font-black uppercase tracking-[0.2em]">{t('overview')}</span>
        </a>

        {/* Add Debtor — refined floating button */}
        <button
          onClick={() => dialogRef.current?.showModal()}
          className="w-16 h-16 bg-white text-black rounded-full flex items-center justify-center shadow-[0_10px_30px_rgba(255,255,255,0.1)] -translate-y-8 border-[6px] border-[#0a0a0a] transition-all active:scale-90 hover:bg-[#D4AF37]"
          aria-label={t('addDebtor')}
        >
          <Plus className="w-7 h-7" />
        </button>

        {/* Debtors */}
        <a
          href="#debtors"
          className="flex flex-col items-center gap-1.5 text-white/20 hover:text-white transition-colors"
        >
          <Users className="w-5 h-5" />
          <span className="text-[9px] font-black uppercase tracking-[0.2em]">{t('debtors')}</span>
        </a>
      </div>
    </>
  );
}
