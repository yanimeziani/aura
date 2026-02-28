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
      <dialog ref={dialogRef} className="modal modal-bottom sm:modal-middle">
        <div className="modal-box overflow-hidden rounded-2xl border border-base-300 bg-base-200 p-0 shadow-xl">
          <div className="p-6">
            <div className="mb-6 flex items-center justify-between">
              <div className="flex items-center gap-3">
                <div className="flex h-11 w-11 items-center justify-center rounded-xl border border-base-300 bg-base-100">
                  <Plus className="h-5 w-5" />
                </div>
                <div>
                  <h3 className="text-lg font-semibold uppercase tracking-[0.12em]">{t('addDebtor')}</h3>
                  <p className="text-label">{t('createRecoveryCase')}</p>
                </div>
              </div>
              <button
                onClick={() => dialogRef.current?.close()}
                className="btn btn-ghost btn-circle btn-sm"
              >
                <X className="h-4 w-4" />
              </button>
            </div>

            <form ref={formRef} action={handleSubmit} className="space-y-4">
              <div className="space-y-2">
                <label className="text-label">{t('debtorName')}</label>
                <div className="relative">
                  <User className="absolute left-4 top-1/2 h-4 w-4 -translate-y-1/2 text-base-content/40" />
                  <input
                    name="name"
                    required
                    type="text"
                    placeholder="Jane Smith"
                    className="input input-bordered w-full pl-11 min-h-11"
                  />
                </div>
              </div>

              <div className="space-y-2">
                <label className="text-label">{t('debtorEmail')}</label>
                <div className="relative">
                  <Mail className="absolute left-4 top-1/2 h-4 w-4 -translate-y-1/2 text-base-content/40" />
                  <input
                    name="email"
                    required
                    type="email"
                    placeholder="jane@example.com"
                    className="input input-bordered w-full pl-11 min-h-11"
                  />
                </div>
              </div>

              <div className="grid grid-cols-2 gap-3">
                <div className="space-y-2">
                  <label className="text-label">{t('debtorDebt')}</label>
                  <div className="relative">
                    <DollarSign className="absolute left-4 top-1/2 h-4 w-4 -translate-y-1/2 text-base-content/40" />
                    <input
                      name="total_debt"
                      required
                      type="number"
                      min="0.01"
                      step="0.01"
                      placeholder="1500.00"
                      className="input input-bordered w-full pl-11 min-h-11"
                    />
                  </div>
                </div>
                <div className="space-y-2">
                  <label className="text-label">{t('debtorCurrency')}</label>
                  <select name="currency" className="select select-bordered w-full min-h-11">
                    <option value="USD">USD</option>
                    <option value="CAD">CAD</option>
                    <option value="EUR">EUR</option>
                    <option value="GBP">GBP</option>
                  </select>
                </div>
              </div>

              <div className="space-y-2">
                <label className="text-label">{t('daysOverdue')}</label>
                <input
                  name="days_overdue"
                  type="number"
                  min="0"
                  defaultValue="0"
                  className="input input-bordered w-full min-h-11"
                />
              </div>

              <button
                type="submit"
                disabled={isPending}
                className="btn btn-primary w-full mt-2 min-h-12"
              >
                {isPending ? <span className="loading loading-spinner loading-sm" /> : t('addDebtorSubmit')}
              </button>
            </form>
          </div>
        </div>

        <form method="dialog" className="modal-backdrop bg-base-100/80 backdrop-blur-sm">
          <button type="submit">close</button>
        </form>
      </dialog>

      <div className="fixed bottom-0 left-0 right-0 z-30 flex h-20 items-center justify-between border-t border-base-300 bg-base-100 px-6 pb-[env(safe-area-inset-bottom)] pl-[env(safe-area-inset-left)] pr-[env(safe-area-inset-right)] md:hidden">
        <a href="#top" className="flex min-h-11 min-w-11 flex-col items-center justify-center gap-1">
          <BarChart3 className="h-5 w-5" />
          <span className="text-[9px] font-semibold uppercase tracking-[0.16em]">{t('overview')}</span>
        </a>

        <button
          onClick={() => dialogRef.current?.showModal()}
          className="-translate-y-7 flex h-14 w-14 items-center justify-center rounded-full border-4 border-base-100 bg-primary text-primary-content shadow-lg active:scale-95"
          aria-label={t('addDebtor')}
        >
          <Plus className="h-6 w-6" />
        </button>

        <a href="#debtors" className="flex min-h-11 min-w-11 flex-col items-center justify-center gap-1 text-base-content/50 hover:text-base-content">
          <Users className="h-5 w-5" />
          <span className="text-[9px] font-semibold uppercase tracking-[0.16em]">{t('debtors')}</span>
        </a>
      </div>
    </>
  );
}
