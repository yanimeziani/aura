import { useTranslations } from 'next-intl';
import { Link } from '@/i18n/navigation';
import { ArrowRight, CheckCircle2, ShieldCheck, Gauge, Wallet } from 'lucide-react';
import Logo from '@/components/Logo';

export default function LandingPage() {
  const t = useTranslations('Home');

  return (
    <main className="bg-background text-foreground">
      <section className="border-b border-border">
        <div className="mx-auto flex w-full max-w-7xl flex-col gap-10 px-4 pb-20 pt-20 sm:px-6 lg:px-8 lg:pt-24">
          <div className="inline-flex w-fit items-center rounded-full border border-border bg-card px-4 py-2 text-[11px] font-semibold uppercase tracking-[0.18em] text-muted-foreground">
            {t('badge')}
          </div>

          <div className="max-w-4xl space-y-6">
            <h1 className="text-4xl font-semibold leading-tight tracking-tightest sm:text-6xl">
              {t('heroLine1')}
            </h1>
            <p className="max-w-3xl text-base text-muted-foreground sm:text-lg">{t('heroParagraph')}</p>
            <p className="text-sm text-muted-foreground">{t('trustLine')}</p>
          </div>

          <div className="flex flex-col gap-3 sm:flex-row">
            <Link
              href="/login"
              className="inline-flex h-12 items-center justify-center rounded-xl bg-primary px-7 text-sm font-semibold uppercase tracking-[0.14em] text-primary-foreground hover:opacity-90"
            >
              {t('startPilot')}
            </Link>
            <Link
              href="#demo"
              className="inline-flex h-12 items-center justify-center rounded-xl border border-border bg-card px-7 text-sm font-semibold uppercase tracking-[0.14em] text-foreground hover:bg-accent"
            >
              {t('watchDemo')}
            </Link>
          </div>
        </div>
      </section>

      <section id="demo" className="border-b border-border">
        <div className="mx-auto grid w-full max-w-7xl grid-cols-1 gap-8 px-4 py-16 sm:px-6 lg:grid-cols-12 lg:px-8">
          <div className="rounded-2xl border border-border bg-card p-8 shadow-elev-1 lg:col-span-8">
            <div className="mb-6 flex items-center justify-between">
              <div className="flex items-center gap-3">
                <Logo className="h-7 w-auto" />
                <p className="text-xs font-semibold uppercase tracking-[0.16em] text-muted-foreground">{t('agentName')}</p>
              </div>
              <span className="rounded-full border border-border px-3 py-1 text-[10px] uppercase tracking-[0.14em] text-muted-foreground">
                {t('encrypted')}
              </span>
            </div>
            <div className="space-y-4 text-sm">
              <div className="max-w-[85%] rounded-xl border border-border bg-background p-4 text-muted-foreground">
                {t('chatBubble1')}
              </div>
              <div className="ml-auto max-w-[85%] rounded-xl bg-primary p-4 text-primary-foreground">{t('chatBubble2')}</div>
              <div className="max-w-[85%] rounded-xl border border-border bg-background p-4 text-muted-foreground">
                {t('chatBubble3')}
              </div>
            </div>
          </div>

          <div className="grid grid-cols-1 gap-4 lg:col-span-4">
            <div className="rounded-2xl border border-border bg-card p-6 shadow-elev-1">
              <p className="text-xs uppercase tracking-[0.16em] text-muted-foreground">{t('recoveryRateLabel')}</p>
              <p className="mt-2 text-4xl font-semibold">82%</p>
            </div>
            <div className="rounded-2xl border border-border bg-card p-6 shadow-elev-1">
              <p className="text-xs uppercase tracking-[0.16em] text-muted-foreground">{t('latencyLabel')}</p>
              <p className="mt-2 text-4xl font-semibold">2.1s</p>
            </div>
            <p className="text-xs text-muted-foreground">{t('metricsFootnote')}</p>
          </div>
        </div>
      </section>

      <section className="border-b border-border">
        <div className="mx-auto w-full max-w-7xl px-4 py-16 sm:px-6 lg:px-8">
          <p className="text-sm text-muted-foreground">{t('socialProof')}</p>
          <div className="mt-6 grid grid-cols-2 gap-3 sm:grid-cols-4">
            {['NORTH POINT FITNESS', 'LUMEN DENTAL', 'ATLAS SERVICES', 'WELLSPRING CLINIC'].map((name) => (
              <div key={name} className="rounded-xl border border-border bg-card px-4 py-3 text-center text-xs tracking-[0.12em] text-muted-foreground">
                {name}
              </div>
            ))}
          </div>
        </div>
      </section>

      <section className="border-b border-border">
        <div className="mx-auto w-full max-w-7xl px-4 py-16 sm:px-6 lg:px-8">
          <div className="grid grid-cols-1 gap-8 lg:grid-cols-3">
            {[
              { icon: ShieldCheck, title: t('legalTitle'), desc: t('legalDesc') },
              { icon: Wallet, title: t('stripeTitle'), desc: t('stripeDesc') },
              { icon: Gauge, title: t('knowledgeTitle'), desc: t('knowledgeDesc') },
            ].map((feature) => (
              <div key={feature.title} className="rounded-2xl border border-border bg-card p-8 shadow-elev-1">
                <feature.icon className="h-6 w-6 text-foreground" />
                <h3 className="mt-4 text-lg font-semibold">{feature.title}</h3>
                <p className="mt-3 text-sm text-muted-foreground">{feature.desc}</p>
              </div>
            ))}
          </div>
        </div>
      </section>

      <section className="border-b border-border">
        <div className="mx-auto w-full max-w-7xl px-4 py-16 sm:px-6 lg:px-8">
          <h2 className="text-3xl font-semibold tracking-tight sm:text-4xl">{t('howTitle')}</h2>
          <div className="mt-8 grid grid-cols-1 gap-6 md:grid-cols-3">
            {[1, 2, 3].map((index) => (
              <div key={index} className="rounded-2xl border border-border bg-card p-6 shadow-elev-1">
                <p className="text-[11px] font-semibold uppercase tracking-[0.18em] text-muted-foreground">0{index}</p>
                <h3 className="mt-3 text-lg font-semibold">{t(`howStep${index}`)}</h3>
                <p className="mt-2 text-sm text-muted-foreground">{t(`howStep${index}Desc`)}</p>
              </div>
            ))}
          </div>
        </div>
      </section>

      <section className="border-b border-border">
        <div className="mx-auto w-full max-w-7xl px-4 py-16 sm:px-6 lg:px-8">
          <h2 className="text-3xl font-semibold tracking-tight sm:text-4xl">{t('securityTitle')}</h2>
          <div className="mt-8 grid grid-cols-1 gap-4 md:grid-cols-2">
            {[t('securityPoint1'), t('securityPoint2'), t('securityPoint3'), t('securityPoint4')].map((point) => (
              <div key={point} className="flex items-start gap-3 rounded-xl border border-border bg-card p-5 text-sm text-muted-foreground">
                <CheckCircle2 className="mt-0.5 h-4 w-4 text-foreground" />
                <span>{point}</span>
              </div>
            ))}
          </div>
        </div>
      </section>

      <section className="border-b border-border">
        <div className="mx-auto w-full max-w-7xl px-4 py-16 sm:px-6 lg:px-8">
          <div className="rounded-2xl border border-border bg-card p-8 shadow-elev-2 sm:p-12">
            <p className="text-xs uppercase tracking-[0.18em] text-muted-foreground">{t('ctaTitle1')}</p>
            <h2 className="mt-3 text-3xl font-semibold tracking-tight sm:text-5xl">{t('ctaTitle2')}</h2>
            <p className="mt-4 max-w-2xl text-sm text-muted-foreground sm:text-base">{t('ctaSubtitle')}</p>
            <div className="mt-8 flex flex-col gap-3 sm:flex-row">
              <Link
                href="/login"
                className="inline-flex h-12 items-center justify-center rounded-xl bg-primary px-7 text-sm font-semibold uppercase tracking-[0.14em] text-primary-foreground hover:opacity-90"
              >
                {t('ctaButton')}
                <ArrowRight className="ml-2 h-4 w-4" />
              </Link>
              <Link
                href="/pricing"
                className="inline-flex h-12 items-center justify-center rounded-xl border border-border bg-background px-7 text-sm font-semibold uppercase tracking-[0.14em] text-foreground hover:bg-accent"
              >
                {t('seePricing')}
              </Link>
            </div>
          </div>
        </div>
      </section>
    </main>
  );
}
