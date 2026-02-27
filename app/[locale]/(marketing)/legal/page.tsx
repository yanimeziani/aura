import { useTranslations } from 'next-intl';

export default function LegalPage() {
  const t = useTranslations('Legal');

  const sections = [
    { title: t('privacyTitle'), content: t('privacyContent') },
    { title: t('tosTitle'), content: t('tosContent') },
    { title: t('complianceTitle'), content: t('complianceContent') },
  ];

  return (
    <main>
      <section className="hero-gradient py-16 sm:py-20">
        <div className="app-shell max-w-3xl space-y-5">
          <span className="badge badge-outline text-[10px] font-bold uppercase tracking-widest">{t('badge')}</span>
          <h1 className="text-4xl font-bold sm:text-5xl">
            {t('title')} <span className="text-base-content/40">{t('titleHighlight')}</span>
          </h1>
          <p className="max-w-2xl text-base text-base-content/60 leading-relaxed">{t('subtitle')}</p>
        </div>
      </section>

      <section className="py-16">
        <div className="app-shell space-y-5 max-w-4xl">
          {sections.map((section) => (
            <article key={section.title} className="surface-card">
              <div className="card-body p-7 sm:p-8">
                <h2 className="text-xl font-bold">{section.title}</h2>
                <p className="mt-4 text-sm leading-relaxed text-base-content/60">{section.content}</p>
              </div>
            </article>
          ))}
        </div>
      </section>
    </main>
  );
}
