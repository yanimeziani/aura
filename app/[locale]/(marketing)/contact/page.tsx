import type { Metadata } from 'next';
import { useTranslations } from 'next-intl';

export const metadata: Metadata = {
  title: 'Contact | Dragun.app — Get in Touch',
  description: 'Questions about AI debt recovery? Contact the Dragun team for sales, support, or partnership inquiries.',
  openGraph: {
    title: 'Contact | Dragun.app',
    description: 'Reach the Dragun team for sales, support, or partnership inquiries.',
  },
};
import { Send, Mail, User, Tag, MessageSquare } from 'lucide-react';

export default function ContactPage() {
  const t = useTranslations('Contact');

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
              <form className="space-y-6">
                <div className="grid gap-5 md:grid-cols-2">
                  <div className="space-y-2">
                    <label className="flex items-center gap-2 text-label">
                      <User className="h-3.5 w-3.5" />
                      {t('fullName')}
                    </label>
                    <input type="text" placeholder={t('fullNamePlaceholder')} className="input input-bordered w-full min-h-11" />
                  </div>
                  <div className="space-y-2">
                    <label className="flex items-center gap-2 text-label">
                      <Mail className="h-3.5 w-3.5" />
                      {t('emailAddress')}
                    </label>
                    <input type="email" placeholder={t('emailPlaceholder')} className="input input-bordered w-full min-h-11" />
                  </div>
                </div>

                <div className="space-y-2">
                  <label className="flex items-center gap-2 text-label">
                    <Tag className="h-3.5 w-3.5" />
                    {t('subject')}
                  </label>
                  <select className="select select-bordered w-full min-h-11">
                    <option>{t('subjectGeneral')}</option>
                    <option>{t('subjectSales')}</option>
                    <option>{t('subjectSupport')}</option>
                    <option>{t('subjectPartnerships')}</option>
                  </select>
                </div>

                <div className="space-y-2">
                  <label className="flex items-center gap-2 text-label">
                    <MessageSquare className="h-3.5 w-3.5" />
                    {t('message')}
                  </label>
                  <textarea rows={6} placeholder={t('messagePlaceholder')} className="textarea textarea-bordered w-full min-h-32" />
                </div>

                <button type="submit" className="btn btn-primary w-full gap-2 min-h-12 text-xs font-bold uppercase tracking-widest">
                  {t('sendMessage')}
                  <Send className="h-4 w-4" />
                </button>
              </form>
            </div>
          </div>
        </div>
      </section>
    </main>
  );
}
