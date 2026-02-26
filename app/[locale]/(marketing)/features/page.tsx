import { useTranslations } from 'next-intl';
import { Bot, FileText, BadgeDollarSign, Sparkles } from 'lucide-react';

export default function FeaturesPage() {
  const t = useTranslations('Features');

  return (
    <main className="bg-background text-foreground">
      <section className="border-b border-border">
        <div className="mx-auto flex w-full max-w-7xl flex-col gap-8 px-4 pb-16 pt-20 sm:px-6 lg:px-8 lg:pt-24">
          <div className="inline-flex w-fit items-center gap-2 rounded-full border border-border bg-card px-4 py-2 text-[11px] font-semibold uppercase tracking-[0.18em] text-muted-foreground">
            <Sparkles className="h-3.5 w-3.5" />
            Platform Capabilities
          </div>
          <h1 className="max-w-4xl text-4xl font-semibold tracking-tightest sm:text-6xl">
            {t('title')} <span className="text-muted-foreground">{t('titleHighlight')}</span>
          </h1>
          <p className="max-w-3xl text-base text-muted-foreground sm:text-lg">{t('subtitle')}</p>
        </div>
      </section>

      <section>
        <div className="mx-auto grid w-full max-w-7xl grid-cols-1 gap-6 px-4 py-16 sm:px-6 md:grid-cols-3 lg:px-8">
          {[
            { icon: Bot, title: t('geminiTitle'), desc: t('geminiDesc') },
            { icon: FileText, title: t('contractTitle'), desc: t('contractDesc') },
            { icon: BadgeDollarSign, title: t('stripeTitle'), desc: t('stripeDesc') },
          ].map((feature) => (
            <div key={feature.title} className="rounded-2xl border border-border bg-card p-8 shadow-elev-1">
              <feature.icon className="h-6 w-6 text-foreground" />
              <h2 className="mt-4 text-lg font-semibold">{feature.title}</h2>
              <p className="mt-3 text-sm text-muted-foreground">{feature.desc}</p>
            </div>
          ))}
        </div>
      </section>
    </main>
  );
}
