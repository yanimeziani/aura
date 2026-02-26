import { useTranslations } from 'next-intl';
import { Link } from '@/i18n/navigation';
import { ArrowRight, Bot, ShieldCheck, Zap, BarChart3, Globe, Sparkles, ChevronRight } from 'lucide-react';
import Logo from '@/components/Logo';

export default function LandingPage() {
  const t = useTranslations('Home');

  return (
    <div className="relative isolate bg-bg">
      {/* Premium Ambient Background */}
      <div className="absolute inset-0 -z-10 overflow-hidden pointer-events-none dot-grid">
        <div className="absolute top-[-20%] left-[-10%] w-[60%] h-[60%] bg-accent-indigo/10 blur-[140px] rounded-full"></div>
        <div className="absolute bottom-[-15%] right-[-10%] w-[55%] h-[55%] bg-accent-emerald/10 blur-[140px] rounded-full"></div>
        <div className="absolute inset-0 bg-[radial-gradient(circle_at_top,rgba(255,255,255,0.05)_0%,transparent_60%)]"></div>
      </div>

      {/* Hero Section */}
      <main className="max-w-7xl mx-auto px-6 pt-24 pb-20 md:pt-40 md:pb-40 flex flex-col items-center text-center relative z-10">
        <div className="inline-flex items-center gap-2 px-4 py-1.5 rounded-full border border-white/10 bg-white/[0.03] backdrop-blur-xl text-text-muted text-[10px] font-black tracking-[0.3em] uppercase mb-12 animate-in fade-in slide-in-from-top-4 duration-1000">
          <Sparkles className="w-3 h-3 text-accent-indigo" />
          {t('badge')}
        </div>

        <h1 className="text-5xl md:text-[96px] font-black tracking-[-0.04em] leading-[0.9] mb-10 text-text-primary uppercase group font-display">
          <span className="block">{t('heroLine1')}</span>
          <span className="block gradient-text bg-[length:200%_auto] animate-gradient-x tracking-tight lowercase mt-2">
            {t('heroLine2')}
          </span>
        </h1>

        <p className="text-base md:text-lg text-white/60 max-w-2xl mx-auto leading-relaxed mb-16 font-medium tracking-tight">
          {t('heroParagraph')}
        </p>

        <div className="flex flex-col sm:flex-row gap-6 w-full sm:w-auto">
          <Link href="/dashboard" className="h-16 px-12 rounded-2xl bg-accent-indigo text-white font-black text-xs uppercase tracking-[0.2em] flex items-center justify-center gap-3 hover:bg-accent-indigo-hover transition-all active:scale-95 shadow-glow-indigo group">
            {t('launchAgent')}
            <ChevronRight className="w-4 h-4 group-hover:translate-x-1 transition-transform" />
          </Link>
          <Link href="/about" className="h-16 px-12 rounded-2xl bg-accent-emerald text-white font-black text-xs uppercase tracking-[0.2em] flex items-center justify-center hover:bg-accent-emerald-hover transition-all active:scale-95 shadow-glow-emerald">
            {t('howItWorks')}
          </Link>
        </div>

        {/* Bento Grid Preview */}
        <div className="mt-40 grid grid-cols-1 md:grid-cols-12 gap-8 w-full max-w-6xl relative">
          <div className="absolute -inset-4 bg-accent-indigo/10 blur-[100px] rounded-full pointer-events-none opacity-50"></div>
          
          {/* Main Agent Interface */}
          <div className="md:col-span-8 group relative rounded-[3rem] border border-white/10 glass-card p-1 overflow-hidden transition-all hover:border-accent-indigo/40 shadow-2xl">
            <div className="bg-white/[0.02] rounded-[2.8rem] p-8 md:p-10 h-[500px] flex flex-col">
              <div className="flex items-center justify-between mb-12">
                <div className="flex items-center gap-4">
                  <Logo className="h-8 w-auto" />
                  <div>
                    <div className="text-xs font-black text-text-primary uppercase tracking-[0.2em]">{t('agentName')}</div>
                    <div className="text-[9px] text-accent-emerald font-black flex items-center gap-1.5 uppercase tracking-widest mt-1">
                      <div className="w-1.5 h-1.5 bg-accent-emerald rounded-full animate-pulse"></div> {t('agentStatus')}
                    </div>
                  </div>
                </div>
                <div className="flex gap-2">
                   <div className="px-3 py-1 rounded-full bg-white/10 border border-white/10 text-[9px] font-black text-text-muted uppercase tracking-widest">ENCRYPTED</div>
                </div>
              </div>

              <div className="space-y-6 flex-1 overflow-hidden">
                <div className="flex justify-start">
                   <div className="max-w-[80%] bg-white/[0.06] border border-white/10 p-4 rounded-2xl rounded-tl-none text-xs text-text-muted leading-relaxed font-medium">
                     {t('chatBubble1')}
                   </div>
                </div>
                <div className="flex justify-end">
                   <div className="max-w-[80%] bg-accent-indigo text-white p-4 rounded-2xl rounded-tr-none text-xs font-bold shadow-2xl">
                     {t('chatBubble2')}
                   </div>
                </div>
                <div className="flex justify-start">
                   <div className="max-w-[80%] bg-white/[0.06] border border-white/10 p-4 rounded-2xl rounded-tl-none text-xs text-text-muted leading-relaxed font-medium">
                     {t('chatBubble3')}
                   </div>
                </div>
              </div>

              <div className="mt-8 flex gap-3">
                <div className="h-12 flex-1 bg-white/[0.04] rounded-xl border border-white/10 px-4 flex items-center text-text-subtle text-xs font-bold uppercase tracking-widest">
                  Secure messaging protocol...
                </div>
                <div className="h-12 w-12 bg-accent-indigo rounded-xl flex items-center justify-center text-white">
                   <ArrowRight className="w-5 h-5" />
                </div>
              </div>
            </div>
          </div>

          {/* Side Stats */}
          <div className="md:col-span-4 grid grid-cols-1 gap-8">
            <div className="rounded-[3rem] border border-white/10 glass-card p-10 flex flex-col justify-between group hover:bg-white/[0.06] transition-all hover:border-accent-indigo/30 shadow-xl relative overflow-hidden">
              <div className="absolute top-0 right-0 p-8 opacity-5 group-hover:opacity-10 transition-opacity">
                <Zap className="w-20 h-20 text-accent-indigo" />
              </div>
              <Zap className="w-10 h-10 text-accent-indigo mb-6 relative z-10" />
              <div className="relative z-10">
                <div className="text-5xl font-black text-text-primary tracking-tighter mb-1">82%</div>
                <div className="text-[10px] text-text-subtle font-black uppercase tracking-[0.2em]">{t('recoveryRateLabel')}</div>
              </div>
            </div>
            <div className="rounded-[3rem] border border-white/10 glass-card p-10 flex flex-col justify-between group hover:bg-white/[0.06] transition-all hover:border-accent-emerald/30 shadow-xl relative overflow-hidden">
              <div className="absolute top-0 right-0 p-8 opacity-5 group-hover:opacity-10 transition-opacity">
                <Bot className="w-20 h-20 text-accent-emerald" />
              </div>
              <Bot className="w-10 h-10 text-accent-emerald mb-6 relative z-10" />
              <div className="relative z-10">
                <div className="text-5xl font-black text-text-primary tracking-tighter mb-1">2.1s</div>
                <div className="text-[10px] text-text-subtle font-black uppercase tracking-[0.2em]">{t('latencyLabel')}</div>
              </div>
            </div>
          </div>
        </div>
      </main>

      {/* How It Works Section */}
      <section className="py-32 border-t border-white/10 relative">
        <div className="max-w-7xl mx-auto px-6">
          <div className="grid grid-cols-1 md:grid-cols-3 gap-16">
            {[t('howStep1'), t('howStep2'), t('howStep3')].map((step, index) => (
              <div key={step} className="rounded-[2.5rem] border border-white/10 glass-card p-10 shadow-xl">
                <div className="text-[10px] font-black uppercase tracking-[0.4em] text-accent-indigo mb-4">0{index + 1}</div>
                <h3 className="text-lg font-black text-text-primary uppercase tracking-widest mb-4 font-display">{step}</h3>
                <p className="text-text-muted text-sm leading-relaxed font-medium">{t(`howStep${index + 1}Desc`)}</p>
              </div>
            ))}
          </div>
        </div>
      </section>

      {/* For Collectors / Debtors Section */}
      <section className="py-32 border-t border-white/10">
        <div className="max-w-7xl mx-auto px-6 grid grid-cols-1 lg:grid-cols-2 gap-12">
          <div className="rounded-[2.5rem] border border-white/10 glass-card p-12 shadow-xl">
            <div className="text-[10px] font-black uppercase tracking-[0.3em] text-accent-indigo mb-6">{t('collectorsLabel')}</div>
            <h3 className="text-3xl font-black text-text-primary uppercase tracking-tight mb-4 font-display">{t('collectorsTitle')}</h3>
            <p className="text-text-muted text-sm leading-relaxed font-medium mb-8">{t('collectorsDesc')}</p>
            <ul className="space-y-4 text-text-muted text-xs font-bold uppercase tracking-widest">
              <li className="flex items-center gap-3"><ShieldCheck className="w-4 h-4 text-accent-emerald" /> {t('collectorsPoint1')}</li>
              <li className="flex items-center gap-3"><BarChart3 className="w-4 h-4 text-accent-indigo" /> {t('collectorsPoint2')}</li>
              <li className="flex items-center gap-3"><Globe className="w-4 h-4 text-accent-emerald" /> {t('collectorsPoint3')}</li>
            </ul>
          </div>
          <div className="rounded-[2.5rem] border border-white/10 glass-card p-12 shadow-xl">
            <div className="text-[10px] font-black uppercase tracking-[0.3em] text-accent-emerald mb-6">{t('debtorsLabel')}</div>
            <h3 className="text-3xl font-black text-text-primary uppercase tracking-tight mb-4 font-display">{t('debtorsTitle')}</h3>
            <p className="text-text-muted text-sm leading-relaxed font-medium mb-8">{t('debtorsDesc')}</p>
            <ul className="space-y-4 text-text-muted text-xs font-bold uppercase tracking-widest">
              <li className="flex items-center gap-3"><ShieldCheck className="w-4 h-4 text-accent-emerald" /> {t('debtorsPoint1')}</li>
              <li className="flex items-center gap-3"><Zap className="w-4 h-4 text-accent-indigo" /> {t('debtorsPoint2')}</li>
              <li className="flex items-center gap-3"><Bot className="w-4 h-4 text-accent-emerald" /> {t('debtorsPoint3')}</li>
            </ul>
          </div>
        </div>
      </section>

      {/* Trust Section */}
      <section className="py-32 border-t border-white/10">
        <div className="max-w-7xl mx-auto px-6 grid grid-cols-1 md:grid-cols-3 gap-12">
          {[
            { icon: ShieldCheck, title: t('legalTitle'), desc: t('legalDesc'), color: '#6366F1' },
            { icon: Globe, title: t('stripeTitle'), desc: t('stripeDesc'), color: '#10B981' },
            { icon: BarChart3, title: t('knowledgeTitle'), desc: t('knowledgeDesc'), color: '#6366F1' }
          ].map((feature, i) => (
            <div key={i} className="rounded-[2.5rem] border border-white/10 glass-card p-10 shadow-xl">
              <div className="w-14 h-14 rounded-2xl bg-white/5 border border-white/10 flex items-center justify-center mb-6">
                <feature.icon className="w-6 h-6" style={{ color: feature.color }} />
              </div>
              <h3 className="text-lg font-black text-text-primary uppercase tracking-widest mb-4 font-display">{feature.title}</h3>
              <p className="text-text-muted text-sm leading-relaxed font-medium">{feature.desc}</p>
            </div>
          ))}
        </div>
      </section>

      {/* CTA Section */}
      <section className="py-32 px-6 relative">
        <div className="max-w-6xl mx-auto rounded-[3.5rem] bg-gradient-to-br from-[#0f2436] to-[#081423] border border-white/10 p-16 md:p-24 text-center space-y-10 relative overflow-hidden shadow-[0_50px_100px_-20px_rgba(2,12,27,0.9)]">
          <div className="absolute top-[-10%] right-[-10%] w-96 h-96 bg-[#d4af37]/10 blur-[120px] rounded-full"></div>
          <div className="absolute bottom-[-10%] left-[-10%] w-96 h-96 bg-[#2fbf9a]/10 blur-[120px] rounded-full"></div>
          
          <div className="space-y-6 relative z-10">
            <h2 className="text-4xl md:text-6xl font-black text-white tracking-tight uppercase leading-none">
              {t('ctaTitle1')} <br /> <span className="text-[#d4af37]">{t('ctaTitle2')}</span>
            </h2>
            <p className="text-white/60 text-lg md:text-xl max-w-2xl mx-auto font-medium tracking-tight">
              {t('ctaSubtitle')}
            </p>
          </div>
          
          <div className="pt-6 relative z-10">
            <Link href="/dashboard" className="h-18 px-12 rounded-2xl bg-[#d4af37] text-[#0b1b2b] hover:bg-[#b48b24] transition-all active:scale-95 text-sm font-black uppercase tracking-[0.3em] inline-flex items-center shadow-2xl">
              {t('ctaButton')}
            </Link>
          </div>
        </div>
      </section>

      {/* Footer Decoration */}
      <div className="py-20 text-center opacity-20">
         <p className="text-[10px] font-black uppercase tracking-[0.6em] text-white/60">TRUSTED INFRASTRUCTURE • DRAGUN COMPLIANCE PLATFORM</p>
      </div>
    </div>
  );
}
