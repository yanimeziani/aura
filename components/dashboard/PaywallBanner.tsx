'use client';

import { useTranslations } from 'next-intl';
import { Lock, Zap, ArrowRight } from 'lucide-react';
import type { PlanTier } from '@/lib/paywall';

interface Props {
  currentCount: number;
  limit: number;
  plan: PlanTier;
  subscribeAction: (formData: FormData) => Promise<void>;
}

export default function PaywallBanner({ currentCount, limit, plan, subscribeAction }: Props) {
  const t = useTranslations('Dashboard');
  const isAtLimit = currentCount >= limit;
  const nearLimit = currentCount >= limit - 1;

  if (!nearLimit && plan !== 'free') return null;

  return (
    <div className={`card ${isAtLimit ? 'border-error/40 bg-error/5' : 'border-warning/40 bg-warning/5'} shadow-sm`}>
      <div className="card-body p-5 sm:p-6">
        <div className="flex flex-col gap-4 md:flex-row md:items-center md:justify-between">
          <div className="flex items-start gap-4">
            <div className={`flex h-11 w-11 shrink-0 items-center justify-center rounded-xl ${
              isAtLimit ? 'bg-error/10 text-error' : 'bg-warning/10 text-warning'
            }`}>
              {isAtLimit ? <Lock className="h-5 w-5" /> : <Zap className="h-5 w-5" />}
            </div>
            <div>
              <h3 className="text-lg font-semibold">
                {isAtLimit ? t('limitReached') : t('approachingLimit')}
              </h3>
              <p className="mt-1 text-sm text-base-content/70">
                {isAtLimit
                  ? t('limitReachedDesc', { limit: String(limit), plan })
                  : t('approachingLimitDesc', { current: String(currentCount), limit: String(limit) })
                }
              </p>
            </div>
          </div>

          <div className="flex gap-2">
            <form action={subscribeAction}>
              <input type="hidden" name="plan" value="starter" />
              <button className="btn btn-primary gap-2 min-h-11 px-5 text-sm font-semibold uppercase tracking-[0.14em]">
                {t('upgradeToStarter')}
                <ArrowRight className="h-4 w-4" />
              </button>
            </form>
          </div>
        </div>

        <div className="mt-3 flex gap-6 text-xs text-base-content/50">
          <span>{t('fiftyDebtors')}</span>
          <span>{t('aiRecoveryAgent')}</span>
          <span>{t('pricePerMonth')}</span>
          <span>{t('cancelAnytime')}</span>
        </div>
      </div>
    </div>
  );
}
