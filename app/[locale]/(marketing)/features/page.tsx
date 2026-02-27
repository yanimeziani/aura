import { useTranslations } from 'next-intl';
import { Link } from '@/i18n/navigation';
import { Bot, FileText, BadgeDollarSign, ShieldCheck, Zap, Users, BarChart3, MessageSquare, Lock, Globe, CheckCircle2, ArrowRight } from 'lucide-react';

export default function FeaturesPage() {
  const t = useTranslations('Features');

  const core = [
    { icon: Bot, title: t('geminiTitle'), desc: t('geminiDesc') },
    { icon: FileText, title: t('contractTitle'), desc: t('contractDesc') },
    { icon: BadgeDollarSign, title: t('stripeTitle'), desc: t('stripeDesc') },
  ];

  const advanced = [
    { icon: ShieldCheck, title: 'Automated Compliance', desc: 'Built-in regulatory compliance checks ensure all communications meet legal requirements automatically.' },
    { icon: Zap, title: 'Smart Escalation', desc: 'AI automatically escalates cases based on debtor response patterns and configurable business rules.' },
    { icon: Users, title: 'Team Collaboration', desc: 'Assign cases, track progress, add notes, and coordinate across your recovery team with role-based access.' },
    { icon: BarChart3, title: 'Analytics Dashboard', desc: 'Real-time insights into recovery rates, response times, payment trends, and team performance.' },
    { icon: MessageSquare, title: 'AI Chat Assistant', desc: 'Get instant guidance on recovery strategy with AI that analyzes case details and suggests optimal approaches.' },
    { icon: ShieldCheck, title: 'Smart Notifications', desc: 'Real-time alerts for payments, responses, deadlines, and follow-ups.' },
  ];

  const security = [
    { icon: Lock, title: 'End-to-End Encryption', desc: 'All data encrypted at rest and in transit using AES-256.' },
    { icon: Globe, title: 'GDPR Compliant', desc: 'Full compliance with GDPR, CCPA, and international data protection regulations.' },
    { icon: ShieldCheck, title: 'SOC 2 Aligned', desc: 'Enterprise-grade security infrastructure on Vercel + Supabase.' },
    { icon: CheckCircle2, title: 'Audit Trails', desc: 'Complete audit logging for all user actions, communications, and system events.' },
  ];

  return (
    <main>
      <section className="hero-gradient py-16 sm:py-20">
        <div className="app-shell max-w-3xl space-y-5">
          <span className="badge badge-primary badge-outline text-[10px] font-bold uppercase tracking-widest">Platform capabilities</span>
          <h1 className="text-4xl font-bold sm:text-5xl">
            {t('title')} <span className="text-base-content/40">{t('titleHighlight')}</span>
          </h1>
          <p className="max-w-2xl text-base text-base-content/60 leading-relaxed">{t('subtitle')}</p>
        </div>
      </section>

      <section className="section-divider bg-base-200/20 py-16">
        <div className="app-shell">
          <span className="text-label">Core Capabilities</span>
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
          <span className="text-label">Advanced Features</span>
          <h2 className="mt-3 text-2xl font-bold sm:text-3xl">Everything you need to recover efficiently</h2>
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
          <span className="text-label">Security & Compliance</span>
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
          <h2 className="text-3xl font-bold">Ready to transform your recovery?</h2>
          <p className="mt-3 text-base text-base-content/55 max-w-xl mx-auto">
            Join the pilot program and start recovering more with AI-powered automation.
          </p>
          <div className="mt-8 flex flex-wrap gap-3 justify-center">
            <Link href="/login" className="btn btn-primary btn-lg gap-2">
              Start Free Pilot <ArrowRight className="h-4 w-4" />
            </Link>
            <Link href="/pricing" className="btn btn-outline btn-lg">See Pricing</Link>
          </div>
        </div>
      </section>
    </main>
  );
}
