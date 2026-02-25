import { useTranslations } from 'next-intl';
import { Link } from '@/i18n/navigation';

export default function Footer() {
  const t = useTranslations('Footer');

  return (
    <footer className="px-6 py-20 bg-bg border-t border-white/10">
      <div className="max-w-7xl mx-auto grid grid-cols-1 md:grid-cols-4 gap-12 md:gap-8">
        <div className="col-span-1 md:col-span-2 space-y-6">
          <div className="flex items-center gap-2 group">
            <div className="w-8 h-8 bg-gradient-to-br from-[#1B2333] to-[#0D1520] border border-white/10 rounded-xl flex items-center justify-center font-bold text-text-primary shadow-lg">🐲</div>
            <span className="text-xl font-bold tracking-tighter text-text-primary">Dragun<span className="text-accent-indigo">.app</span></span>
          </div>
          <p className="text-sm text-text-muted max-w-xs leading-relaxed">
            {t('tagline')}
          </p>
          <div className="text-[10px] font-bold uppercase tracking-[0.2em] text-text-subtle">
            {t('copyright')}
          </div>
        </div>
        <div className="space-y-4">
          <h6 className="text-[10px] font-black uppercase tracking-[0.3em] text-text-muted">{t('platform')}</h6>
          <div className="flex flex-col gap-3 text-sm text-text-muted font-medium">
            <Link href="/features" className="hover:text-accent-indigo transition-colors">{t('features')}</Link>
            <Link href="/pricing" className="hover:text-accent-indigo transition-colors">{t('pricing')}</Link>
            <Link href="/integrations" className="hover:text-accent-indigo transition-colors">{t('integrations')}</Link>
          </div>
        </div>
        <div className="space-y-4">
          <h6 className="text-[10px] font-black uppercase tracking-[0.3em] text-text-muted">{t('company')}</h6>
          <div className="flex flex-col gap-3 text-sm text-text-muted font-medium">
            <Link href="/about" className="hover:text-accent-emerald transition-colors">{t('about')}</Link>
            <Link href="/contact" className="hover:text-accent-emerald transition-colors">{t('contact')}</Link>
            <Link href="/legal" className="hover:text-accent-emerald transition-colors">{t('legal')}</Link>
          </div>
        </div>
      </div>
    </footer>
  );
}
