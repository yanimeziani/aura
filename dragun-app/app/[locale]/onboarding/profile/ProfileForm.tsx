'use client';

import { useMemo, useState } from 'react';
import { useTranslations } from 'next-intl';
import { useRouter } from '@/i18n/navigation';
import { updateOnboardingProfile } from '@/app/actions/onboarding';

const countries = [
  'Canada', 'United States', 'France', 'United Kingdom', 'Belgium',
  'Germany', 'Spain', 'Italy', 'Netherlands', 'Australia', 'New Zealand',
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
        <label className="text-label">{t('businessNameLabel')}</label>
        <input
          type="text"
          value={name}
          onChange={(e) => setName(e.target.value)}
          placeholder={t('businessNamePlaceholder')}
          className="input input-bordered h-12 w-full text-base font-semibold"
          required
        />
      </div>

      <div className="space-y-2">
        <label className="text-label">{t('countryLabel')}</label>
        <input
          type="text"
          value={countryQuery}
          onChange={(e) => setCountryQuery(e.target.value)}
          placeholder={t('countrySearchPlaceholder')}
          className="input input-bordered h-11 w-full text-sm"
        />
        <div className="grid max-h-44 grid-cols-1 gap-2 overflow-y-auto rounded-xl border border-base-300 bg-base-100 p-3 sm:grid-cols-2">
          {filteredCountries.map((item) => (
            <button
              type="button"
              key={item}
              onClick={() => { setCountry(item); setCountryQuery(item); }}
              className={`btn btn-sm justify-start ${country === item ? 'btn-primary' : 'btn-ghost'}`}
            >
              {item}
            </button>
          ))}
        </div>
        {!country && <p className="text-xs text-base-content/40">{t('countryHelper')}</p>}
      </div>

      <div className="space-y-2">
        <label className="text-label">{t('currencyLabel')}</label>
        <div className="grid grid-cols-2 sm:grid-cols-4 gap-3">
          {currencies.map((item) => (
            <button
              key={item}
              type="button"
              onClick={() => setCurrency(item)}
              className={`btn ${currency === item ? 'btn-primary' : 'btn-outline'}`}
            >
              {item}
            </button>
          ))}
        </div>
      </div>

      <div className="space-y-2">
        <label className="text-label">{t('phoneLabel')}</label>
        <input
          type="tel"
          value={phone}
          onChange={(e) => setPhone(e.target.value)}
          placeholder={t('phonePlaceholder')}
          className="input input-bordered h-12 w-full text-base font-semibold"
        />
      </div>

      {error && (
        <div className="alert alert-error text-sm">{error}</div>
      )}

      <button type="submit" disabled={loading} className="btn btn-primary w-full h-12 text-sm font-bold uppercase tracking-widest">
        {loading ? <span className="loading loading-spinner loading-sm" /> : t('continue')}
      </button>
    </form>
  );
}
