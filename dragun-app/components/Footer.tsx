import { useTranslations } from 'next-intl';
import { Link } from '@/i18n/navigation';
import Logo from '@/components/Logo';
import FooterStatus from '@/components/FooterStatus';

export default function Footer() {
  const t = useTranslations('Footer');

  return (
    <footer className="border-t border-base-300/50 bg-base-200/20">
      <div className="app-shell py-10 sm:py-14 md:py-20">
        <div className="grid gap-8 sm:gap-12 grid-cols-1 sm:grid-cols-2 lg:grid-cols-12">
          <div className="space-y-5 sm:col-span-2 lg:col-span-5">
            <Logo className="h-8 w-auto" />
            <p className="max-w-sm text-sm text-base-content/50 leading-relaxed">
              {t('tagline')}
            </p>
            <div className="flex flex-wrap gap-2">
              {['tagStripe', 'tagAudit', 'tagRag', 'tagSoc'].map((key) => (
                <span key={key} className="rounded-full border border-base-300/60 bg-base-100 px-3 py-1 text-[9px] font-semibold uppercase tracking-widest text-base-content/35">
                  {t(key)}
                </span>
              ))}
            </div>
          </div>

          <div className="lg:col-span-2">
            <h2 className="text-[10px] font-bold uppercase tracking-[0.2em] text-base-content/35 mb-4">{t('platform')}</h2>
            <ul className="space-y-3 text-sm text-base-content/50">
              <li><Link href="/demo" className="hover:text-base-content transition-colors touch-manipulation">{t('demo')}</Link></li>
              <li><Link href="/features" className="hover:text-base-content transition-colors">{t('features')}</Link></li>
              <li><Link href="/pricing" className="hover:text-base-content transition-colors">{t('pricing')}</Link></li>
              <li><Link href="/integrations" className="hover:text-base-content transition-colors">{t('integrations')}</Link></li>
              <li><Link href="/faq" className="hover:text-base-content transition-colors">{t('faq')}</Link></li>
            </ul>
          </div>

          <div className="lg:col-span-2">
            <h2 className="text-[10px] font-bold uppercase tracking-[0.2em] text-base-content/35 mb-4">{t('company')}</h2>
            <ul className="space-y-3 text-sm text-base-content/50">
              <li><Link href="/about" className="hover:text-base-content transition-colors">{t('about')}</Link></li>
              <li><Link href="/contact" className="hover:text-base-content transition-colors">{t('contact')}</Link></li>
              <li><Link href="/legal" className="hover:text-base-content transition-colors">{t('legal')}</Link></li>
              <li><Link href="/legal" className="hover:text-base-content transition-colors">{t('security')}</Link></li>
            </ul>
          </div>

          <div className="lg:col-span-3">
            <h2 className="text-[10px] font-bold uppercase tracking-[0.2em] text-base-content/35 mb-4">{t('contactHeading')}</h2>
            <ul className="space-y-3 text-sm text-base-content/50">
              <li>hello@dragun.app</li>
              <li>legal@meziani.ai</li>
              <li>privacy@meziani.ai</li>
            </ul>

            <FooterStatus />
          </div>
        </div>

        <div className="mt-14 pt-6 border-t border-base-300/40 flex flex-col gap-3 sm:flex-row sm:items-center sm:justify-between">
          <p className="text-xs text-base-content/30">
            {t('copyright')}
          </p>
          <p className="text-xs text-base-content/25">
            {t('disclaimer')}
          </p>
        </div>
      </div>
    </footer>
  );
}
