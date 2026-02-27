import { useTranslations } from 'next-intl';
import { Check } from 'lucide-react';

export default function PricingPage() {
  const t = useTranslations('Pricing');

  const plans = [
    {
      key: 'starter',
      highlight: false,
      features: [t('starter.feature1'), t('starter.feature2'), t('starter.feature3')],
      cta: t('starter.cta'),
    },
    {
      key: 'pro',
      highlight: true,
      features: [t('pro.feature1'), t('pro.feature2'), t('pro.feature3'), t('pro.feature4')],
      cta: t('pro.cta'),
    },
    {
      key: 'enterprise',
      highlight: false,
      features: [t('enterprise.feature1'), t('enterprise.feature2'), t('enterprise.feature3'), t('enterprise.feature4')],
      cta: t('enterprise.cta'),
    },
  ];

  return (
    <main className="app-shell space-y-10 py-10 sm:space-y-16 sm:py-16">
      <section className="space-y-5">
        <span className="badge badge-outline badge-accent">{t('titleHighlight')} plans</span>
        <h1 className="text-4xl font-semibold sm:text-6xl">
          {t('title')} <span className="text-base-content/55">{t('titleHighlight')}</span>
        </h1>
        <p className="max-w-3xl text-base text-base-content/72 sm:text-lg">{t('subtitle')}</p>
      </section>

      <section className="grid gap-4 md:grid-cols-3">
        {plans.map((plan) => {
          const isStarter = plan.key === 'starter';
          const isPro = plan.key === 'pro';
          const name = isStarter ? t('starter.name') : isPro ? t('pro.name') : t('enterprise.name');
          const description = isStarter ? t('starter.description') : isPro ? t('pro.description') : t('enterprise.description');
          const price = isStarter ? t('starter.price') : isPro ? t('pro.price') : t('enterprise.price');

          return (
            <article
              key={plan.key}
              className={`surface-card ${plan.highlight ? 'border-primary/50 shadow-md shadow-primary/10' : ''}`}
            >
              <div className="card-body">
                <div className="flex items-center justify-between">
                  <p className="text-xs uppercase tracking-wide text-base-content/55">{name}</p>
                  {plan.highlight && <span className="badge badge-primary badge-sm">{t('popular')}</span>}
                </div>
                <p className="text-sm text-base-content/70">{description}</p>
                <div className="mt-2 flex items-baseline gap-2">
                  <span className="text-4xl font-semibold">{price}</span>
                  {!plan.key.includes('enterprise') && <span className="text-xs uppercase tracking-wide text-base-content/50">{t('perMonth')}</span>}
                </div>
                <ul className="mt-3 space-y-2">
                  {plan.features.map((feature) => (
                    <li key={feature} className="flex items-start gap-2 text-sm text-base-content/70">
                      <Check className="mt-0.5 h-4 w-4 text-success" />
                      {feature}
                    </li>
                  ))}
                </ul>
                <button className={`btn mt-4 ${plan.highlight ? 'btn-primary' : 'btn-outline'}`}>{plan.cta}</button>
              </div>
            </article>
          );
        })}
      </section>

      <article className="surface-card">
        <div className="card-body text-center">
          <p className="text-xs uppercase tracking-wide text-base-content/55">Global Platform Protocol</p>
          <p className="mx-auto max-w-3xl text-sm text-base-content/70">
            Dragun operates on a performance-based resolution model. A <span className="font-semibold text-base-content">5% platform fee</span> applies only to successfully recovered funds.
            No recovery, no fee. Secure gateway payments processed via Stripe Connect.
          </p>
        </div>
      </article>
    </main>
  );
}
