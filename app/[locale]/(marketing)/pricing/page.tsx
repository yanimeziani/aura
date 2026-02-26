import { useTranslations } from 'next-intl';
import { Sparkles, Check } from 'lucide-react';

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
    <main className="bg-background text-foreground">
      <section className="border-b border-border">
        <div className="mx-auto flex w-full max-w-7xl flex-col gap-8 px-4 pb-16 pt-20 sm:px-6 lg:px-8 lg:pt-24">
          <div className="inline-flex w-fit items-center gap-2 rounded-full border border-border bg-card px-4 py-2 text-[11px] font-semibold uppercase tracking-[0.18em] text-muted-foreground">
            <Sparkles className="h-3.5 w-3.5" />
            {t('titleHighlight')} Plans
          </div>
          <h1 className="max-w-4xl text-4xl font-semibold tracking-tightest sm:text-6xl">
            {t('title')} <span className="text-muted-foreground">{t('titleHighlight')}</span>
          </h1>
          <p className="max-w-3xl text-base text-muted-foreground sm:text-lg">{t('subtitle')}</p>
        </div>
      </section>

      <section className="border-b border-border">
        <div className="mx-auto grid w-full max-w-7xl grid-cols-1 gap-6 px-4 py-16 sm:px-6 md:grid-cols-3 lg:px-8">
          {plans.map((plan) => {
            const isStarter = plan.key === 'starter';
            const isPro = plan.key === 'pro';
            const isEnterprise = plan.key === 'enterprise';
            const name = isStarter ? t('starter.name') : isPro ? t('pro.name') : t('enterprise.name');
            const description = isStarter ? t('starter.description') : isPro ? t('pro.description') : t('enterprise.description');
            const price = isStarter ? t('starter.price') : isPro ? t('pro.price') : t('enterprise.price');

            return (
              <article
                key={plan.key}
                className={`rounded-2xl border p-8 shadow-elev-1 ${plan.highlight ? 'border-ring bg-popover' : 'border-border bg-card'}`}
              >
                <div className="flex items-center justify-between">
                  <p className="text-[11px] font-semibold uppercase tracking-[0.18em] text-muted-foreground">{name}</p>
                  {plan.highlight && (
                    <span className="rounded-full border border-border bg-background px-3 py-1 text-[10px] font-semibold uppercase tracking-[0.14em] text-foreground">
                      {t('popular')}
                    </span>
                  )}
                </div>
                <p className="mt-2 text-sm text-muted-foreground">{description}</p>
                <div className="mt-6 flex items-baseline gap-2">
                  <span className="text-4xl font-semibold">{price}</span>
                  {!isEnterprise && <span className="text-xs uppercase tracking-[0.14em] text-muted-foreground">{t('perMonth')}</span>}
                </div>

                <ul className="mt-6 space-y-3">
                  {plan.features.map((feature) => (
                    <li key={feature} className="flex items-center gap-3 text-sm text-muted-foreground">
                      <span className="inline-flex h-5 w-5 items-center justify-center rounded-full border border-border bg-background">
                        <Check className="h-3 w-3 text-foreground" />
                      </span>
                      {feature}
                    </li>
                  ))}
                </ul>

                <button
                  className={`mt-8 inline-flex h-11 w-full items-center justify-center rounded-xl text-sm font-semibold uppercase tracking-[0.14em] ${
                    plan.highlight
                      ? 'bg-primary text-primary-foreground hover:opacity-90'
                      : 'border border-border bg-background text-foreground hover:bg-accent'
                  }`}
                >
                  {plan.cta}
                </button>
              </article>
            );
          })}
        </div>
      </section>

      <section>
        <div className="mx-auto w-full max-w-7xl px-4 py-16 sm:px-6 lg:px-8">
          <div className="rounded-2xl border border-border bg-card p-8 text-center shadow-elev-1 sm:p-10">
            <p className="text-[11px] font-semibold uppercase tracking-[0.18em] text-muted-foreground">Global Platform Protocol</p>
            <p className="mx-auto mt-4 max-w-3xl text-sm text-muted-foreground">
              Dragun operates on a performance-based resolution model. A <span className="font-semibold text-foreground">5% platform fee</span> applies only to successfully recovered funds.
              No recovery, no fee. Secure gateway payments processed via Stripe Connect.
            </p>
          </div>
        </div>
      </section>
    </main>
  );
}
