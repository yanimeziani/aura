import type { Metadata } from 'next';
import { useTranslations } from 'next-intl';
import { Link } from '@/i18n/navigation';

export const metadata: Metadata = {
  title: 'Pricing | Dragun.app — Simple, Transparent Recovery Pricing',
  description: 'Performance-based pricing from $49/mo. 5% fee only on recovered funds. No recovery, no fee. Starter, Growth, and Scale plans.',
  openGraph: {
    title: 'Pricing | Dragun.app',
    description: 'Performance-based pricing from $49/mo. 5% fee only on recovered funds.',
  },
};
import { Check, ArrowRight, Zap } from 'lucide-react';

export default function PricingPage() {
  const t = useTranslations('Pricing');

  const plans = [
    {
      key: 'starter' as const,
      featureCount: 5,
      highlight: false,
    },
    {
      key: 'pro' as const,
      featureCount: 6,
      highlight: true,
    },
    {
      key: 'enterprise' as const,
      featureCount: 7,
      highlight: false,
    },
  ];

  return (
    <main>
      <section className="hero-gradient py-16 sm:py-20">
        <div className="app-shell max-w-2xl space-y-5">
          <span className="badge badge-primary badge-outline text-[10px] font-bold uppercase tracking-widest">{t('badge')}</span>
          <h1 className="text-4xl font-bold sm:text-5xl">
            {t('title')} <span className="text-base-content/40">{t('titleHighlight').toLowerCase()}</span> {t('titleEnd').toLowerCase()}
          </h1>
          <p className="text-base text-base-content/60 leading-relaxed">
            {t('heroDesc')}
          </p>
        </div>
      </section>

      <section className="py-16">
        <div className="app-shell grid gap-5 md:grid-cols-3">
          {plans.map((plan) => (
            <article
              key={plan.key}
              className={`surface-card relative ${plan.highlight ? 'border-primary/40 shadow-lg shadow-primary/5' : ''}`}
            >
              {plan.highlight && (
                <div className="absolute -top-3 left-6">
                  <span className="badge badge-primary gap-1 text-[10px] font-bold uppercase tracking-widest">
                    <Zap className="h-3 w-3" /> {t('mostPopular')}
                  </span>
                </div>
              )}
              <div className="card-body p-6">
                <div>
                  <p className="text-label">{t(`${plan.key}.name`)}</p>
                  <p className="mt-1 text-sm text-base-content/55">{t(`${plan.key}.description`)}</p>
                </div>
                <div className="mt-4 flex items-baseline gap-1">
                  <span className="text-4xl font-bold">{t(`${plan.key}.price`)}</span>
                  <span className="text-label">{t('perMonth')}</span>
                </div>
                <div className="divider my-3" />
                <ul className="space-y-2.5">
                  {Array.from({ length: plan.featureCount }, (_, i) => (
                    <li key={i} className="flex items-start gap-2.5 text-sm text-base-content/65">
                      <Check className="mt-0.5 h-4 w-4 text-success shrink-0" />
                      {t(`${plan.key}.feature${i + 1}`)}
                    </li>
                  ))}
                </ul>
                <Link href={`/login?plan=${t(`${plan.key}.name`).toLowerCase()}`} className={`btn mt-6 w-full gap-2 min-h-12 ${plan.highlight ? 'btn-primary' : 'btn-outline'}`}>
                  {t(`${plan.key}.cta`)} <ArrowRight className="h-4 w-4" />
                </Link>
              </div>
            </article>
          ))}
        </div>
      </section>

      <section className="py-8">
        <div className="app-shell">
          <div className="surface-card">
            <div className="card-body p-6 sm:p-8 text-center">
              <span className="text-label">{t('feeModelLabel')}</span>
              <p className="mx-auto mt-3 max-w-3xl text-sm text-base-content/60 leading-relaxed">
                {t('feeModelDesc')}
              </p>
            </div>
          </div>
        </div>
      </section>

      <section className="py-12">
        <div className="app-shell">
          <div className="surface-card-elevated gradient-mesh">
            <div className="card-body p-8 sm:p-12 text-center">
              <h2 className="text-2xl font-bold sm:text-3xl">{t('customPlanTitle')}</h2>
              <p className="mx-auto mt-2 max-w-xl text-sm text-base-content/60">
                {t('customPlanDesc')}
              </p>
              <Link href="/contact" className="btn btn-primary btn-lg mt-6 gap-2 min-h-14">
                {t('contactSales')} <ArrowRight className="h-4 w-4" />
              </Link>
            </div>
          </div>
        </div>
      </section>
    </main>
  );
}
