import { useTranslations } from 'next-intl';
import { Bot, FileText, BadgeDollarSign } from 'lucide-react';

export default function FeaturesPage() {
  const t = useTranslations('Features');

  return (
    <main className="app-shell space-y-10 py-10 sm:space-y-16 sm:py-16">
      <section className="space-y-5">
        <span className="badge badge-outline badge-secondary">Platform capabilities</span>
        <h1 className="text-4xl font-semibold leading-tight sm:text-6xl">
          {t('title')} <span className="text-base-content/55">{t('titleHighlight')}</span>
        </h1>
        <p className="max-w-3xl text-base text-base-content/72 sm:text-lg">{t('subtitle')}</p>
      </section>

      <section className="grid gap-4 md:grid-cols-3">
        {[
          { icon: Bot, title: t('geminiTitle'), desc: t('geminiDesc') },
          { icon: FileText, title: t('contractTitle'), desc: t('contractDesc') },
          { icon: BadgeDollarSign, title: t('stripeTitle'), desc: t('stripeDesc') },
        ].map((feature) => (
          <article key={feature.title} className="surface-card">
            <div className="card-body">
              <feature.icon className="h-6 w-6 text-primary" />
              <h2 className="card-title text-xl">{feature.title}</h2>
              <p className="text-sm text-base-content/70">{feature.desc}</p>
            </div>
          </article>
        ))}
      </section>
    </main>
  );
}
