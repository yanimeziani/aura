import type { Metadata } from 'next';
import { useTranslations } from 'next-intl';
import { Link } from '@/i18n/navigation';

export const metadata: Metadata = {
  title: 'Dragun.app | AI-Powered Debt Recovery',
  description: 'Recover debt without burning relationships. Dragun negotiates with empathy, cites your contracts, and sends settlement links instantly.',
  openGraph: {
    title: 'Dragun.app | AI-Powered Debt Recovery',
    description: 'Recover debt without burning relationships. Empathetic AI negotiation with Stripe settlement links.',
  },
};
import {
  ArrowRight,
  CheckCircle2,
  Shield,
  Zap,
  FileText,
  MessageSquare,
  CreditCard,
  BarChart3,
  Lock,
} from 'lucide-react';
import InteractiveRecoveryDemo from '@/components/InteractiveRecoveryDemo';
import HeroGlow from '@/components/landing/HeroGlow';

const jsonLd = {
  '@context': 'https://schema.org',
  '@type': 'SoftwareApplication',
  name: 'Dragun.app',
  applicationCategory: 'BusinessApplication',
  operatingSystem: 'Web',
  description: 'AI-powered debt recovery platform with empathetic negotiation, contract intelligence, and Stripe settlement links.',
  url: 'https://www.dragun.app',
  offers: {
    '@type': 'AggregateOffer',
    lowPrice: '49',
    highPrice: '399',
    priceCurrency: 'USD',
    offerCount: 3,
  },
  creator: {
    '@type': 'Organization',
    name: 'Meziani AI',
    url: 'https://meziani.ai',
  },
};

export default function LandingPage() {
  const t = useTranslations('Home');

  return (
    <main>
      <script
        type="application/ld+json"
        dangerouslySetInnerHTML={{ __html: JSON.stringify(jsonLd) }}
      />
      <a href="#main-content" className="skip-link">Skip to main content</a>

      {/* ─── Hero: funky, visual, not cluttered ─── */}
      <section className="relative overflow-hidden" id="main-content">
        <div className="absolute inset-0 grid-pattern text-base-content/[0.03] pointer-events-none" />
        <HeroGlow />

        <div className="app-shell relative z-10 pt-24 pb-20 sm:pt-32 sm:pb-28">
          <div className="max-w-3xl">
            {/* Badge */}
            <div className="inline-flex items-center gap-2 rounded-full border border-primary/20 bg-primary/5 px-4 py-1.5 mb-8">
              <Zap className="w-3.5 h-3.5 text-primary" />
              <span className="text-xs font-semibold text-primary">{t('badge')}</span>
            </div>

            <h1 className="text-4xl sm:text-5xl lg:text-6xl font-bold tracking-tight leading-[1.1]">
              {t('heroLine1')}
            </h1>

            <p className="mt-6 text-lg text-base-content/55 max-w-2xl leading-relaxed">
              {t('heroParagraph')}
            </p>

            <div className="flex flex-wrap gap-3 mt-10">
              <Link href="/register" className="btn btn-primary gap-2 px-6 text-base min-h-12">
                {t('startPilot')}
                <ArrowRight className="w-4 h-4" />
              </Link>
              <Link href="/pricing" className="btn btn-ghost border border-base-300/60 gap-2 min-h-12">
                {t('seePricing')}
              </Link>
              <a href="#demo" className="btn btn-ghost gap-2 min-h-12">
                {t('watchDemo')}
              </a>
            </div>
          </div>

          {/* Floating stat cards beside hero -- Von Restorff: make key metrics stand out */}
          <div className="mt-16 grid grid-cols-2 sm:grid-cols-3 gap-3 max-w-2xl">
            {[
              { label: t('recoveryRateLabel'), value: '82%', sub: t('pilotMedian') },
              { label: t('latencyLabel'), value: '2.1s', sub: t('p50Latency') },
              { label: t('activePilots'), value: '24+', sub: t('liveDeployments') },
            ].map((stat) => (
              <div key={stat.label} className="card bg-base-200/50 border border-base-300/30 shadow-warm hover-lift">
                <div className="card-body p-4">
                  <p className="text-label">{stat.label}</p>
                  <p className="text-2xl sm:text-3xl font-bold tracking-tight">{stat.value}</p>
                  <p className="text-xs text-base-content/40">{stat.sub}</p>
                </div>
              </div>
            ))}
          </div>

          <p className="text-[10px] text-base-content/25 mt-4 max-w-lg">{t('metricsFootnote')}</p>
        </div>
      </section>

      {/* ─── Social proof ticker ─── */}
      <section className="border-y border-base-300/30 bg-base-200/20 py-6 overflow-hidden">
        <div className="app-shell">
          <p className="text-label text-center mb-4">{t('trustedBy')}</p>
          <div className="flex flex-wrap justify-center gap-x-10 gap-y-3 items-center">
            {['North Point Fitness', 'Lumen Dental', 'Atlas Services', 'Wellspring Clinic', 'Urban Physio', 'Metro Legal', 'Apex Dental', 'City Fitness'].map((name) => (
              <span key={name} className="text-sm text-base-content/30 font-medium whitespace-nowrap">
                {name}
              </span>
            ))}
            <span className="badge badge-outline badge-sm border-base-300/50 text-base-content/40">
              Stripe · SOC 2
            </span>
          </div>
        </div>
      </section>

      {/* ─── Demo: interactive, the peak experience (Peak-End Rule) ─── */}
      <section className="py-20 sm:py-28" id="demo">
        <div className="app-shell max-w-5xl">
          <div className="text-center mb-14">
            <h2 className="text-3xl sm:text-4xl font-bold tracking-tight">{t('demoTitle')}</h2>
            <p className="text-base-content/50 mt-3 max-w-xl mx-auto">
              {t('demoDesc')}
            </p>
          </div>
          <InteractiveRecoveryDemo />
        </div>
      </section>

      {/* ─── Features: chunked into 3 (Miller's Law), grouped by region (Law of Common Region) ─── */}
      <section className="py-20 bg-base-200/20 border-y border-base-300/20">
        <div className="app-shell max-w-5xl">
          <div className="text-center mb-14">
            <h2 className="text-3xl sm:text-4xl font-bold tracking-tight">{t('featSectionTitle')}</h2>
            <p className="text-base-content/50 mt-3 max-w-xl mx-auto">
              {t('featSectionDesc')}
            </p>
          </div>

          <div className="grid sm:grid-cols-2 lg:grid-cols-3 gap-4">
            {[
              { icon: MessageSquare, title: t('featAiTitle'), desc: t('featAiDesc') },
              { icon: FileText, title: t('featContractTitle'), desc: t('featContractDesc') },
              { icon: CreditCard, title: t('featStripeTitle'), desc: t('featStripeDesc') },
              { icon: BarChart3, title: t('featAnalyticsTitle'), desc: t('featAnalyticsDesc') },
              { icon: Shield, title: t('featComplianceTitle'), desc: t('featComplianceDesc') },
              { icon: Lock, title: t('featSecurityTitle'), desc: t('featSecurityDesc') },
            ].map((f) => (
              <div key={f.title} className="card bg-base-100 border border-base-300/40 shadow-warm hover-lift">
                <div className="card-body p-6">
                  <div className="flex h-10 w-10 items-center justify-center rounded-xl bg-primary/10 text-primary mb-2">
                    <f.icon className="w-5 h-5" />
                  </div>
                  <h3 className="font-bold text-lg">{f.title}</h3>
                  <p className="text-sm text-base-content/50 leading-relaxed">{f.desc}</p>
                </div>
              </div>
            ))}
          </div>
        </div>
      </section>

      {/* ─── How it works: 3 steps (Chunking, Goal-Gradient) ─── */}
      <section className="py-20 sm:py-28">
        <div className="app-shell max-w-3xl">
          <div className="text-center mb-16">
            <h2 className="text-3xl sm:text-4xl font-bold tracking-tight">{t('howTitle')}</h2>
          </div>

          <div className="space-y-12">
            {[
              { n: '01', title: t('howStep1'), desc: t('howStep1Desc') },
              { n: '02', title: t('howStep2'), desc: t('howStep2Desc') },
              { n: '03', title: t('howStep3'), desc: t('howStep3Desc') },
            ].map((step) => (
              <div key={step.n} className="flex gap-6 items-start">
                <div className="flex h-12 w-12 shrink-0 items-center justify-center rounded-2xl bg-primary/10 text-primary font-bold text-sm">
                  {step.n}
                </div>
                <div>
                  <h3 className="text-lg font-bold">{step.title}</h3>
                  <p className="text-base-content/50 mt-1 leading-relaxed">{step.desc}</p>
                </div>
              </div>
            ))}
          </div>
        </div>
      </section>

      {/* ─── Security ─── */}
      <section className="py-16 bg-base-200/20 border-y border-base-300/20">
        <div className="app-shell max-w-3xl">
          <h2 className="text-2xl font-bold tracking-tight mb-8">{t('securityTitle')}</h2>
          <div className="space-y-4">
            {[t('securityPoint1'), t('securityPoint2'), t('securityPoint3'), t('securityPoint4')].map((point) => (
              <div key={point} className="flex items-start gap-3">
                <CheckCircle2 className="w-5 h-5 text-success shrink-0 mt-0.5" />
                <p className="text-base-content/70">{point}</p>
              </div>
            ))}
          </div>
        </div>
      </section>

      {/* ─── CTA: clean, single focus (Hick's Law -- reduce choices) ─── */}
      <section className="py-20 sm:py-28">
        <div className="app-shell max-w-2xl text-center">
          <h2 className="text-3xl sm:text-4xl font-bold tracking-tight">
            {t('ctaTitle2')}
          </h2>
          <p className="text-base-content/50 mt-4 mb-10 text-lg">{t('ctaSubtitle')}</p>
          <div className="flex flex-wrap gap-3 justify-center">
            <Link href="/register" className="btn btn-primary btn-lg gap-2 px-8 min-h-14">
              {t('ctaButton')}
              <ArrowRight className="w-5 h-5" />
            </Link>
            <Link href="/pricing" className="btn btn-ghost btn-lg border border-base-300/60 min-h-14">
              {t('seePricing')}
            </Link>
          </div>
          <p className="text-xs text-base-content/40 mt-4">
            Production pilot · No credit card for trial · Cancel anytime
          </p>
        </div>
      </section>
    </main>
  );
}
