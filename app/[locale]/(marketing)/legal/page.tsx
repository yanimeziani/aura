import { useTranslations } from 'next-intl';

export default function LegalPage() {
  const t = useTranslations('Legal');

  const sections = [
    { title: t('privacyTitle'), content: t('privacyContent') },
    { title: t('tosTitle'), content: t('tosContent') },
    { title: t('complianceTitle'), content: t('complianceContent') },
  ];

  return (
    <main className="bg-background text-foreground">
      <section className="border-b border-border">
        <div className="mx-auto flex w-full max-w-5xl flex-col gap-8 px-4 pb-16 pt-20 sm:px-6 lg:px-8 lg:pt-24">
          <div className="inline-flex w-fit items-center rounded-full border border-border bg-card px-4 py-2 text-[11px] font-semibold uppercase tracking-[0.18em] text-muted-foreground">
            {t('badge')}
          </div>
          <h1 className="max-w-4xl text-4xl font-semibold tracking-tightest sm:text-6xl">
            {t('title')} <span className="text-muted-foreground">{t('titleHighlight')}</span>
          </h1>
          <p className="max-w-3xl text-base text-muted-foreground sm:text-lg">{t('subtitle')}</p>
        </div>
      </section>

      <section>
        <div className="mx-auto w-full max-w-5xl space-y-5 px-4 py-16 sm:px-6 lg:px-8">
          {sections.map((section) => (
            <article key={section.title} className="rounded-2xl border border-border bg-card p-7 shadow-elev-1 sm:p-8">
              <h2 className="text-xl font-semibold">{section.title}</h2>
              <p className="mt-4 text-sm leading-relaxed text-muted-foreground">{section.content}</p>
            </article>
          ))}
        </div>
      </section>
    </main>
  );
}
