import { useTranslations } from 'next-intl';
import { Link } from '@/i18n/navigation';
import Logo from '@/components/Logo';

export default function Footer() {
  const t = useTranslations('Footer');

  return (
    <footer className="border-t border-border bg-background">
      <div className="mx-auto grid w-full max-w-7xl grid-cols-1 gap-12 px-4 py-16 sm:px-6 lg:grid-cols-4 lg:px-8">
        <div className="space-y-5 lg:col-span-2">
          <Logo className="h-8 w-auto" />
          <p className="max-w-md text-sm text-muted-foreground">{t('tagline')}</p>
          <div className="space-y-1 text-xs text-muted-foreground">
            <p>{t('trustLine')}</p>
            <p>{t('disclaimer')}</p>
          </div>
          <p className="text-[11px] text-muted-foreground">{t('copyright')}</p>
        </div>

        <div className="space-y-4">
          <h6 className="text-[11px] font-semibold uppercase tracking-[0.18em] text-foreground">{t('platform')}</h6>
          <div className="flex flex-col gap-2 text-sm text-muted-foreground">
            <Link href="/features" className="hover:text-foreground">{t('features')}</Link>
            <Link href="/pricing" className="hover:text-foreground">{t('pricing')}</Link>
            <Link href="/integrations" className="hover:text-foreground">{t('integrations')}</Link>
            <Link href="/faq" className="hover:text-foreground">{t('faq')}</Link>
          </div>
        </div>

        <div className="space-y-4">
          <h6 className="text-[11px] font-semibold uppercase tracking-[0.18em] text-foreground">{t('company')}</h6>
          <div className="flex flex-col gap-2 text-sm text-muted-foreground">
            <Link href="/about" className="hover:text-foreground">{t('about')}</Link>
            <Link href="/contact" className="hover:text-foreground">{t('contact')}</Link>
            <Link href="/legal" className="hover:text-foreground">{t('legal')}</Link>
            <Link href="/legal" className="hover:text-foreground">{t('security')}</Link>
          </div>
        </div>
      </div>
    </footer>
  );
}
