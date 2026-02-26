import { useTranslations } from 'next-intl';

export default function IntegrationsPage() {
  const t = useTranslations('Integrations');

  const integrations = [
    { name: 'Stripe', description: t('stripeDesc'), status: 'active', icon: '💳' },
    { name: 'Supabase', description: t('supabaseDesc'), status: 'active', icon: '⚡' },
    { name: 'Gemini 2.0 Flash', description: t('geminiDesc'), status: 'active', icon: '🐉' },
    { name: t('mindbodyName'), description: t('mindbodyDesc'), status: 'upcoming', icon: '🧘' },
  ];

  return (
    <main className="bg-background text-foreground">
      <section className="border-b border-border">
        <div className="mx-auto flex w-full max-w-6xl flex-col gap-8 px-4 pb-16 pt-20 sm:px-6 lg:px-8 lg:pt-24">
          <div className="inline-flex w-fit items-center rounded-full border border-border bg-card px-4 py-2 text-[11px] font-semibold uppercase tracking-[0.18em] text-muted-foreground">
            {t('subtitle')}
          </div>
          <h1 className="max-w-4xl text-4xl font-semibold tracking-tightest sm:text-6xl">
            {t('title')} <span className="text-muted-foreground">{t('titleHighlight')}</span>
          </h1>
          <p className="max-w-3xl text-base text-muted-foreground sm:text-lg">{t('supporting')}</p>
        </div>
      </section>

      <section>
        <div className="mx-auto grid w-full max-w-6xl grid-cols-1 gap-6 px-4 py-16 sm:px-6 md:grid-cols-2 lg:grid-cols-4 lg:px-8">
          {integrations.map((integration) => (
            <article key={integration.name} className="rounded-2xl border border-border bg-card p-6 shadow-elev-1">
              <div className="flex items-center justify-between">
                <span className="text-2xl">{integration.icon}</span>
                <span
                  className={`rounded-full border px-2.5 py-1 text-[10px] font-semibold uppercase tracking-[0.14em] ${
                    integration.status === 'upcoming'
                      ? 'border-border bg-background text-muted-foreground'
                      : 'border-ring bg-popover text-foreground'
                  }`}
                >
                  {integration.status === 'upcoming' ? t('upcoming') : 'Active'}
                </span>
              </div>
              <h2 className="mt-4 text-lg font-semibold">{integration.name}</h2>
              <p className="mt-3 text-sm text-muted-foreground">{integration.description}</p>
            </article>
          ))}
        </div>
      </section>
    </main>
  );
}
