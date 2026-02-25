import { useTranslations } from 'next-intl';
import { Link } from '@/i18n/navigation';

export default function Footer() {
  const t = useTranslations('Footer');

  return (
    <footer className="px-6 py-20 bg-[#050505] border-t border-white/5">
      <div className="max-w-7xl mx-auto grid grid-cols-1 md:grid-cols-4 gap-12 md:gap-8">
        <div className="col-span-1 md:col-span-2 space-y-6">
          <div className="flex items-center gap-2 group">
            <div className="w-8 h-8 bg-gradient-to-br from-[#1a1a1a] to-[#0a0a0a] border border-white/10 rounded-xl flex items-center justify-center font-bold text-[#D4AF37] shadow-lg">🐲</div>
            <span className="text-xl font-bold tracking-tighter text-white">Dragun<span className="text-[#D4AF37]">.app</span></span>
          </div>
          <p className="text-sm text-white/40 max-w-xs leading-relaxed">
            {t('tagline')}
          </p>
          <div className="text-[10px] font-bold uppercase tracking-[0.2em] text-white/30">
            {t('copyright')}
          </div>
        </div>
        <div className="space-y-4">
          <h6 className="text-[10px] font-black uppercase tracking-[0.3em] text-white/70">{t('platform')}</h6>
          <div className="flex flex-col gap-3 text-sm text-white/40 font-medium">
            <Link href="/features" className="hover:text-[#D4AF37] transition-colors">{t('features')}</Link>
            <Link href="/pricing" className="hover:text-[#D4AF37] transition-colors">{t('pricing')}</Link>
            <Link href="/integrations" className="hover:text-[#D4AF37] transition-colors">{t('integrations')}</Link>
          </div>
        </div>
        <div className="space-y-4">
          <h6 className="text-[10px] font-black uppercase tracking-[0.3em] text-white/70">{t('company')}</h6>
          <div className="flex flex-col gap-3 text-sm text-white/40 font-medium">
            <Link href="/about" className="hover:text-[#D4AF37] transition-colors">{t('about')}</Link>
            <Link href="/contact" className="hover:text-[#D4AF37] transition-colors">{t('contact')}</Link>
            <Link href="/legal" className="hover:text-[#D4AF37] transition-colors">{t('legal')}</Link>
          </div>
        </div>
      </div>
    </footer>
  );
}
