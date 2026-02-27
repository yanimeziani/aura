import { useTranslations } from 'next-intl';
import { Link } from '@/i18n/navigation';
import Logo from '@/components/Logo';

export default function Footer() {
  const t = useTranslations('Footer');

  return (
    <footer className="mt-16 border-t border-base-300/80 bg-base-200/40">
      <div className="app-shell py-12 sm:py-16">
        <div className="grid gap-10 sm:grid-cols-2 lg:grid-cols-12">
          <div className="space-y-4 sm:col-span-2 lg:col-span-6">
            <Logo className="h-8 w-auto" />
            <p className="max-w-xl text-sm text-base-content/75">{t('tagline')}</p>
            <p className="text-xs text-base-content/60">{t('trustLine')}</p>
            <p className="text-xs text-base-content/60">{t('disclaimer')}</p>
            <p className="text-xs text-base-content/45">{t('copyright')}</p>
          </div>

          <div className="lg:col-span-3">
            <h2 className="mb-4 text-sm font-semibold text-base-content">{t('platform')}</h2>
            <ul className="space-y-2 text-sm text-base-content/70">
              <li><Link href="/features" className="hover:text-base-content">{t('features')}</Link></li>
              <li><Link href="/pricing" className="hover:text-base-content">{t('pricing')}</Link></li>
              <li><Link href="/integrations" className="hover:text-base-content">{t('integrations')}</Link></li>
              <li><Link href="/faq" className="hover:text-base-content">{t('faq')}</Link></li>
            </ul>
          </div>

          <div className="lg:col-span-3">
            <h2 className="mb-4 text-sm font-semibold text-base-content">{t('company')}</h2>
            <ul className="space-y-2 text-sm text-base-content/70">
              <li><Link href="/about" className="hover:text-base-content">{t('about')}</Link></li>
              <li><Link href="/contact" className="hover:text-base-content">{t('contact')}</Link></li>
              <li><Link href="/legal" className="hover:text-base-content">{t('legal')}</Link></li>
              <li><Link href="/legal" className="hover:text-base-content">{t('security')}</Link></li>
            </ul>
          </div>
        </div>
      </div>
    </footer>
  );
}
