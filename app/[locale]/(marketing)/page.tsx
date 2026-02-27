import { useTranslations } from 'next-intl';
import { Link } from '@/i18n/navigation';
import { ArrowRight, CheckCircle2, ShieldCheck, Gauge, Wallet } from 'lucide-react';
import InteractiveRecoveryDemo from '@/components/InteractiveRecoveryDemo';

export default function LandingPage() {
  const t = useTranslations('Home');

  return (
    <main>
      <section className="app-shell py-10 sm:py-16">
        <div className="grid gap-6 lg:grid-cols-12">
          <div className="space-y-6 lg:col-span-8">
            <span className="badge badge-accent badge-outline">{t('badge')}</span>
            <h1 className="text-4xl font-semibold leading-tight sm:text-5xl lg:text-6xl">{t('heroLine1')}</h1>
            <p className="max-w-3xl text-base text-base-content/72 sm:text-lg">{t('heroParagraph')}</p>
            <p className="text-sm text-base-content/60">{t('trustLine')}</p>
            <div className="flex flex-col gap-3 sm:flex-row">
              <Link href="/login" className="btn btn-primary">{t('startPilot')}</Link>
              <Link href="#demo" className="btn btn-outline">{t('watchDemo')}</Link>
            </div>
          </div>

          <aside className="surface-card lg:col-span-4">
            <div className="card-body">
              <p className="text-sm font-semibold">Launch Checklist</p>
              <ul className="space-y-3 text-sm text-base-content/70">
                <li className="flex items-start gap-2"><CheckCircle2 className="mt-0.5 h-4 w-4 text-success" />Stripe connect configured</li>
                <li className="flex items-start gap-2"><CheckCircle2 className="mt-0.5 h-4 w-4 text-success" />Contract clauses indexed</li>
                <li className="flex items-start gap-2"><CheckCircle2 className="mt-0.5 h-4 w-4 text-success" />Escalation policy defined</li>
              </ul>
              <div className="divider my-1" />
              <p className="text-xs text-base-content/60">{t('metricsFootnote')}</p>
            </div>
          </aside>
        </div>
      </section>

      <section id="demo" className="border-y border-base-300/70 bg-base-200/50 py-10 sm:py-16">
        <div className="app-shell grid gap-6 lg:grid-cols-12">
          <InteractiveRecoveryDemo />
          <div className="grid gap-4 lg:col-span-4">
            {[
              { label: t('recoveryRateLabel'), value: '82%', note: 'Pilot median across accounts aged 30-90 days.' },
              { label: t('latencyLabel'), value: '2.1s', note: 'Measured at p50 in active pilot environments.' },
            ].map((metric) => (
              <article key={metric.label} className="surface-card">
                <div className="card-body">
                  <p className="text-xs uppercase tracking-wide text-base-content/60">{metric.label}</p>
                  <p className="text-4xl font-semibold">{metric.value}</p>
                  <p className="text-xs text-base-content/60">{metric.note}</p>
                </div>
              </article>
            ))}
            <p className="text-xs text-base-content/60">{t('metricsFootnote')}</p>
          </div>
        </div>
      </section>

      <section className="app-shell py-10 sm:py-16">
        <p className="text-sm text-base-content/70">{t('socialProof')}</p>
        <div className="mt-6 grid grid-cols-2 gap-3 sm:grid-cols-4">
          {['NORTH POINT FITNESS', 'LUMEN DENTAL', 'ATLAS SERVICES', 'WELLSPRING CLINIC'].map((name) => (
            <div key={name} className="rounded-box border border-base-300 bg-base-100 p-4 text-center text-xs font-semibold tracking-wide text-base-content/70">
              {name}
            </div>
          ))}
        </div>
      </section>

      <section className="border-y border-base-300/70 bg-base-200/45 py-10 sm:py-16">
        <div className="app-shell grid gap-4 md:grid-cols-3">
          {[
            { icon: ShieldCheck, title: t('legalTitle'), desc: t('legalDesc') },
            { icon: Wallet, title: t('stripeTitle'), desc: t('stripeDesc') },
            { icon: Gauge, title: t('knowledgeTitle'), desc: t('knowledgeDesc') },
          ].map((feature) => (
            <article key={feature.title} className="surface-card">
              <div className="card-body">
                <feature.icon className="h-6 w-6 text-primary" />
                <h2 className="card-title text-xl">{feature.title}</h2>
                <p className="text-sm text-base-content/70">{feature.desc}</p>
              </div>
            </article>
          ))}
        </div>
      </section>

      <section className="app-shell py-10 sm:py-16">
        <h2 className="text-3xl font-semibold sm:text-4xl">{t('howTitle')}</h2>
        <div className="mt-6 grid gap-4 md:grid-cols-3">
          {[1, 2, 3].map((index) => (
            <article key={index} className="surface-card">
              <div className="card-body">
                <p className="text-xs uppercase tracking-wide text-base-content/55">Step 0{index}</p>
                <h3 className="text-lg font-semibold">{t(`howStep${index}`)}</h3>
                <p className="text-sm text-base-content/70">{t(`howStep${index}Desc`)}</p>
              </div>
            </article>
          ))}
        </div>
      </section>

      <section className="border-y border-base-300/70 bg-base-200/45 py-10 sm:py-16">
        <div className="app-shell">
          <h2 className="text-3xl font-semibold sm:text-4xl">{t('securityTitle')}</h2>
          <div className="mt-6 grid gap-3 md:grid-cols-2">
            {[t('securityPoint1'), t('securityPoint2'), t('securityPoint3'), t('securityPoint4')].map((point) => (
              <div key={point} className="rounded-box border border-base-300 bg-base-100 p-4 text-sm text-base-content/72">
                <span className="inline-flex items-start gap-2"><CheckCircle2 className="mt-0.5 h-4 w-4 text-success" />{point}</span>
              </div>
            ))}
          </div>
        </div>
      </section>

      <section className="app-shell py-12 sm:py-20">
        <article className="surface-card">
          <div className="card-body p-6 sm:p-10">
            <p className="text-xs uppercase tracking-wide text-base-content/55">{t('ctaTitle1')}</p>
            <h2 className="mt-2 text-3xl font-semibold sm:text-5xl">{t('ctaTitle2')}</h2>
            <p className="mt-4 max-w-2xl text-sm text-base-content/70 sm:text-base">{t('ctaSubtitle')}</p>
            <div className="mt-7 flex flex-col gap-3 sm:flex-row">
              <Link href="/login" className="btn btn-primary">
                {t('ctaButton')}
                <ArrowRight className="h-4 w-4" />
              </Link>
              <Link href="/pricing" className="btn btn-outline">{t('seePricing')}</Link>
            </div>
          </div>
        </article>
      </section>
    </main>
  );
}
