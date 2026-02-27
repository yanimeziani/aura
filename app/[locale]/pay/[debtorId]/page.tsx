'use client';

import { use, useEffect, useMemo, useState } from 'react';
import { useTranslations } from 'next-intl';
import { Link } from '@/i18n/navigation';
import { createClient } from '@/lib/supabase/client';
import { ChevronLeft, ShieldCheck, Sparkles, Check, ArrowRight } from 'lucide-react';

interface Debtor {
  id: string;
  merchant_id: string;
  name: string;
  currency: string;
  total_debt: number;
  merchant: {
    name: string;
    settlement_floor: number;
  };
}

export default function PaymentPage({ params }: { params: Promise<{ debtorId: string }> }) {
  const { debtorId } = use(params);
  const t = useTranslations('Pay');
  const [debtor, setDebtor] = useState<Debtor | null>(null);
  const [loading, setLoading] = useState(true);
  const supabase = useMemo(() => createClient(), []);

  useEffect(() => {
    async function fetchDebtor() {
      const { data } = await supabase
        .from('debtors')
        .select('*, merchant:merchants(*)')
        .eq('id', debtorId)
        .single();
      setDebtor(data);
      setLoading(false);
    }
    fetchDebtor();
  }, [debtorId, supabase]);

  const handlePayment = async (amount: number, description: string) => {
    if (!debtor) return;
    const res = await fetch('/api/stripe/checkout', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        debtorId,
        merchantId: debtor.merchant_id,
        amount,
        currency: debtor.currency,
        description,
      }),
    });
    const { url } = await res.json();
    if (url) window.location.href = url;
  };

  if (loading) return (
    <div className="min-h-screen bg-[#050505] flex items-center justify-center">
      <div className="w-10 h-10 border-4 border-[#D4AF37]/20 border-t-[#D4AF37] rounded-full animate-spin"></div>
    </div>
  );

  if (!debtor) return (
    <div className="min-h-screen bg-[#050505] flex flex-col items-center justify-center p-10 space-y-6">
       <ShieldCheck className="w-16 h-16 text-[#F87272] opacity-20" />
       <p className="text-white/40 font-black tracking-widest uppercase">{t('notFound')}</p>
    </div>
  );

  const fullDebt = debtor.total_debt;
  const settlementFloor = debtor.merchant.settlement_floor;
  const settlementAmount = fullDebt * Math.max(0.7, settlementFloor);
  const savingPercent = Math.round((1 - settlementAmount / fullDebt) * 100);

  return (
    <main className="relative isolate bg-[#050505] min-h-screen text-white overflow-hidden selection:bg-[#D4AF37] selection:text-black">
      {/* Premium Ambient Background */}
      <div className="absolute inset-0 -z-10 overflow-hidden pointer-events-none">
        <div className="absolute top-[-10%] left-[-10%] w-[60%] h-[60%] bg-[#D4AF37]/5 blur-[120px] rounded-full"></div>
        <div className="absolute bottom-[-10%] right-[-10%] w-[50%] h-[50%] bg-[#6419E6]/10 blur-[120px] rounded-full"></div>
      </div>

      <div className="max-w-7xl mx-auto px-6 pt-24 pb-40 flex flex-col items-center relative z-10">
        <div className="w-full flex justify-start mb-16">
          <Link href={`/chat/${debtorId}`} className="group flex items-center gap-3 px-6 py-3 rounded-full bg-white/[0.03] border border-white/10 hover:bg-white/[0.08] transition-all">
            <ChevronLeft className="w-4 h-4 text-white/40 group-hover:text-white transition-colors" />
            <span className="text-[10px] font-black uppercase tracking-[0.2em] text-white/40 group-hover:text-white transition-colors">{t('returnToChat')}</span>
          </Link>
        </div>

        <div className="text-center space-y-6 mb-24">
          <div className="inline-flex items-center gap-2 px-4 py-1.5 rounded-full border border-[#D4AF37]/20 bg-[#D4AF37]/5 backdrop-blur-xl text-[#D4AF37] text-[10px] font-black tracking-[0.3em] uppercase">
            <Sparkles className="w-3 h-3" />
            {t('portalBadge')}
          </div>
          <h1 className="text-5xl md:text-8xl font-black tracking-[-0.04em] leading-none text-white uppercase">
            {t('title')} <span className="italic font-serif tracking-tight lowercase text-[#D4AF37]">{t('titleHighlight')}</span> {t('titleEnd')}
          </h1>
          <p className="text-base md:text-lg text-white/40 max-w-2xl mx-auto leading-relaxed font-medium tracking-tight">
            {t('subtitle')}
          </p>
        </div>

        <div className="grid grid-cols-1 md:grid-cols-3 gap-8 w-full max-w-6xl">
          {/* Pay in Full */}
          <div className="group relative rounded-[3rem] border border-white/5 bg-white/[0.02] p-1 overflow-hidden transition-all hover:border-white/10 shadow-2xl flex flex-col">
            <div className="bg-white/[0.02] rounded-[2.8rem] p-10 h-full flex flex-col space-y-10">
              <div className="space-y-2">
                <div className="text-[10px] font-black text-white/40 uppercase tracking-[0.3em]">{t('payInFull')}</div>
                <div className="text-xs text-white/20 font-medium uppercase tracking-widest">{t('payInFullDesc')}</div>
              </div>
              
              <div className="flex items-baseline gap-2">
                <span className="text-6xl font-black text-white">{debtor.currency} {fullDebt.toLocaleString()}</span>
              </div>

              <div className="h-px bg-white/5 w-full" />

              <ul className="space-y-5 flex-1">
                {[t('benefit1Full'), t('benefit2Full')].map((f, i) => (
                  <li key={i} className="flex items-center gap-4 text-xs font-bold text-white/60 tracking-tight uppercase">
                    <div className="w-5 h-5 rounded-full bg-white/5 flex items-center justify-center border border-white/10">
                       <Check className="w-3 h-3 text-white/40" />
                    </div>
                    {f}
                  </li>
                ))}
              </ul>

              <button onClick={() => handlePayment(fullDebt, 'Full Debt Payment')} className="h-16 w-full rounded-2xl bg-white/[0.05] border border-white/10 text-white font-black text-[10px] uppercase tracking-[0.3em] flex items-center justify-center hover:bg-white/10 transition-all active:scale-95 group/btn">
                {t('payFullButton')}
                <ArrowRight className="w-4 h-4 ml-3 group-hover/btn:translate-x-1 transition-transform" />
              </button>
            </div>
          </div>

          {/* Lump Sum Settlement - Highlighted */}
          <div className="group relative rounded-[3rem] border border-[#D4AF37]/30 bg-white/[0.02] p-1 overflow-hidden transition-all hover:border-[#D4AF37]/50 shadow-[0_0_50px_rgba(212,175,55,0.1)] flex flex-col scale-105 z-10">
            <div className="absolute top-0 right-0 px-6 py-2 bg-[#D4AF37] text-black text-[10px] font-black uppercase tracking-widest rounded-bl-[2rem]">{t('recommended')}</div>
            <div className="bg-white/[0.03] rounded-[2.8rem] p-10 h-full flex flex-col space-y-10">
              <div className="space-y-2">
                <div className="text-[10px] font-black text-[#D4AF37] uppercase tracking-[0.3em]">{t('lumpSum')}</div>
                <div className="text-xs text-white/40 font-medium uppercase tracking-widest">{t('lumpSumDesc')}</div>
              </div>
              
              <div className="flex flex-col">
                <div className="flex items-baseline gap-2">
                  <span className="text-6xl font-black text-white">{debtor.currency} {settlementAmount.toLocaleString()}</span>
                </div>
                <span className="text-xs font-bold text-white/20 line-through tracking-widest uppercase mt-2">{debtor.currency} {fullDebt}</span>
              </div>

              <div className="h-px bg-white/5 w-full" />

              <ul className="space-y-5 flex-1">
                {[t('benefit1Lump', { percent: savingPercent }), t('benefit2Lump'), t('benefit3Lump')].map((f, i) => (
                  <li key={i} className="flex items-center gap-4 text-xs font-bold text-white uppercase tracking-tight">
                    <div className="w-5 h-5 rounded-full bg-[#D4AF37]/20 flex items-center justify-center border border-[#D4AF37]/30">
                       <Check className="w-3 h-3 text-[#D4AF37]" />
                    </div>
                    {f}
                  </li>
                ))}
              </ul>

              <button onClick={() => handlePayment(settlementAmount, 'One-time Settlement')} className="h-16 w-full rounded-2xl bg-white text-black font-black text-[10px] uppercase tracking-[0.3em] flex items-center justify-center hover:bg-[#D4AF37] transition-all active:scale-95 shadow-2xl group/btn">
                {t('acceptSettlement')}
                <ArrowRight className="w-4 h-4 ml-3 group-hover/btn:translate-x-1 transition-transform" />
              </button>
            </div>
          </div>

          {/* Installment Plan */}
          <div className="group relative rounded-[3rem] border border-white/5 bg-white/[0.02] p-1 overflow-hidden transition-all hover:border-white/10 shadow-2xl flex flex-col">
            <div className="bg-white/[0.02] rounded-[2.8rem] p-10 h-full flex flex-col space-y-10">
              <div className="space-y-2">
                <div className="text-[10px] font-black text-white/40 uppercase tracking-[0.3em]">{t('installments')}</div>
                <div className="text-xs text-white/20 font-medium uppercase tracking-widest">{t('installmentsDesc')}</div>
              </div>
              
              <div className="flex items-baseline gap-2">
                <span className="text-5xl font-black text-white">{debtor.currency} {(fullDebt / 3).toLocaleString()}</span>
                <span className="text-xs font-bold text-white/20 uppercase tracking-widest">{t('perMonth')}</span>
              </div>

              <div className="h-px bg-white/5 w-full" />

              <ul className="space-y-5 flex-1">
                {[t('benefit1Install'), t('benefit2Install')].map((f, i) => (
                  <li key={i} className="flex items-center gap-4 text-xs font-bold text-white/60 tracking-tight uppercase">
                    <div className="w-5 h-5 rounded-full bg-white/5 flex items-center justify-center border border-white/10">
                       <Check className="w-3 h-3 text-white/40" />
                    </div>
                    {f}
                  </li>
                ))}
              </ul>

              <button onClick={() => handlePayment(fullDebt / 3, 'First Installment')} className="h-16 w-full rounded-2xl bg-white/[0.05] border border-white/10 text-white font-black text-[10px] uppercase tracking-[0.3em] flex items-center justify-center hover:bg-white/10 transition-all active:scale-95 group/btn">
                {t('startInstallments')}
                <ArrowRight className="w-4 h-4 ml-3 group-hover/btn:translate-x-1 transition-transform" />
              </button>
            </div>
          </div>
        </div>

        {/* Global Disclaimer */}
        <div className="mt-32 p-12 rounded-[3rem] border border-white/5 bg-white/[0.02] max-w-4xl w-full text-center space-y-4">
           <div className="text-[10px] font-black text-[#D4AF37] uppercase tracking-[0.4em]">Protocol Disclosure</div>
           <p className="text-white/40 text-sm font-medium tracking-tight leading-relaxed max-w-2xl mx-auto">
             {t('disclaimer', { merchant: debtor.merchant.name })}
           </p>
        </div>
      </div>
    </main>
  );
}
