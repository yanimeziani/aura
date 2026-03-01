import type { Metadata } from 'next';
import { getTranslations } from 'next-intl/server';
import ContactForm from '@/components/contact/ContactForm';

export const metadata: Metadata = {
  title: 'Contact | Dragun.app — Get in Touch',
  description: 'Questions about AI debt recovery? Contact the Dragun team for sales, support, or partnership inquiries.',
  openGraph: {
    title: 'Contact | Dragun.app',
    description: 'Reach the Dragun team for sales, support, or partnership inquiries.',
  },
};

export default async function ContactPage() {
  const t = await getTranslations('Contact');

  return (
    <main>
      <section className="hero-gradient py-16 sm:py-20">
        <div className="app-shell max-w-3xl space-y-5">
          <span className="badge badge-primary badge-outline text-[10px] font-bold uppercase tracking-widest">{t('badge')}</span>
          <h1 className="text-4xl font-bold sm:text-5xl">
            {t('title')} <span className="text-base-content/40">{t('titleHighlight')}</span>
          </h1>
          <p className="max-w-2xl text-base text-base-content/60 leading-relaxed">{t('subtitle')}</p>
        </div>
      </section>

      <section className="py-16">
        <div className="app-shell">
          <div className="surface-card-elevated mx-auto max-w-3xl">
            <div className="card-body p-8 sm:p-10">
              <ContactForm />
            </div>
          </div>
        </div>
      </section>
    </main>
  );
}
