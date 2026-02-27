import { Settings } from 'lucide-react';

interface Props {
  merchant: {
    name: string;
    strictness_level: number;
    settlement_floor: number;
  };
  handleUpdateSettings: (formData: FormData) => Promise<void>;
  t: (key: string) => string;
}

export default function SettingsPanel({ merchant, handleUpdateSettings, t }: Props) {
  return (
    <div className="card bg-base-200/50 border border-base-300/50 shadow-warm">
      <div className="card-body p-5">
        <div className="flex items-center gap-3 mb-4">
          <div className="flex h-9 w-9 items-center justify-center rounded-lg bg-base-300/50">
            <Settings className="h-4 w-4 text-base-content/60" />
          </div>
          <h2 className="font-bold">{t('agentParams')}</h2>
        </div>

        <form action={handleUpdateSettings} className="space-y-5">
          <div className="form-control">
            <label className="text-label mb-1.5">{t('businessNameLabel')}</label>
            <input
              type="text"
              name="name"
              defaultValue={merchant.name}
              className="input input-bordered input-sm w-full"
            />
          </div>

          <div className="space-y-2">
            <div className="flex items-center justify-between">
              <label className="text-label">{t('strictnessLabel')}</label>
              <span className="text-sm font-bold tabular-nums">
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

          <button className="btn btn-primary w-full">
            {t('applyUpdates')}
          </button>
        </form>
      </div>
    </div>
  );
}
