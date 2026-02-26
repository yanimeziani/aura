import { useTranslations } from 'next-intl';

export default function AboutPage() {
  const t = useTranslations('About');

  return (
    <main className="bg-background text-foreground">
      <section className="border-b border-border">
        <div className="mx-auto flex w-full max-w-6xl flex-col gap-8 px-4 pb-16 pt-20 sm:px-6 lg:px-8 lg:pt-24">
          <div className="inline-flex w-fit items-center rounded-full border border-border bg-card px-4 py-2 text-[11px] font-semibold uppercase tracking-[0.18em] text-muted-foreground">
            {t('badge')}
          </div>
          <h1 className="max-w-4xl text-4xl font-semibold tracking-tightest sm:text-6xl">
            {t('title')} <span className="text-muted-foreground">{t('titleHighlight')}</span>
          </h1>
          <p className="max-w-3xl text-base text-muted-foreground sm:text-lg">{t('paragraph')}</p>
        </div>
      </section>

      <section>
        <div className="mx-auto grid w-full max-w-6xl grid-cols-1 gap-6 px-4 py-16 sm:px-6 md:grid-cols-2 lg:px-8">
          <article className="rounded-2xl border border-border bg-card p-8 shadow-elev-1">
            <h2 className="text-lg font-semibold">{t('speedTitle')}</h2>
            <p className="mt-3 text-sm text-muted-foreground">{t('speedDesc')}</p>
          </article>
          <article className="rounded-2xl border border-border bg-card p-8 shadow-elev-1">
            <h2 className="text-lg font-semibold">{t('foundedTitle')}</h2>
            <p className="mt-3 text-sm text-muted-foreground">{t('foundedDesc')}</p>
          </article>
        </div>
      </section>
    </main>
  );
}
