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
    <main>
      <section className="hero-gradient py-16 sm:py-20">
        <div className="app-shell max-w-3xl space-y-5">
          <span className="badge badge-primary badge-outline text-[10px] font-bold uppercase tracking-widest">{t('subtitle')}</span>
          <h1 className="text-4xl font-bold sm:text-5xl">
            {t('title')} <span className="text-base-content/40">{t('titleHighlight')}</span>
          </h1>
          <p className="max-w-2xl text-base text-base-content/60 leading-relaxed">{t('supporting')}</p>
        </div>
      </section>

      <section className="py-16">
        <div className="app-shell grid gap-5 sm:grid-cols-2 lg:grid-cols-4">
          {integrations.map((item) => (
            <article key={item.name} className="surface-card">
              <div className="card-body p-6">
                <div className="flex items-center justify-between">
                  <span className="text-2xl">{item.icon}</span>
                  <span className={`badge badge-sm ${item.status === 'upcoming' ? 'badge-outline' : 'badge-success badge-outline'}`}>
                    {item.status === 'upcoming' ? t('upcoming') : 'Active'}
                  </span>
                </div>
                <h2 className="mt-4 text-lg font-bold">{item.name}</h2>
                <p className="mt-2 text-sm text-base-content/60 leading-relaxed">{item.description}</p>
              </div>
            </article>
          ))}
        </div>
      </section>
    </main>
  );
}
