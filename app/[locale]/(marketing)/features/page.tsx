import type { Metadata } from 'next';
import { useTranslations } from 'next-intl';
import { Link } from '@/i18n/navigation';

export const metadata: Metadata = {
  title: 'Features | Dragun.app — AI Negotiation, Contract Intelligence, Stripe Connect',
  description: 'Gemini-powered AI negotiation, contract clause citation, Stripe payment integration, compliance guardrails, and real-time analytics.',
  openGraph: {
    title: 'Features | Dragun.app',
    description: 'AI negotiation, contract intelligence, Stripe integration, and compliance guardrails for professional debt recovery.',
  },
};
import { Bot, FileText, BadgeDollarSign, ShieldCheck, Zap, Users, BarChart3, MessageSquare, Lock, Globe, CheckCircle2, ArrowRight } from 'lucide-react';

export default function FeaturesPage() {
  const t = useTranslations('Features');

  const core = [
    { icon: Bot, title: t('geminiTitle'), desc: t('geminiDesc') },
    { icon: FileText, title: t('contractTitle'), desc: t('contractDesc') },
    { icon: BadgeDollarSign, title: t('stripeTitle'), desc: t('stripeDesc') },
  ];

  const advanced = [
    { icon: ShieldCheck, title: t('advComplianceTitle'), desc: t('advComplianceDesc') },
    { icon: Zap, title: t('advEscalationTitle'), desc: t('advEscalationDesc') },
    { icon: Users, title: t('advTeamTitle'), desc: t('advTeamDesc') },
    { icon: BarChart3, title: t('advAnalyticsTitle'), desc: t('advAnalyticsDesc') },
    { icon: MessageSquare, title: t('advChatTitle'), desc: t('advChatDesc') },
    { icon: ShieldCheck, title: t('advNotificationsTitle'), desc: t('advNotificationsDesc') },
  ];

  const security = [
    { icon: Lock, title: t('secEncryptionTitle'), desc: t('secEncryptionDesc') },
    { icon: Globe, title: t('secGdprTitle'), desc: t('secGdprDesc') },
    { icon: ShieldCheck, title: t('secSocTitle'), desc: t('secSocDesc') },
    { icon: CheckCircle2, title: t('secAuditTitle'), desc: t('secAuditDesc') },
  ];

  return (
    <main>
      <section className="hero-gradient py-16 sm:py-20">
        <div className="app-shell max-w-3xl space-y-5">
          <span className="badge badge-primary badge-outline text-[10px] font-bold uppercase tracking-widest">{t('badge')}</span>
          <h1 className="text-4xl font-bold sm:text-5xl">
            {t('title')} <span className="text-base-content/40">{t('titleHighlight')}</span>
          </h1>
          <p className="max-w-2xl text-base text-base-content/60 leading-relaxed">{t('subtitle')}</p>
        </div>
      </section>

      <section className="section-divider bg-base-200/20 py-16">
        <div className="app-shell">
          <span className="text-label">{t('coreLabel')}</span>
          <div className="mt-6 grid gap-4 md:grid-cols-3">
            {core.map((f) => (
              <article key={f.title} className="surface-card-elevated">
                <div className="card-body p-6">
                  <div className="flex h-10 w-10 items-center justify-center rounded-xl border border-base-300 bg-base-200/60">
                    <f.icon className="h-5 w-5 text-primary" />
                  </div>
                  <h2 className="mt-4 text-lg font-bold">{f.title}</h2>
                  <p className="mt-2 text-sm text-base-content/60 leading-relaxed">{f.desc}</p>
                </div>
              </article>
            ))}
          </div>
        </div>
      </section>

      <section className="py-16">
        <div className="app-shell">
          <span className="text-label">{t('advancedLabel')}</span>
          <h2 className="mt-3 text-2xl font-bold sm:text-3xl">{t('advancedTitle')}</h2>
          <div className="mt-8 grid gap-4 md:grid-cols-2">
            {advanced.map((f) => (
              <article key={f.title} className="surface-card">
                <div className="card-body p-6 flex-row gap-4">
                  <div className="flex h-10 w-10 shrink-0 items-center justify-center rounded-xl border border-base-300 bg-base-200/60">
                    <f.icon className="h-5 w-5 text-primary" />
                  </div>
                  <div>
                    <h3 className="text-base font-bold">{f.title}</h3>
                    <p className="mt-1 text-sm text-base-content/60 leading-relaxed">{f.desc}</p>
                  </div>
                </div>
              </article>
            ))}
          </div>
        </div>
      </section>

      <section className="section-divider bg-base-200/20 py-16">
        <div className="app-shell">
          <span className="text-label">{t('securityLabel')}</span>
          <div className="mt-6 grid gap-4 md:grid-cols-2">
            {security.map((f) => (
              <article key={f.title} className="surface-card">
                <div className="card-body p-6 flex-row gap-4">
                  <div className="flex h-10 w-10 shrink-0 items-center justify-center rounded-xl border border-base-300 bg-base-200/60">
                    <f.icon className="h-5 w-5 text-primary" />
                  </div>
                  <div>
                    <h3 className="text-base font-bold">{f.title}</h3>
                    <p className="mt-1 text-sm text-base-content/60 leading-relaxed">{f.desc}</p>
                  </div>
                </div>
              </article>
            ))}
          </div>
        </div>
      </section>

      <section className="py-16 sm:py-20">
        <div className="app-shell text-center">
          <h2 className="text-3xl font-bold">{t('ctaTitle')}</h2>
          <p className="mt-3 text-base text-base-content/55 max-w-xl mx-auto">
            {t('ctaDesc')}
          </p>
          <div className="mt-8 flex flex-wrap gap-3 justify-center">
            <Link href="/login" className="btn btn-primary btn-lg gap-2 min-h-14">
              {t('ctaButton')} <ArrowRight className="h-4 w-4" />
            </Link>
            <Link href="/pricing" className="btn btn-outline btn-lg min-h-14">{t('ctaPricing')}</Link>
          </div>
        </div>
      </section>
    </main>
  );
}
