'use client';

import { FormEvent, useMemo, useState } from 'react';
import { ShieldCheck, Activity, Lock } from 'lucide-react';
import Logo from '@/components/Logo';

type Message = {
  role: 'agent' | 'user';
  text: string;
};

function buildReply(input: string) {
  const normalized = input.toLowerCase();

  if (normalized.includes('dispute') || normalized.includes('cancel')) {
    return 'I understand. In this demo account, clause 4.2 requires written notice 30 days in advance. We can open a dispute review while keeping a temporary payment plan active.';
  }

  if (normalized.includes('plan') || normalized.includes('installment') || normalized.includes('split')) {
    return 'Yes. For demo case DRG-2048, we can schedule two payments this week and auto-send receipts after each settlement.';
  }

  if (normalized.includes('pay') || normalized.includes('today')) {
    return 'Great. Demo secure link generated: pay.dragun.app/demo/DRG-2048. This is a sandbox link and no real charge is executed.';
  }

  return 'Understood. In demo mode, I can offer full payment, split settlement, or dispute review with contract citation. Which path do you prefer?';
}

export default function InteractiveRecoveryDemo() {
  const initialMessages = useMemo<Message[]>(
    () => [
      {
        role: 'agent',
        text: 'Hello. This is Dragun demo mode for case DRG-2048. Balance: 1,250 CAD. I can propose compliant options and cite contract terms.',
      },
    ],
    []
  );

  const [messages, setMessages] = useState<Message[]>(initialMessages);
  const [input, setInput] = useState('');
  const [typing, setTyping] = useState(false);

  const runAgentReply = (reply: string) => {
    setTyping(true);
    setMessages((prev) => [...prev, { role: 'agent', text: '' }]);

    let index = 0;
    const timer = setInterval(() => {
      index += 1;
      setMessages((prev) => {
        const copy = [...prev];
        const last = copy[copy.length - 1];
        if (last && last.role === 'agent') {
          last.text = reply.slice(0, index);
        }
        return copy;
      });

      if (index >= reply.length) {
        clearInterval(timer);
        setTyping(false);
      }
    }, 12);
  };

  const handleSend = (text: string) => {
    const clean = text.trim();
    if (!clean || typing) return;

    setMessages((prev) => [...prev, { role: 'user', text: clean }]);
    setInput('');
    runAgentReply(buildReply(clean));
  };

  const onSubmit = (event: FormEvent<HTMLFormElement>) => {
    event.preventDefault();
    handleSend(input);
  };

  return (
    <div className="surface-card lg:col-span-8">
      <div className="card-body gap-4 p-4 sm:p-6">
        <div className="flex items-center justify-between gap-3">
          <div className="flex items-center gap-3">
            <Logo className="h-7 w-auto" />
            <div>
              <p className="text-sm font-semibold">Recovery Agent Live Demo</p>
              <p className="text-xs text-base-content/60">Case DRG-2048 · Synthetic data</p>
            </div>
          </div>
          <span className="badge badge-outline">Sandbox</span>
        </div>

        <div className="rounded-2xl border border-neutral/20 bg-neutral p-4 text-neutral-content sm:p-5">
          <div className="mb-3 flex flex-wrap gap-2">
            <span className="badge badge-sm border-neutral-content/20 bg-neutral-content/10 text-neutral-content">Secure session</span>
            <span className="badge badge-sm border-neutral-content/20 bg-neutral-content/10 text-neutral-content">Policy cite enabled</span>
            <span className="badge badge-sm border-neutral-content/20 bg-neutral-content/10 text-neutral-content">Stripe sandbox</span>
          </div>

          <div className="mb-3 grid gap-2 rounded-xl border border-neutral-content/20 bg-neutral-content/5 p-3 font-mono text-xs text-neutral-content/75 sm:grid-cols-3">
            <p>SESSION_ID: DRG-2048-DEV</p>
            <p>RISK_PROFILE: MEDIUM</p>
            <p>ESCALATION: LEGAL_REVIEW</p>
          </div>

          <div className="mb-3 flex items-center gap-2 text-xs text-neutral-content/80">
            <Activity className="h-3.5 w-3.5" />
            SYSTEM: Running compliant negotiation protocol v2.4
          </div>

          <div className="max-h-72 space-y-3 overflow-y-auto rounded-xl border border-neutral-content/20 bg-neutral-content/5 p-3 sm:p-4">
            {messages.map((message, idx) => (
              <div
                key={`${message.role}-${idx}`}
                className={
                  message.role === 'user'
                    ? 'ml-auto max-w-[85%] rounded-xl border border-info/40 bg-info/20 p-3 text-info-content'
                    : 'max-w-[85%] rounded-xl border border-neutral-content/20 bg-neutral-content/10 p-3 text-neutral-content/85'
                }
              >
                {message.text}
              </div>
            ))}
          </div>

          <div className="mt-4 flex flex-wrap gap-2">
            {['I can pay today', 'Can we split this amount?', 'I want to dispute this'].map((preset) => (
              <button
                key={preset}
                onClick={() => handleSend(preset)}
                disabled={typing}
                className="btn btn-xs border-neutral-content/30 bg-transparent text-neutral-content/80 hover:bg-neutral-content/10"
                type="button"
              >
                {preset}
              </button>
            ))}
          </div>

          <form onSubmit={onSubmit} className="mt-4 flex flex-col gap-2 sm:flex-row">
            <input
              value={input}
              onChange={(event) => setInput(event.target.value)}
              placeholder={typing ? 'Agent is typing...' : 'Type a message to test the demo'}
              disabled={typing}
              className="input input-bordered h-11 w-full border-neutral-content/30 bg-neutral-content/5 text-neutral-content placeholder:text-neutral-content/40"
            />
            <button type="submit" disabled={typing || !input.trim()} className="btn btn-primary h-11 px-6">
              Send
            </button>
          </form>
        </div>

        <div className="divider my-0" />

        <div className="grid gap-2 text-xs text-base-content/70 sm:grid-cols-3">
          <p className="inline-flex items-center gap-1.5"><ShieldCheck className="h-3.5 w-3.5" /> Contract-aware replies</p>
          <p className="inline-flex items-center gap-1.5"><Lock className="h-3.5 w-3.5" /> Encrypted transit channel</p>
          <p className="inline-flex items-center gap-1.5"><Activity className="h-3.5 w-3.5" /> Full interaction audit trail</p>
        </div>
      </div>
    </div>
  );
}
