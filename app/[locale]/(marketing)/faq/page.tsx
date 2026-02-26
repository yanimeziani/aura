import { useTranslations } from 'next-intl';
import { Sparkles, HelpCircle, ChevronRight } from 'lucide-react';

export default function FAQPage() {
  const t = useTranslations('FAQ');

  const faqs = [
    { q: t('q1'), a: t('a1') },
    { q: t('q2'), a: t('a2') },
    { q: t('q3'), a: t('a3') },
    { q: t('q4'), a: t('a4') },
  ];

  return (
    <main className="bg-background text-foreground">
      <section className="border-b border-border">
        <div className="mx-auto flex w-full max-w-7xl flex-col gap-8 px-4 pb-16 pt-20 sm:px-6 lg:px-8 lg:pt-24">
          <div className="inline-flex w-fit items-center gap-2 rounded-full border border-border bg-card px-4 py-2 text-[11px] font-semibold uppercase tracking-[0.18em] text-muted-foreground">
            <Sparkles className="h-3.5 w-3.5" />
            Knowledge Base
          </div>
          <h1 className="max-w-4xl text-4xl font-semibold tracking-tightest sm:text-6xl">
            {t('title')} <span className="text-muted-foreground">{t('titleHighlight')}</span>
          </h1>
          <p className="max-w-3xl text-base text-muted-foreground sm:text-lg">{t('subtitle')}</p>
        </div>
      </section>

      <section>
        <div className="mx-auto w-full max-w-4xl space-y-4 px-4 py-16 sm:px-6 lg:px-8">
          {faqs.map((faq) => (
            <article key={faq.q} className="rounded-2xl border border-border bg-card shadow-elev-1">
              <details className="group">
                <summary className="flex cursor-pointer list-none items-center justify-between gap-4 px-6 py-5 sm:px-8">
                  <div className="flex items-center gap-3">
                    <span className="inline-flex h-9 w-9 items-center justify-center rounded-full border border-border bg-background">
                      <HelpCircle className="h-4 w-4 text-foreground" />
                    </span>
                    <h2 className="text-base font-semibold sm:text-lg">{faq.q}</h2>
                  </div>
                  <ChevronRight className="h-4 w-4 shrink-0 text-muted-foreground transition-transform group-open:rotate-90" />
                </summary>
                <div className="border-t border-border px-6 pb-6 pt-4 sm:px-8">
                  <p className="text-sm text-muted-foreground">{faq.a}</p>
                </div>
              </details>
            </article>
          ))}
        </div>
      </section>
    </main>
  );
}
