'use client';

import { useActionState, useEffect } from 'react';
import { useTranslations } from 'next-intl';
import { Settings, Shield, X } from 'lucide-react';
import AccessibleModal from '@/components/ui/AccessibleModal';
import { updateMerchantSettingsFromForm } from '@/app/actions/merchant-settings';

const RETENTION_OPTIONS = [
  { value: 90, label: '90 days' },
  { value: 180, label: '180 days' },
  { value: 365, label: '1 year' },
  { value: 730, label: '2 years' },
  { value: 0, label: 'Indefinite' },
];

const CURRENCIES = [
  { value: 'CAD', label: 'CAD' },
  { value: 'USD', label: 'USD' },
  { value: 'EUR', label: 'EUR' },
  { value: 'GBP', label: 'GBP' },
];

interface Props {
  open: boolean;
  onClose: () => void;
  merchant: {
    name: string;
    strictness_level: number;
    settlement_floor: number;
    data_retention_days?: number | null;
    currency_preference?: string | null;
    phone?: string | null;
  };
}

export default function SettingsModal({ open, onClose, merchant }: Props) {
  const t = useTranslations('Dashboard');
  const [state, formAction, isPending] = useActionState(updateMerchantSettingsFromForm, {
    success: false,
    error: undefined as string | undefined,
  });

  useEffect(() => {
    if (state.success) onClose();
  }, [state.success, onClose]);

  return (
    <AccessibleModal
      open={open}
      onClose={onClose}
      titleId="settings-modal-title"
      className="max-w-md"
    >
      <div className="flex items-center justify-between border-b border-base-300/50 px-4 pt-4 pb-4 sm:px-6 sm:pt-6">
        <div className="flex items-center gap-3">
          <div className="flex h-9 w-9 items-center justify-center rounded-lg bg-base-300/50">
            <Settings className="h-4 w-4 text-base-content/60" />
          </div>
          <h2 id="settings-modal-title" className="font-bold">
            {t('agentParams')}
          </h2>
        </div>
        <button
          type="button"
          onClick={onClose}
          className="btn btn-ghost btn-circle btn-sm"
          aria-label={t('cancel')}
        >
          <X className="h-4 w-4" />
        </button>
      </div>

      <form action={formAction} className="space-y-5 px-4 pb-6 pt-4 sm:px-6 sm:pb-8">
        <div className="form-control">
          <label className="text-label mb-1.5" htmlFor="settings-name">
            {t('businessNameLabel')}
          </label>
          <input
            id="settings-name"
            type="text"
            name="name"
            defaultValue={merchant.name}
            className="input input-bordered input-sm w-full min-h-10"
          />
        </div>

        <div className="form-control">
          <label className="text-label mb-1.5" htmlFor="settings-currency">
            {t('currencyLabel')}
          </label>
          <select
            id="settings-currency"
            name="currency_preference"
            defaultValue={merchant.currency_preference ?? 'CAD'}
            className="select select-bordered select-sm w-full min-h-10"
          >
            {CURRENCIES.map((opt) => (
              <option key={opt.value} value={opt.value}>
                {opt.label}
              </option>
            ))}
          </select>
          <p className="mt-1 text-[10px] text-base-content/35 leading-relaxed">
            {t('currencyHint')}
          </p>
        </div>

        <div className="form-control">
          <label className="text-label mb-1.5" htmlFor="settings-phone">
            {t('phoneLabel')}
          </label>
          <input
            id="settings-phone"
            type="tel"
            name="phone"
            defaultValue={merchant.phone ?? ''}
            className="input input-bordered input-sm w-full min-h-10"
            placeholder="+1 234 567 8900"
          />
        </div>

        <div className="space-y-2">
          <div className="flex items-center justify-between">
            <label className="text-label">{t('strictnessLabel')}</label>
            <span className="text-sm font-bold tabular-nums" id="strictness-value">
              {merchant.strictness_level}/10
            </span>
          </div>
          <input
            type="range"
            name="strictness"
            min="1"
            max="10"
            defaultValue={merchant.strictness_level}
            className="range range-xs range-primary"
            aria-valuetext={`${merchant.strictness_level} of 10`}
          />
        </div>

        <div className="space-y-2">
          <div className="flex items-center justify-between">
            <label className="text-label">{t('settlementFloor')}</label>
            <span className="text-sm font-bold tabular-nums">
              {Math.round(merchant.settlement_floor * 100)}%
            </span>
          </div>
          <input
            type="range"
            name="settlement"
            min="50"
            max="100"
            defaultValue={merchant.settlement_floor * 100}
            className="range range-xs range-primary"
          />
        </div>

        <div className="divider my-1" />

        <div className="space-y-2">
          <div className="flex items-center gap-2">
            <Shield className="h-3.5 w-3.5 text-base-content/40" />
            <label className="text-label" htmlFor="settings-retention">
              {t('dataRetentionLabel')}
            </label>
          </div>
          <select
            id="settings-retention"
            name="data_retention_days"
            defaultValue={merchant.data_retention_days ?? 0}
            className="select select-bordered select-sm w-full min-h-10"
          >
            {RETENTION_OPTIONS.map((opt) => (
              <option key={opt.value} value={opt.value}>
                {opt.label}
              </option>
            ))}
          </select>
          <p className="text-[10px] text-base-content/35 leading-relaxed">
            {t('dataRetentionHint')}
          </p>
        </div>

        {state.error && (
          <p className="text-sm text-error" role="alert">
            {state.error}
          </p>
        )}

        <button
          type="submit"
          className="btn btn-primary w-full min-h-11"
          disabled={isPending}
        >
          {isPending ? (
            <span className="loading loading-spinner loading-sm" />
          ) : (
            t('applyUpdates')
          )}
        </button>
      </form>
    </AccessibleModal>
  );
}
