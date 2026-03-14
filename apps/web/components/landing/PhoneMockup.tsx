'use client';

import { useTranslations } from 'next-intl';

export default function PhoneMockup() {
  const t = useTranslations('Home');
  return (
    <div className="phone-frame w-[280px] bg-[#faf9f7] animate-float">
      {/* Status bar */}
      <div className="flex items-center justify-between px-5 py-2 bg-[#f5f3f0]">
        <span className="text-[10px] font-medium text-[#999]">9:41</span>
        <div className="flex gap-1">
          <div className="w-3.5 h-2 rounded-sm bg-[#ccc]" />
          <div className="w-1 h-2 rounded-sm bg-[#ccc]" />
        </div>
      </div>

      {/* Chat header */}
      <div className="border-b border-[#e8e4df] px-4 py-3">
        <p className="text-[13px] font-semibold text-[#444]">Atlas Services</p>
        <p className="text-[10px] text-[#aaa]">Account Resolution</p>
      </div>

      {/* Balance bar */}
      <div className="mx-3 mt-3 rounded-xl bg-[#f0ece6] px-3 py-2 flex items-center justify-between">
        <span className="text-[10px] text-[#888]">Balance</span>
        <span className="text-[12px] font-semibold text-[#555]">CAD 1,250.00</span>
      </div>

      {/* Messages */}
      <div className="p-3 space-y-2.5 min-h-[200px]">
        <div className="max-w-[85%]">
          <div className="rounded-2xl rounded-bl-md bg-[#f0ece6] px-3 py-2.5">
            <p className="text-[12px] leading-relaxed text-[#444]">
              Hi Sarah, thanks for reaching out. I have a few flexible options that could work for your situation.
            </p>
          </div>
        </div>

        <div className="max-w-[80%] ml-auto">
          <div className="rounded-2xl rounded-br-md bg-[#5b4a3f] px-3 py-2.5">
            <p className="text-[12px] leading-relaxed text-white">
              Can I set up a payment plan?
            </p>
          </div>
        </div>

        <div className="max-w-[85%]">
          <div className="rounded-2xl rounded-bl-md bg-[#f0ece6] px-3 py-2.5">
            <p className="text-[12px] leading-relaxed text-[#444]">
              Of course. We can split this into 3 payments of $416.67/mo. Would that be more manageable?
            </p>
          </div>
        </div>

        <div className="max-w-[80%] ml-auto">
          <div className="rounded-2xl rounded-br-md bg-[#5b4a3f] px-3 py-2.5">
            <p className="text-[12px] leading-relaxed text-white">
              Yes, that works for me
            </p>
          </div>
        </div>

        <div className="max-w-[85%]">
          <div className="rounded-2xl rounded-bl-md bg-[#f0ece6] px-3 py-2.5">
            <p className="text-[12px] leading-relaxed text-[#444]">
              Great, I&apos;ll send you a secure payment link now.
            </p>
          </div>
        </div>
      </div>

      {/* Quick options */}
      <div className="px-3 pb-2 flex gap-1.5 overflow-hidden">
        <span className="shrink-0 rounded-full border border-[#e0dbd4] bg-white px-2.5 py-1 text-[10px] text-[#888]">{t('viewPaymentOptions')}</span>
        <span className="shrink-0 rounded-full border border-[#e0dbd4] bg-white px-2.5 py-1 text-[10px] text-[#888]">I need more time</span>
      </div>

      {/* Input */}
      <div className="border-t border-[#e8e4df] px-3 py-2.5 flex items-center gap-2">
        <div className="flex-1 rounded-lg border border-[#e0dbd4] bg-[#faf9f7] px-3 py-1.5 text-[11px] text-[#c4b9a8]">
          Type your message...
        </div>
        <div className="flex h-7 w-7 items-center justify-center rounded-lg bg-[#5b4a3f]">
          <svg className="h-3 w-3 text-white" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2.5"><path d="M22 2L11 13M22 2l-7 20-4-9-9-4 20-7z"/></svg>
        </div>
      </div>

      {/* Home indicator */}
      <div className="flex justify-center py-2">
        <div className="h-1 w-24 rounded-full bg-[#ddd]" />
      </div>
    </div>
  );
}
