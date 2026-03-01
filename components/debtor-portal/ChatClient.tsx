'use client';

import { useChat } from '@ai-sdk/react';
import { useEffect, useMemo, useRef, useState } from 'react';
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

interface Props {
  debtorId: string;
  token: string;
}

function generateId() {
  return crypto.randomUUID?.() ?? `msg-${Date.now()}-${Math.random().toString(36).slice(2, 9)}`;
}

export default function ChatClient({ debtorId, token }: Props) {
  const t = useTranslations('Chat');
  const [debtor, setDebtor] = useState<Debtor | null>(null);
  const [loading, setLoading] = useState(true);
  const [initiateLoading, setInitiateLoading] = useState(false);
  const initiateRequested = useRef(false);
  const supabase = useMemo(() => createClient(), []);
  const scrollRef = useRef<HTMLDivElement>(null);

  const [chatError, setChatError] = useState<string | null>(null);
  const { messages, setMessages, input, handleInputChange, handleSubmit, isLoading } = useChat({
    api: '/api/chat',
    body: { debtorId, token },
    onError: () => setChatError(t('agentUnavailable')),
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

  // Load existing conversation or request agent to send the first message
  useEffect(() => {
    if (!debtor || loading) return;

    async function hydrateConversation() {
      const { data: rows } = await supabase
        .from('conversations')
        .select('role, message')
        .eq('debtor_id', debtorId)
        .order('created_at', { ascending: true });

      if (rows && rows.length > 0) {
        const hydrated = rows.map((r) => ({
          id: generateId(),
          role: r.role as 'user' | 'assistant' | 'system',
          content: r.message ?? '',
        }));
        setMessages(hydrated);
        return;
      }

      if (initiateRequested.current) return;
      initiateRequested.current = true;
      setInitiateLoading(true);
      setChatError(null);
      try {
        const res = await fetch('/api/chat', {
          method: 'POST',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify({ debtorId, token, initiate: true }),
        });
        if (!res.ok) {
          const err = await res.json().catch(() => ({}));
          setChatError((err as { error?: string })?.error ?? t('agentUnavailable'));
          return;
        }
        const text = await res.text();
        if (text?.trim()) {
          setMessages([{ id: generateId(), role: 'assistant', content: text.trim() }]);
        }
      } catch {
        setChatError(t('agentUnavailable'));
      } finally {
        setInitiateLoading(false);
      }
    }

    hydrateConversation();
  }, [debtor, debtorId, token, loading, supabase, setMessages, t]);

  useEffect(() => {
    scrollRef.current?.scrollTo({ top: scrollRef.current.scrollHeight, behavior: 'smooth' });
  }, [messages]);

  if (loading) {
    return (
      <div className="min-h-screen bg-base-100 flex items-center justify-center">
        <span className="loading loading-spinner loading-lg text-primary" />
      </div>
    );
  }

  if (!debtor) {
    return (
      <div className="min-h-screen bg-base-100 flex flex-col items-center justify-center p-10 gap-4">
        <ShieldCheck className="w-12 h-12 text-base-content/20" />
        <p className="text-base-content/40 font-semibold text-sm">{t('notFound')}</p>
      </div>
    );
  }

  const payHref = `/pay/${debtorId}?token=${encodeURIComponent(token)}`;
  const actionChips = [t('chipPay'), t('chipFriday'), t('chipDispute'), t('chipSettlement')];

  return (
    <div className="flex flex-col min-h-[100dvh] bg-base-100 text-base-content w-full md:max-w-lg mx-auto border-x border-base-300/50 shadow-elevated relative">
      <header className="px-4 pt-[calc(env(safe-area-inset-top)+0.75rem)] pb-3 border-b border-base-300/50 bg-base-100/90 backdrop-blur-xl flex items-center gap-3 sticky top-0 z-20">
        <Link href="/" className="btn btn-ghost btn-sm btn-square">
          <ChevronLeft className="w-4 h-4" />
        </Link>
        <div className="w-10 h-10 rounded-xl bg-primary/10 border border-primary/20 flex items-center justify-center text-primary font-bold text-sm">
          {debtor.merchant.name[0]}
        </div>
        <div className="flex-1 min-w-0">
          <h1 className="text-sm font-bold truncate">{debtor.merchant.name}</h1>
          <div className="flex items-center gap-1.5">
            <span className="relative flex h-1.5 w-1.5">
              <span className="absolute inline-flex h-full w-full animate-ping rounded-full bg-success opacity-75" />
              <span className="relative inline-flex h-1.5 w-1.5 rounded-full bg-success" />
            </span>
            <span className="text-[10px] text-base-content/40 font-medium">{t('agentActive')}</span>
          </div>
        </div>
        <div className="text-right shrink-0">
          <div className="text-[10px] text-base-content/40 font-medium">{t('balanceDue')}</div>
          <div className="text-sm font-bold text-primary tabular-nums">
            {debtor.currency} {debtor.total_debt.toLocaleString()}
          </div>
        </div>
      </header>

      <main ref={scrollRef} className="flex-1 overflow-y-auto p-4 space-y-4 scroll-smooth">
        {chatError && (
          <div className="alert alert-error alert-sm">
            <span className="text-xs">{chatError}</span>
          </div>
        )}
        {messages.length === 0 && !initiateLoading && (
          <div className="text-center py-16 space-y-6">
            <div className="w-16 h-16 mx-auto rounded-2xl bg-base-200 border border-base-300/50 flex items-center justify-center text-3xl shadow-warm">
              🐲
            </div>
            <div className="space-y-2">
              <p className="text-sm font-bold">{t('automatedAgent')}</p>
              <p className="text-xs text-base-content/50 max-w-[260px] mx-auto leading-relaxed">
                {t('agentIntro', { merchant: debtor.merchant.name })}
              </p>
            </div>
            <div className="flex flex-col items-center gap-1.5">
              <div className="inline-flex items-center gap-1.5 px-3 py-1 rounded-full bg-base-200/60 border border-base-300/30 text-[10px] text-base-content/30 font-medium">
                <Sparkles className="w-3 h-3 text-primary/50" />
                {t('encrypted')}
              </div>
              <p className="text-[10px] text-base-content/40 max-w-[240px] text-center">
                {t('trustLine', { merchant: debtor.merchant.name })}
              </p>
            </div>
          </div>
        )}
        {messages.length === 0 && initiateLoading && (
          <div className="chat chat-start">
            <div className="chat-bubble bg-base-200 border border-base-300/30">
              <span className="loading loading-dots loading-xs" />
            </div>
          </div>
        )}
        {messages.map((m) => (
          <div key={m.id} className={`chat ${m.role === 'user' ? 'chat-end' : 'chat-start'}`}>
            <div
              className={`chat-bubble text-sm leading-relaxed ${
                m.role === 'user'
                  ? 'chat-bubble-primary'
                  : 'bg-base-200 text-base-content border border-base-300/30'
              }`}
            >
              {m.content}
            </div>
            <div className="chat-footer opacity-40 text-[10px] mt-0.5">
              {m.role === 'user' ? t('sent') : t('dragunAI')}
            </div>
          </div>
        ))}
        {isLoading && (
          <div className="chat chat-start">
            <div className="chat-bubble bg-base-200 border border-base-300/30">
              <span className="loading loading-dots loading-xs" />
            </div>
          </div>
        )}
      </main>

      <section className="px-4 py-2.5 flex gap-2 overflow-x-auto overflow-y-hidden border-t border-base-300/30 bg-base-100/80 backdrop-blur-sm scrollbar-hide scroll-smooth" style={{ paddingLeft: 'max(1rem, env(safe-area-inset-left))', paddingRight: 'max(1rem, env(safe-area-inset-right))' }}>
        {actionChips.map((chip) => (
          <button
            key={chip}
            className="btn btn-sm btn-ghost rounded-full border border-base-300/50 whitespace-nowrap text-xs font-semibold hover:btn-primary hover:border-primary min-h-9"
            onClick={() => {
              const e = { target: { value: chip } } as React.ChangeEvent<HTMLInputElement>;
              handleInputChange(e);
              setTimeout(() => document.querySelector<HTMLFormElement>('form')?.requestSubmit(), 50);
            }}
          >
            {chip}
          </button>
        ))}
      </section>

      <footer className="p-4 pb-[max(1rem,calc(env(safe-area-inset-bottom)+1rem))] bg-base-100 border-t border-base-300/30" style={{ paddingLeft: 'max(1rem, env(safe-area-inset-left))', paddingRight: 'max(1rem, env(safe-area-inset-right))' }}>
        <form onSubmit={handleSubmit} className="flex items-center gap-2 min-w-0">
          <input
            className="input input-bordered flex-1 min-w-0 text-sm min-h-11"
            value={input}
            placeholder={t('placeholder')}
            onChange={handleInputChange}
          />
          <button type="submit" className="btn btn-primary btn-square min-h-11 min-w-11" disabled={isLoading || !input.trim()}>
            <Send className="w-4 h-4" />
          </button>
        </form>
        <div className="mt-3 flex items-center justify-between px-1">
          <Link href={payHref} className="flex items-center gap-1.5 text-[10px] font-semibold text-primary hover:underline underline-offset-2">
            <CreditCard className="w-3 h-3" />
            {t('settlementPlans')}
          </Link>
          <div className="flex flex-col items-end gap-0.5">
            <span className="text-[9px] font-medium text-base-content/40">{t('secureGateway')}</span>
            <span className="text-[9px] text-base-content/30">{t('trustLine', { merchant: debtor.merchant.name })}</span>
          </div>
        </div>
      </footer>
    </div>
  );
}
