import { useTranslations } from 'next-intl';
import { HelpCircle, ChevronRight } from 'lucide-react';

export default function FAQPage() {
  const t = useTranslations('FAQ');

  const faqs = [
    { q: t('q1'), a: t('a1') },
    { q: t('q2'), a: t('a2') },
    { q: t('q3'), a: t('a3') },
    { q: t('q4'), a: t('a4') },
  ];

  return (
    <main>
      <section className="hero-gradient py-16 sm:py-20">
        <div className="app-shell max-w-3xl space-y-5">
          <span className="badge badge-primary badge-outline text-[10px] font-bold uppercase tracking-widest">Knowledge base</span>
          <h1 className="text-4xl font-bold sm:text-5xl">
            {t('title')} <span className="text-base-content/40">{t('titleHighlight')}</span>
          </h1>
          <p className="max-w-2xl text-base text-base-content/60 leading-relaxed">{t('subtitle')}</p>
        </div>
      </section>

      <section className="py-16">
        <div className="app-shell mx-auto max-w-3xl space-y-4">
          {faqs.map((faq) => (
            <div key={faq.q} className="surface-card overflow-hidden">
              <details className="group">
                <summary className="flex cursor-pointer list-none items-center justify-between gap-4 px-6 py-5">
                  <div className="flex items-center gap-3">
                    <span className="flex h-9 w-9 shrink-0 items-center justify-center rounded-full border border-base-300 bg-base-200/50">
                      <HelpCircle className="h-4 w-4" />
                    </span>
                    <h2 className="text-base font-semibold sm:text-lg">{faq.q}</h2>
                  </div>
                  <ChevronRight className="h-4 w-4 shrink-0 text-base-content/40 transition-transform group-open:rotate-90" />
                </summary>
                <div className="border-t border-base-300 px-6 pb-6 pt-4">
                  <p className="text-sm text-base-content/60 leading-relaxed">{faq.a}</p>
                </div>
              </details>
            </div>
          ))}
        </div>
      </section>
    </main>
  );
}
