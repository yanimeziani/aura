'use client';

import { use, useEffect, useMemo, useState } from 'react';
import { useTranslations } from 'next-intl';
import { createClient } from '@/lib/supabase/client';

interface Debtor {
  name: string;
  email: string;
  merchant: {
    name: string;
  };
}

export default function SuccessPage({ params }: { params: Promise<{ debtorId: string }> }) {
  const { debtorId } = use(params);
  const t = useTranslations('Success');
  const [debtor, setDebtor] = useState<Debtor | null>(null);
  const supabase = useMemo(() => createClient(), []);

  useEffect(() => {
    async function fetchDebtor() {
      const { data } = await supabase
        .from('debtors')
        .select('*, merchant:merchants(name)')
        .eq('id', debtorId)
        .single();
      setDebtor(data);
    }
    fetchDebtor();
  }, [debtorId, supabase]);

  if (!debtor) return <div className="p-10 text-center">{t('finalizing')}</div>;

  return (
    <div className="flex flex-col h-screen bg-base-100 text-base-content max-w-md mx-auto border-x border-base-300 shadow-2xl p-8 items-center justify-center space-y-8 relative overflow-hidden">
      <div className="absolute top-0 left-1/2 -translate-x-1/2 w-64 h-64 bg-success/10 blur-[100px] rounded-full -z-10"></div>

      <div className="w-24 h-24 bg-success/20 text-success rounded-full flex items-center justify-center shadow-[0_0_40px_rgba(34,197,94,0.2)] ring-1 ring-success/50 animate-pulse">
        <svg xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24" strokeWidth={3} stroke="currentColor" className="w-12 h-12">
          <path strokeLinecap="round" strokeLinejoin="round" d="M4.5 12.75l6 6 9-13.5" />
        </svg>
      </div>

      <div className="text-center space-y-4">
        <h1 className="text-4xl font-black text-base-content tracking-tight uppercase">{t('title')}</h1>
        <div className="space-y-1">
          <p className="text-lg font-bold text-base-content/80">{t('thankYou', { name: debtor.name })}</p>
          <p className="text-xs text-base-content/50 max-w-[280px] mx-auto leading-relaxed">
            {t('message', { merchant: debtor.merchant.name, email: debtor.email })}
          </p>
        </div>
      </div>

      <div className="bg-base-200/50 border border-base-300 w-full rounded-2xl p-5 text-center shadow-inner">
        <div className="text-[10px] uppercase font-black tracking-widest text-base-content/40 mb-1">{t('transactionId')}</div>
        <div className="text-xs font-mono text-base-content/60">DRGN-SETTLMT-{debtorId.slice(0, 8).toUpperCase()}</div>
      </div>

      <button
        className="btn btn-primary w-full shadow-lg shadow-primary/20 border-none h-12 rounded-xl text-xs font-bold uppercase tracking-widest"
        onClick={() => window.location.href = '/'}
      >
        {t('returnHome')}
      </button>
    </div>
  );
}
