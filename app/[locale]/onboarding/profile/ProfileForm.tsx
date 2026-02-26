'use client';

import { useMemo, useState } from 'react';
import { useTranslations } from 'next-intl';
import { useRouter } from '@/i18n/navigation';
import { updateOnboardingProfile } from '@/app/actions/onboarding';

const countries = [
  'Canada',
  'United States',
  'France',
  'United Kingdom',
  'Belgium',
  'Germany',
  'Spain',
  'Italy',
  'Netherlands',
  'Australia',
  'New Zealand',
];

const currencies = ['CAD', 'USD', 'EUR', 'GBP'];

export default function ProfileForm() {
  const t = useTranslations('OnboardingProfile');
  const router = useRouter();
  const [name, setName] = useState('');
  const [countryQuery, setCountryQuery] = useState('');
  const [country, setCountry] = useState('');
  const [currency, setCurrency] = useState(currencies[0]);
  const [phone, setPhone] = useState('');
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);

  const filteredCountries = useMemo(() => {
    const query = countryQuery.trim().toLowerCase();
    if (!query) return countries;
    return countries.filter((item) => item.toLowerCase().includes(query));
  }, [countryQuery]);

  async function handleSubmit(event: React.FormEvent<HTMLFormElement>) {
    event.preventDefault();
    setError(null);

    if (!name.trim() || !country.trim() || !currency) {
      setError(t('errorRequired'));
      return;
    }

    setLoading(true);
    const result = await updateOnboardingProfile({
      name: name.trim(),
      country: country.trim(),
      currency_preference: currency,
      phone: phone.trim() ? phone.trim() : null,
    });

    if (!result.success) {
      setError(result.error || t('errorGeneric'));
      setLoading(false);
      return;
    }

    router.push('/onboarding/tutorial');
  }

  return (
    <form onSubmit={handleSubmit} className="space-y-8">
      <div className="space-y-2">
        <label className="text-xs uppercase tracking-[0.2em] text-white/40 font-semibold">
          {t('businessNameLabel')}
        </label>
        <input
          type="text"
          value={name}
          onChange={(event) => setName(event.target.value)}
          placeholder={t('businessNamePlaceholder')}
          className="w-full rounded-2xl border border-white/10 bg-white/5 px-5 py-4 text-base font-semibold text-white placeholder:text-white/30 focus:border-white/40 focus:bg-white/10 focus:outline-none"
          required
        />
      </div>

      <div className="space-y-2">
        <label className="text-xs uppercase tracking-[0.2em] text-white/40 font-semibold">
          {t('countryLabel')}
        </label>
        <input
          type="text"
          value={countryQuery}
          onChange={(event) => setCountryQuery(event.target.value)}
          placeholder={t('countrySearchPlaceholder')}
          className="w-full rounded-2xl border border-white/10 bg-white/5 px-5 py-3 text-sm font-medium text-white placeholder:text-white/30 focus:border-white/40 focus:bg-white/10 focus:outline-none"
        />
        <div className="grid grid-cols-1 sm:grid-cols-2 gap-3 max-h-44 overflow-y-auto rounded-2xl border border-white/10 bg-black/30 p-3">
          {filteredCountries.map((item) => {
            const selected = country === item;
            return (
              <button
                type="button"
                key={item}
                onClick={() => {
                  setCountry(item);
                  setCountryQuery(item);
                }}
                className={`rounded-xl border px-3 py-2 text-left text-sm font-semibold transition ${
                  selected
                    ? 'border-white/60 bg-white/20 text-white'
                    : 'border-white/10 bg-white/5 text-white/70 hover:border-white/30 hover:text-white'
                }`}
              >
                {item}
              </button>
            );
          })}
        </div>
        {!country && (
          <p className="text-xs text-white/30">{t('countryHelper')}</p>
        )}
      </div>

      <div className="space-y-2">
        <label className="text-xs uppercase tracking-[0.2em] text-white/40 font-semibold">
          {t('currencyLabel')}
        </label>
        <div className="grid grid-cols-2 sm:grid-cols-4 gap-3">
          {currencies.map((item) => {
            const selected = currency === item;
            return (
              <button
                key={item}
                type="button"
                onClick={() => setCurrency(item)}
                className={`rounded-xl border px-3 py-3 text-sm font-semibold transition ${
                  selected
                    ? 'border-white/60 bg-white/20 text-white'
                    : 'border-white/10 bg-white/5 text-white/70 hover:border-white/30 hover:text-white'
                }`}
              >
                {item}
              </button>
            );
          })}
        </div>
      </div>

      <div className="space-y-2">
        <label className="text-xs uppercase tracking-[0.2em] text-white/40 font-semibold">
          {t('phoneLabel')}
        </label>
        <input
          type="tel"
          value={phone}
          onChange={(event) => setPhone(event.target.value)}
          placeholder={t('phonePlaceholder')}
          className="w-full rounded-2xl border border-white/10 bg-white/5 px-5 py-4 text-base font-semibold text-white placeholder:text-white/30 focus:border-white/40 focus:bg-white/10 focus:outline-none"
        />
      </div>

      {error && (
        <div className="rounded-xl border border-red-500/30 bg-red-500/10 px-4 py-3 text-sm text-red-200">
          {error}
        </div>
      )}

      <button
        type="submit"
        disabled={loading}
        className="w-full rounded-2xl bg-white text-black py-4 text-sm font-black uppercase tracking-[0.2em] transition hover:opacity-90 disabled:opacity-60"
      >
        {loading ? t('saving') : t('continue')}
      </button>
    </form>
  );
}
