'use client';

import { useChat } from '@ai-sdk/react';
import { use, useEffect, useState } from 'react';
import { useTranslations } from 'next-intl';
import { Link } from '@/i18n/navigation';
import { createClient } from '@/lib/supabase/client';
import { ChevronLeft, ShieldCheck, Sparkles, Send, CreditCard } from 'lucide-react';

interface Debtor {
  id: string;
  name: string;
  currency: string;
  total_debt: number;
  merchant: {
    name: string;
    strictness_level: number;
  };
}

export default function ChatPage({ params }: { params: Promise<{ debtorId: string }> }) {
  const { debtorId } = use(params);
  const t = useTranslations('Chat');
  const [debtor, setDebtor] = useState<Debtor | null>(null);
  const [loading, setLoading] = useState(true);
  const supabase = createClient();

  const [chatError, setChatError] = useState<string | null>(null);
  const { messages, input, handleInputChange, handleSubmit, isLoading } = useChat({
    api: '/api/chat',
    body: { debtorId },
    onError: (err) => {
      console.error('[chat]', err);
      setChatError('The recovery agent is unavailable right now. Please try again in a moment.');
    },
  });

  useEffect(() => {
    async function fetchDebtor() {
      const { data } = await supabase
        .from('debtors')
        .select('*, merchant:merchants(name, strictness_level)')
        .eq('id', debtorId)
        .single();
      setDebtor(data);
      setLoading(false);
    }
    fetchDebtor();
  }, [debtorId, supabase]);

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

  const actionChips = [
    t('chipPay'),
    t('chipFriday'),
    t('chipDispute'),
    t('chipSettlement'),
  ];

  return (
    <div className="flex flex-col min-h-[100dvh] bg-[#050505] text-white w-full md:max-w-lg mx-auto border-x border-white/5 shadow-2xl relative selection:bg-[#D4AF37] selection:text-black">
      {/* Premium Ambient Background */}
      <div className="absolute top-0 left-1/2 -translate-x-1/2 w-full h-[500px] bg-gradient-to-b from-[#6419E6]/5 to-transparent pointer-events-none -z-10"></div>

      {/* Header */}
      <header className="px-6 pt-[calc(env(safe-area-inset-top)+1.25rem)] pb-5 border-b border-white/5 bg-[#050505]/80 backdrop-blur-3xl flex items-center gap-4 sticky top-0 z-20">
        <Link href="/" className="p-2 hover:bg-white/5 rounded-xl transition-all text-white/20 hover:text-white">
          <ChevronLeft className="w-5 h-5" />
        </Link>
        <div className="relative group">
          <div className="absolute inset-0 bg-[#D4AF37]/20 blur-md rounded-xl opacity-0 group-hover:opacity-100 transition-opacity" />
          <div className="w-11 h-11 bg-gradient-to-br from-[#1a1a1a] to-[#0a0a0a] border border-white/10 rounded-xl flex items-center justify-center text-[#D4AF37] shadow-2xl relative z-10">
            <span className="text-sm font-black tracking-tighter">{debtor.merchant.name[0]}</span>
          </div>
        </div>
        <div className="flex-1">
          <h1 className="text-xs font-black uppercase tracking-[0.15em] text-white/80">{debtor.merchant.name} Protocol</h1>
          <div className="flex items-center gap-2 mt-0.5">
            <div className="w-1.5 h-1.5 bg-[#10b981] rounded-full animate-pulse shadow-[0_0_8px_rgba(16,185,129,0.5)]"></div>
            <span className="text-[9px] text-white/30 font-black uppercase tracking-widest">{t('agentActive')}</span>
          </div>
        </div>
        <div className="text-right">
          <div className="text-[9px] text-white/20 uppercase font-black tracking-tighter mb-0.5">{t('balanceDue')}</div>
          <div className="text-sm font-black text-[#D4AF37] tracking-tight">{debtor.currency} {debtor.total_debt.toLocaleString()}</div>
        </div>
      </header>

      {/* Chat Area */}
      <main className="flex-1 overflow-y-auto p-6 space-y-8 scroll-smooth scrollbar-hide">
        {chatError && (
          <div className="bg-[#F87272]/10 border border-[#F87272]/20 rounded-2xl p-4 text-[11px] text-[#F87272] font-bold uppercase tracking-widest">
            {chatError}
          </div>
        )}
        {messages.length === 0 && (
          <div className="text-center py-20 space-y-8 animate-in fade-in duration-1000">
            <div className="relative inline-block">
               <div className="absolute inset-0 bg-[#D4AF37]/10 blur-[40px] rounded-full" />
               <div className="w-24 h-24 bg-white/[0.02] border border-white/10 rounded-[2rem] flex items-center justify-center text-5xl relative z-10 shadow-2xl">🐲</div>
            </div>
            <div className="space-y-3">
              <p className="text-sm font-black text-white uppercase tracking-widest">{t('automatedAgent')}</p>
              <p className="text-xs text-white/40 max-w-[240px] mx-auto leading-relaxed font-medium">{t('agentIntro', { merchant: debtor.merchant.name })}</p>
            </div>
            <div className="inline-flex items-center gap-2 px-4 py-1.5 rounded-full border border-white/5 bg-white/[0.03] text-[9px] font-black tracking-[0.2em] text-white/20 uppercase">
               <Sparkles className="w-3 h-3 text-[#D4AF37]" />
               {t('encrypted')}
            </div>
          </div>
        )}

        <div className="space-y-6">
          {messages.map(m => (
            <div key={m.id} className={`flex ${m.role === 'user' ? 'justify-end' : 'justify-start'} animate-in slide-in-from-bottom-2 duration-300`}>
              <div className={`max-w-[85%] p-4 rounded-2xl text-sm leading-relaxed ${
                m.role === 'user'
                  ? 'bg-white text-black font-bold shadow-[0_10px_30px_rgba(0,0,0,0.5)] rounded-tr-none'
                  : 'bg-white/[0.05] border border-white/5 text-white/70 font-medium rounded-tl-none backdrop-blur-xl'
              }`}>
                {m.content}
                <div className={`text-[8px] mt-2 font-black uppercase tracking-widest ${m.role === 'user' ? 'text-black/30' : 'text-white/20'}`}>
                  {m.role === 'user' ? t('sent') : t('dragunAI')}
                </div>
              </div>
            </div>
          ))}
        </div>

        {isLoading && (
          <div className="flex justify-start">
            <div className="bg-white/[0.05] border border-white/5 p-4 rounded-2xl rounded-tl-none">
              <span className="flex gap-1">
                <span className="w-1 h-1 bg-white/20 rounded-full animate-bounce"></span>
                <span className="w-1 h-1 bg-white/20 rounded-full animate-bounce [animation-delay:0.2s]"></span>
                <span className="w-1 h-1 bg-white/20 rounded-full animate-bounce [animation-delay:0.4s]"></span>
              </span>
            </div>
          </div>
        )}
      </main>

      {/* Action Chips */}
      <section className="px-6 py-4 flex gap-3 overflow-x-auto border-t border-white/5 bg-white/[0.02] backdrop-blur-3xl scrollbar-hide">
        {actionChips.map(chip => (
          <button
            key={chip}
            className="h-10 px-5 rounded-full bg-white/[0.03] border border-white/10 text-white/40 text-[10px] font-black uppercase tracking-widest hover:bg-[#D4AF37] hover:text-black hover:border-[#D4AF37] transition-all whitespace-nowrap active:scale-95 shadow-lg"
            onClick={() => {
              const e = { target: { value: chip } } as React.ChangeEvent<HTMLInputElement>;
              handleInputChange(e);
              setTimeout(() => {
                const form = document.querySelector('form') as HTMLFormElement;
                form?.requestSubmit();
              }, 50);
            }}
          >
            {chip}
          </button>
        ))}
      </section>

      {/* Input Area */}
      <footer className="pt-6 px-6 pb-[calc(env(safe-area-inset-bottom)+1.5rem)] bg-[#050505] border-t border-white/5">
        <form onSubmit={handleSubmit} className="relative flex items-center group">
          <input
            className="w-full bg-white/[0.03] border border-white/10 rounded-2xl px-6 py-4 text-sm font-medium text-white focus:border-[#D4AF37]/50 focus:outline-none transition-all placeholder:text-white/10 pr-16"
            value={input}
            placeholder={t('placeholder')}
            onChange={handleInputChange}
          />
          <button
            type="submit"
            className="absolute right-2 w-12 h-12 bg-[#D4AF37] text-black rounded-xl flex items-center justify-center hover:bg-white transition-all active:scale-90 disabled:opacity-50 disabled:active:scale-100 shadow-2xl"
            disabled={isLoading || !input.trim()}
          >
            <Send className="w-5 h-5" />
          </button>
        </form>

        <div className="mt-6 flex items-center justify-between px-2">
          <Link href={`/pay/${debtorId}`} className="group flex items-center gap-2 text-[10px] font-black uppercase tracking-[0.2em] text-[#D4AF37] hover:text-white transition-colors">
            <CreditCard className="w-3.5 h-3.5" />
            <span>{t('settlementPlans')}</span>
          </Link>
          <div className="flex items-center gap-1.5 opacity-20">
             <ShieldCheck className="w-3 h-3 text-white" />
             <div className="text-[8px] uppercase font-black tracking-widest">{t('secureGateway')}</div>
          </div>
        </div>
      </footer>
    </div>
  );
}
