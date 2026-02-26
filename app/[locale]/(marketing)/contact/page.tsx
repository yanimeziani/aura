import { useTranslations } from 'next-intl';
import { Sparkles, Send, Mail, User, Tag, MessageSquare } from 'lucide-react';

export default function ContactPage() {
  const t = useTranslations('Contact');

  return (
    <main className="bg-background text-foreground">
      <section className="border-b border-border">
        <div className="mx-auto flex w-full max-w-7xl flex-col gap-8 px-4 pb-16 pt-20 sm:px-6 lg:px-8 lg:pt-24">
          <div className="inline-flex w-fit items-center gap-2 rounded-full border border-border bg-card px-4 py-2 text-[11px] font-semibold uppercase tracking-[0.18em] text-muted-foreground">
            <Sparkles className="h-3.5 w-3.5" />
            Direct Channel
          </div>
          <h1 className="max-w-4xl text-4xl font-semibold tracking-tightest sm:text-6xl">
            {t('title')} <span className="text-muted-foreground">{t('titleHighlight')}</span>
          </h1>
          <p className="max-w-3xl text-base text-muted-foreground sm:text-lg">{t('subtitle')}</p>
        </div>
      </section>

      <section>
        <div className="mx-auto w-full max-w-4xl px-4 py-16 sm:px-6 lg:px-8">
          <div className="rounded-2xl border border-border bg-card p-8 shadow-elev-2 sm:p-10">
            <form className="space-y-8">
              <div className="grid gap-6 md:grid-cols-2">
                <div className="space-y-2">
                  <label className="flex items-center gap-2 text-[11px] font-semibold uppercase tracking-[0.18em] text-muted-foreground">
                    <User className="h-3.5 w-3.5" />
                    {t('fullName')}
                  </label>
                  <input
                    type="text"
                    placeholder={t('fullNamePlaceholder')}
                    className="h-12 w-full rounded-xl border border-input bg-background px-4 text-sm text-foreground placeholder:text-muted-foreground focus:border-ring focus:outline-none"
                  />
                </div>
                <div className="space-y-2">
                  <label className="flex items-center gap-2 text-[11px] font-semibold uppercase tracking-[0.18em] text-muted-foreground">
                    <Mail className="h-3.5 w-3.5" />
                    {t('emailAddress')}
                  </label>
                  <input
                    type="email"
                    placeholder={t('emailPlaceholder')}
                    className="h-12 w-full rounded-xl border border-input bg-background px-4 text-sm text-foreground placeholder:text-muted-foreground focus:border-ring focus:outline-none"
                  />
                </div>
              </div>

              <div className="space-y-2">
                <label className="flex items-center gap-2 text-[11px] font-semibold uppercase tracking-[0.18em] text-muted-foreground">
                  <Tag className="h-3.5 w-3.5" />
                  {t('subject')}
                </label>
                <select className="h-12 w-full rounded-xl border border-input bg-background px-4 text-sm text-foreground focus:border-ring focus:outline-none">
                  <option>{t('subjectGeneral')}</option>
                  <option>{t('subjectSales')}</option>
                  <option>{t('subjectSupport')}</option>
                  <option>{t('subjectPartnerships')}</option>
                </select>
              </div>

              <div className="space-y-2">
                <label className="flex items-center gap-2 text-[11px] font-semibold uppercase tracking-[0.18em] text-muted-foreground">
                  <MessageSquare className="h-3.5 w-3.5" />
                  {t('message')}
                </label>
                <textarea
                  rows={6}
                  placeholder={t('messagePlaceholder')}
                  className="w-full rounded-xl border border-input bg-background px-4 py-3 text-sm text-foreground placeholder:text-muted-foreground focus:border-ring focus:outline-none"
                />
              </div>

              <button className="inline-flex h-11 w-full items-center justify-center gap-2 rounded-xl bg-primary text-sm font-semibold uppercase tracking-[0.14em] text-primary-foreground hover:opacity-90">
                {t('sendMessage')}
                <Send className="h-4 w-4" />
              </button>
            </form>
          </div>
        </div>
      </section>
    </main>
  );
}
