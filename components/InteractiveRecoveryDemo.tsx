'use client';

import { FormEvent, useMemo, useRef, useState, useEffect } from 'react';
import { Send, Lock, Bot, User } from 'lucide-react';

type Message = {
  role: 'agent' | 'user';
  text: string;
};

function buildReply(input: string) {
  const n = input.toLowerCase();

  if (n.includes('dispute') || n.includes('cancel') || n.includes('don\'t owe'))
    return 'I understand your concern. In this demo account, clause 4.2 of the service agreement requires 30-day written notice. I can note this for review, but in the meantime, would you like to explore a settlement option that could save you up to 30%?';

  if (n.includes('plan') || n.includes('installment') || n.includes('split') || n.includes('payment plan'))
    return 'Absolutely. For your balance of CAD 1,250, I can set up 3 monthly payments of $416.67. Each payment is processed securely through Stripe, and you\'ll get a receipt after each one. Would that work for you?';

  if (n.includes('pay') || n.includes('today') || n.includes('resolve') || n.includes('settle'))
    return 'Great decision. I\'ll send you a secure payment link right now. You can choose to pay the full amount, take the settlement offer at $875, or start a 3-month plan. Everything goes through Stripe checkout.';

  if (n.includes('time') || n.includes('later') || n.includes('can\'t') || n.includes('afford'))
    return 'I hear you, and I appreciate you being upfront about that. That\'s exactly why we have flexible options. Would a payment plan of $416.67/month over 3 months be more manageable for your situation?';

  if (n.includes('who') || n.includes('what is') || n.includes('dragun'))
    return 'I\'m the resolution assistant for this account. Everything here is confidential and secure. I\'m here to help find an option that works for both sides. Would you like to see what\'s available?';

  return 'Thanks for reaching out. I have a few options that might work for your situation: full payment, a 30% settlement discount, or a 3-month plan. Which would you like to hear more about?';
}

export default function InteractiveRecoveryDemo() {
  const initialMessages = useMemo<Message[]>(
    () => [
      {
        role: 'agent',
        text: 'Hi there. I\'m reaching out about an open balance of CAD 1,250 with Atlas Services. I have some flexible options that could work for you -- would you like to hear them?',
      },
    ],
    []
  );

  const [messages, setMessages] = useState<Message[]>(initialMessages);
  const [input, setInput] = useState('');
  const [typing, setTyping] = useState(false);
  const chatEndRef = useRef<HTMLDivElement>(null);

  useEffect(() => {
    chatEndRef.current?.scrollIntoView({ behavior: 'smooth' });
  }, [messages]);

  const runAgentReply = (reply: string) => {
    setTyping(true);
    setMessages((prev) => [...prev, { role: 'agent', text: '' }]);

    let index = 0;
    const timer = setInterval(() => {
      index += 1;
      setMessages((prev) => {
        const copy = [...prev];
        const last = copy[copy.length - 1];
        if (last?.role === 'agent') last.text = reply.slice(0, index);
        return copy;
      });

      if (index >= reply.length) {
        clearInterval(timer);
        setTyping(false);
      }
    }, 10);
  };

  const handleSend = (text: string) => {
    const clean = text.trim();
    if (!clean || typing) return;
    setMessages((prev) => [...prev, { role: 'user', text: clean }]);
    setInput('');
    setTimeout(() => runAgentReply(buildReply(clean)), 400);
  };

  const onSubmit = (event: FormEvent<HTMLFormElement>) => {
    event.preventDefault();
    handleSend(input);
  };

  return (
    <div className="overflow-hidden rounded-2xl border border-base-300 bg-base-100 shadow-xl">
      {/* Browser chrome */}
      <div className="flex items-center gap-2 border-b border-base-300/60 bg-base-200/60 px-4 py-2.5">
        <div className="flex gap-1.5">
          <div className="h-2.5 w-2.5 rounded-full bg-error/50" />
          <div className="h-2.5 w-2.5 rounded-full bg-warning/50" />
          <div className="h-2.5 w-2.5 rounded-full bg-success/50" />
        </div>
        <div className="flex-1 text-center">
          <div className="inline-flex items-center gap-2 rounded-md bg-base-300/40 px-4 py-0.5">
            <Lock className="h-2.5 w-2.5 text-success" />
            <span className="text-[10px] font-mono text-base-content/40">chat.dragun.app/demo/DRG-2048</span>
          </div>
        </div>
        <span className="rounded-md bg-warning/10 px-2 py-0.5 text-[9px] font-bold uppercase tracking-wider text-warning">Sandbox</span>
      </div>

      <div className="grid lg:grid-cols-[1fr_280px]">
        {/* Chat area -- styled like the debtor portal */}
        <div className="flex flex-col" style={{ fontFamily: 'Inter, system-ui, sans-serif' }}>
          {/* Chat header */}
          <div className="border-b border-[#e8e4df] bg-[#faf9f7] px-5 py-3">
            <div className="flex items-center justify-between">
              <div>
                <p className="text-[13px] font-semibold text-[#444]">Atlas Services</p>
                <p className="text-[10px] text-[#aaa]">Account Resolution &middot; Demo</p>
              </div>
              <div className="flex items-center gap-2 rounded-lg bg-[#f0ece6] px-3 py-1.5">
                <span className="text-[10px] text-[#888]">Balance</span>
                <span className="text-[12px] font-semibold text-[#555]">CAD 1,250</span>
              </div>
            </div>
          </div>

          {/* Messages */}
          <div className="flex-1 overflow-y-auto bg-[#faf9f7] p-4 sm:p-5 space-y-3 max-h-[50vh] sm:max-h-[360px] min-h-[240px] sm:min-h-[280px]">
            {messages.map((m, idx) => (
              <div key={`${m.role}-${idx}`} className={`flex ${m.role === 'user' ? 'justify-end' : 'justify-start'} items-end gap-2`}>
                {m.role === 'agent' && (
                  <div className="flex h-6 w-6 shrink-0 items-center justify-center rounded-full bg-[#f0ece6]">
                    <Bot className="h-3 w-3 text-[#8b7355]" />
                  </div>
                )}
                <div
                  className={`max-w-[80%] rounded-2xl px-4 py-2.5 ${
                    m.role === 'user'
                      ? 'bg-[#5b4a3f] text-white rounded-br-md'
                      : 'bg-[#f0ece6] text-[#444] rounded-bl-md'
                  }`}
                >
                  <p className="text-[13px] leading-relaxed">{m.text}</p>
                </div>
                {m.role === 'user' && (
                  <div className="flex h-6 w-6 shrink-0 items-center justify-center rounded-full bg-[#5b4a3f]">
                    <User className="h-3 w-3 text-white" />
                  </div>
                )}
              </div>
            ))}

            {typing && messages[messages.length - 1]?.text === '' && (
              <div className="flex items-end gap-2">
                <div className="flex h-6 w-6 shrink-0 items-center justify-center rounded-full bg-[#f0ece6]">
                  <Bot className="h-3 w-3 text-[#8b7355]" />
                </div>
                <div className="rounded-2xl rounded-bl-md bg-[#f0ece6] px-4 py-2.5" />
              </div>
            )}
            <div ref={chatEndRef} />
          </div>

          {/* Quick actions */}
          <div className="border-t border-[#e8e4df] bg-[#faf9f7] px-4 py-2.5">
            <div className="flex gap-2 overflow-x-auto pb-1">
              {[
                'I\'d like to pay now',
                'Can I set up a plan?',
                'I want to dispute this',
                'I need more time',
              ].map((preset) => (
                <button
                  key={preset}
                  onClick={() => handleSend(preset)}
                  disabled={typing}
                  className="shrink-0 rounded-full border border-[#e0dbd4] bg-white px-3 py-2 min-h-10 text-[11px] font-medium text-[#777] transition-colors hover:border-[#c4b9a8] hover:bg-[#f5f3f0] disabled:opacity-40 touch-manipulation"
                  type="button"
                >
                  {preset}
                </button>
              ))}
            </div>
          </div>

          {/* Input */}
          <form onSubmit={onSubmit} className="border-t border-[#e8e4df] bg-white px-4 py-3 flex items-center gap-2">
            <input
              value={input}
              onChange={(e) => setInput(e.target.value)}
              placeholder={typing ? 'Typing...' : 'Type anything to test the agent'}
              disabled={typing}
              className="flex-1 min-h-11 rounded-xl border border-[#e0dbd4] bg-[#faf9f7] px-4 py-2.5 text-[13px] text-[#444] placeholder:text-[#c4b9a8] outline-none focus:border-[#8b7355] transition-colors"
            />
            <button
              type="submit"
              disabled={typing || !input.trim()}
              className="flex h-11 w-11 min-h-11 min-w-11 shrink-0 items-center justify-center rounded-xl bg-[#5b4a3f] text-white transition-opacity disabled:opacity-30 touch-manipulation"
            >
              <Send className="h-4 w-4" />
            </button>
          </form>
        </div>

        {/* Side panel -- merchant view */}
        <div className="hidden lg:flex flex-col border-l border-base-300/60 bg-base-200/30">
          <div className="border-b border-base-300/60 px-4 py-3">
            <span className="text-[9px] font-bold uppercase tracking-wider text-base-content/40">Merchant View</span>
            <p className="text-[10px] text-base-content/30 mt-0.5">What you see while the AI works</p>
          </div>

          <div className="p-4 space-y-3 flex-1">
            {/* Account summary */}
            <div className="rounded-lg border border-base-300/50 bg-base-100 p-3">
              <p className="text-[10px] font-semibold text-base-content/40 mb-2">ACCOUNT DRG-2048</p>
              <div className="space-y-1.5 text-[11px]">
                <div className="flex justify-between">
                  <span className="text-base-content/50">Status</span>
                  <span className="font-semibold text-blue-500">Negotiating</span>
                </div>
                <div className="flex justify-between">
                  <span className="text-base-content/50">Balance</span>
                  <span className="font-mono">$1,250</span>
                </div>
                <div className="flex justify-between">
                  <span className="text-base-content/50">Days</span>
                  <span className="font-mono">42</span>
                </div>
                <div className="flex justify-between">
                  <span className="text-base-content/50">Messages</span>
                  <span className="font-mono">{messages.length}</span>
                </div>
              </div>
            </div>

            {/* AI confidence */}
            <div className="rounded-lg border border-base-300/50 bg-base-100 p-3">
              <p className="text-[10px] font-semibold text-base-content/40 mb-2">AI ASSESSMENT</p>
              <div className="space-y-2">
                <div>
                  <div className="flex justify-between text-[10px] mb-1">
                    <span className="text-base-content/50">Resolution likelihood</span>
                    <span className="font-semibold text-success">High</span>
                  </div>
                  <div className="h-1.5 rounded-full bg-base-300/50">
                    <div className="h-1.5 rounded-full bg-success w-3/4 transition-all" />
                  </div>
                </div>
                <div>
                  <div className="flex justify-between text-[10px] mb-1">
                    <span className="text-base-content/50">Sentiment</span>
                    <span className="font-semibold text-blue-500">Cooperative</span>
                  </div>
                  <div className="h-1.5 rounded-full bg-base-300/50">
                    <div className="h-1.5 rounded-full bg-blue-400 w-4/5 transition-all" />
                  </div>
                </div>
              </div>
            </div>

            {/* Audit trail */}
            <div className="rounded-lg border border-base-300/50 bg-base-100 p-3">
              <p className="text-[10px] font-semibold text-base-content/40 mb-2">AUDIT TRAIL</p>
              <div className="space-y-1.5 text-[10px] text-base-content/45">
                <div className="flex items-center gap-1.5">
                  <div className="h-1 w-1 rounded-full bg-success" />
                  Session initiated
                </div>
                <div className="flex items-center gap-1.5">
                  <div className="h-1 w-1 rounded-full bg-blue-400" />
                  Options presented
                </div>
                {messages.length > 2 && (
                  <div className="flex items-center gap-1.5">
                    <div className="h-1 w-1 rounded-full bg-amber-400" />
                    Negotiation active
                  </div>
                )}
                {messages.length > 4 && (
                  <div className="flex items-center gap-1.5">
                    <div className="h-1 w-1 rounded-full bg-success" />
                    Resolution path identified
                  </div>
                )}
              </div>
            </div>
          </div>

          <div className="border-t border-base-300/60 px-4 py-3">
            <p className="text-[9px] text-base-content/30 text-center">
              Real-time sync &middot; Every message logged
            </p>
          </div>
        </div>
      </div>
    </div>
  );
}
