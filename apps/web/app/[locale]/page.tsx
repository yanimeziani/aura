import { useTranslations } from 'next-intl';
import { Link } from '@/i18n/navigation';
import { Shield, Zap, Calendar, ArrowRight, Activity, Terminal, Lock } from 'lucide-react';
import Navbar from '@/components/Navbar';
import Footer from '@/components/Footer';

export default function LandingPage() {
  const t = useTranslations('Home');

  return (
    <div className="min-h-screen bg-black text-white font-mono selection:bg-white selection:text-black">
      <Navbar />

      <main>
        {/* HERO SECTION */}
        <section className="relative pt-20 pb-32 overflow-hidden border-b-4 border-white/10">
          <div className="container mx-auto px-6 relative z-10">
            <div className="max-w-4xl space-y-8">
              <div className="inline-flex items-center gap-2 px-3 py-1 border-2 border-white/20 text-[10px] font-bold tracking-widest uppercase animate-pulse">
                <Activity className="w-3 h-3 text-green-400" /> SYSTEM_ACTIVE // SOVEREIGN_MODE
              </div>
              
              <h1 className="text-5xl md:text-7xl lg:text-8xl font-black tracking-tighter leading-none uppercase italic">
                {t('heroLine1')} <br />
                <span className="text-outline-white text-transparent">{t('heroLine2')}</span>
              </h1>
              
              <p className="text-lg md:text-xl opacity-70 max-w-2xl leading-relaxed">
                {t('heroParagraph')}
              </p>

              <div className="flex flex-col sm:flex-row gap-6 pt-8">
                <Link
                  href="/login"
                  className="bg-white text-black px-10 py-4 text-xl font-black uppercase tracking-tighter hover:bg-green-400 transition-all flex items-center justify-between group"
                >
                  {t('launchAgent')} <ArrowRight className="w-6 h-6 group-hover:translate-x-2 transition-transform" />
                </Link>
                <Link
                  href="/demo"
                  className="border-4 border-white px-10 py-4 text-xl font-black uppercase tracking-tighter hover:bg-white hover:text-black transition-all flex items-center justify-center gap-2"
                >
                  {t('watchDemo')}
                </Link>
              </div>
            </div>
          </div>

          {/* BACKGROUND DECOR */}
          <div className="absolute top-0 right-0 w-1/2 h-full opacity-10 pointer-events-none hidden lg:block">
            <div className="grid grid-cols-10 h-full border-l border-white/20">
              {Array.from({ length: 100 }).map((_, i) => (
                <div key={i} className="border border-white/10 aspect-square" />
              ))}
            </div>
          </div>
        </section>

        {/* STATS STRIP */}
        <div className="border-b-4 border-white/10 bg-white/5 py-4">
          <div className="container mx-auto px-6 flex flex-wrap justify-between items-center gap-8 text-[10px] font-bold uppercase tracking-[0.3em] opacity-50">
            <span className="flex items-center gap-2 italic"><Zap className="w-3 h-3" /> {t('pilotMedian')}: 82%</span>
            <span className="flex items-center gap-2"><Lock className="w-3 h-3" /> {t('p50Latency')}: 1.4s</span>
            <span className="flex items-center gap-2 italic"><Terminal className="w-3 h-3" /> {t('activePilots')}: 12</span>
            <span className="flex items-center gap-2"><Shield className="w-3 h-3" /> {t('liveDeployments')}: ACTIVE</span>
          </div>
        </div>

        {/* FEATURES GRID */}
        <section className="py-32 bg-black">
          <div className="container mx-auto px-6">
            <div className="flex flex-col md:flex-row justify-between items-end gap-8 mb-20">
              <div className="max-w-2xl space-y-4">
                <h2 className="text-4xl md:text-6xl font-black uppercase tracking-tighter italic italic underline decoration-white decoration-8 underline-offset-8">
                  {t('featSectionTitle')}
                </h2>
                <p className="opacity-50 text-sm uppercase tracking-widest">{t('featSectionDesc')}</p>
              </div>
              <div className="text-right">
                <span className="text-[10px] font-bold opacity-30 uppercase tracking-[0.5em]">OPERATIONAL_CAPABILITIES</span>
              </div>
            </div>

            <div className="grid grid-cols-1 md:grid-cols-3 gap-0 border-4 border-white">
              {[
                { title: t('featAiTitle'), desc: t('featAiDesc'), icon: <Zap /> },
                { title: t('featContractTitle'), desc: t('featContractDesc'), icon: <Terminal /> },
                { title: t('featStripeTitle'), desc: t('featStripeDesc'), icon: <Shield /> },
                { title: t('featAnalyticsTitle'), desc: t('featAnalyticsDesc'), icon: <Activity /> },
                { title: t('featComplianceTitle'), desc: t('featComplianceDesc'), icon: <Lock /> },
                { title: t('featSecurityTitle'), desc: t('featSecurityDesc'), icon: <Calendar /> },
              ].map((f, i) => (
                <div key={i} className="p-10 border border-white/20 hover:bg-white hover:text-black transition-all group">
                  <div className="mb-6 p-3 border-2 border-white inline-block group-hover:border-black transition-colors">
                    {f.icon}
                  </div>
                  <h3 className="text-2xl font-black uppercase tracking-tighter mb-4 italic">{f.title}</h3>
                  <p className="text-sm opacity-60 group-hover:opacity-100 transition-opacity leading-relaxed font-sans">{f.desc}</p>
                </div>
              ))}
            </div>
          </div>
        </section>

        {/* MISSION STRIP */}
        <section className="bg-white text-black py-20 overflow-hidden">
          <div className="whitespace-nowrap flex animate-marquee text-7xl md:text-9xl font-black uppercase italic tracking-tighter opacity-10">
            {Array.from({ length: 10 }).map((_, i) => (
              <span key={i} className="mx-8">{t('heroLine2')}</span>
            ))}
          </div>
          <div className="container mx-auto px-6 -mt-20 relative z-10 text-center space-y-8">
            <h2 className="text-4xl md:text-6xl font-black uppercase tracking-tighter max-w-3xl mx-auto">
              {t('ctaTitle1')} {t('ctaTitle2')}
            </h2>
            <p className="text-xl max-w-xl mx-auto font-sans">
              {t('ctaSubtitle')}
            </p>
            <div className="pt-8">
              <Link
                href="/login"
                className="bg-black text-white px-12 py-5 text-2xl font-black uppercase tracking-tighter hover:bg-green-400 hover:text-black transition-all inline-flex items-center gap-4"
              >
                {t('ctaButton')} <ArrowRight className="w-8 h-8" />
              </Link>
            </div>
          </div>
        </section>
      </main>

      <Footer />
    </div>
  );
}
