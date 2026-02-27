import { useTranslations } from 'next-intl';

export default function AboutPage() {
  const t = useTranslations('About');

  return (
    <main>
      <section className="hero-gradient py-16 sm:py-20">
        <div className="app-shell max-w-3xl space-y-5">
          <span className="badge badge-outline text-[10px] font-bold uppercase tracking-widest">{t('badge')}</span>
          <h1 className="text-4xl font-bold sm:text-5xl">
            {t('title')} <span className="text-base-content/40">{t('titleHighlight')}</span>
          </h1>
          <p className="max-w-2xl text-base text-base-content/60 leading-relaxed">{t('paragraph')}</p>
        </div>
      </section>

      <section className="py-16">
        <div className="app-shell grid gap-5 md:grid-cols-2">
          <article className="surface-card">
            <div className="card-body p-7">
              <h2 className="text-lg font-bold">{t('speedTitle')}</h2>
              <p className="mt-3 text-sm text-base-content/60 leading-relaxed">{t('speedDesc')}</p>
            </div>
          </article>
          <article className="surface-card">
            <div className="card-body p-7">
              <h2 className="text-lg font-bold">{t('foundedTitle')}</h2>
              <p className="mt-3 text-sm text-base-content/60 leading-relaxed">{t('foundedDesc')}</p>
            </div>
          </article>
        </div>
      </section>
    </main>
  );
}
