'use client';

import { use, useEffect, useMemo, useState } from 'react';
import { useTranslations } from 'next-intl';
import { Link } from '@/i18n/navigation';
import { createClient } from '@/lib/supabase/client';
import { ChevronLeft, ShieldCheck, Sparkles, Check, ArrowRight, AlertCircle } from 'lucide-react';

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
  const [payError, setPayError] = useState<string | null>(null);
  const [paying, setPaying] = useState(false);
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
    if (!debtor || paying) return;
    setPaying(true);
    setPayError(null);
    try {
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
      const data = await res.json();
      if (!res.ok || !data.url) {
        setPayError(data.error || 'Payment could not be initiated. Please try again.');
        setPaying(false);
        return;
      }
      window.location.href = data.url;
    } catch {
      setPayError('Network error. Please check your connection and try again.');
      setPaying(false);
    }
  };

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

  const fullDebt = debtor.total_debt;
  const settlementFloor = debtor.merchant.settlement_floor;
  const settlementAmount = fullDebt * Math.max(0.7, settlementFloor);
  const savingPercent = Math.round((1 - settlementAmount / fullDebt) * 100);

  const plans = [
    {
      key: 'full',
      label: t('payInFull'),
      desc: t('payInFullDesc'),
      amount: fullDebt,
      display: `${debtor.currency} ${fullDebt.toLocaleString()}`,
      benefits: [t('benefit1Full'), t('benefit2Full')],
      cta: t('payFullButton'),
      description: 'Full Debt Payment',
      featured: false,
    },
    {
      key: 'settlement',
      label: t('lumpSum'),
      desc: t('lumpSumDesc'),
      amount: settlementAmount,
      display: `${debtor.currency} ${settlementAmount.toLocaleString()}`,
      strikethrough: `${debtor.currency} ${fullDebt.toLocaleString()}`,
      benefits: [t('benefit1Lump', { percent: savingPercent }), t('benefit2Lump'), t('benefit3Lump')],
      cta: t('acceptSettlement'),
      description: 'One-time Settlement',
      featured: true,
    },
    {
      key: 'installment',
      label: t('installments'),
      desc: t('installmentsDesc'),
      amount: fullDebt / 3,
      display: `${debtor.currency} ${(fullDebt / 3).toLocaleString()}`,
      suffix: t('perMonth'),
      benefits: [t('benefit1Install'), t('benefit2Install')],
      cta: t('startInstallments'),
      description: 'First Installment',
      featured: false,
    },
  ];

  return (
    <main className="min-h-screen bg-base-100 text-base-content">
      <div className="app-shell max-w-6xl py-8 sm:py-16">
        {/* Back */}
        <Link
          href={`/chat/${debtorId}`}
          className="btn btn-ghost gap-2 mb-10"
        >
          <ChevronLeft className="w-4 h-4" />
          {t('returnToChat')}
        </Link>

        {/* Header */}
        <div className="text-center mb-12 space-y-4">
          <div className="badge badge-primary badge-outline gap-1.5 py-3 px-4">
            <Sparkles className="w-3 h-3" />
            {t('portalBadge')}
          </div>
          <h1 className="text-3xl sm:text-5xl font-bold tracking-tight">
            {t('title')}{' '}
            <span className="text-primary">{t('titleHighlight')}</span>{' '}
            {t('titleEnd')}
          </h1>
          <p className="text-base-content/50 max-w-xl mx-auto">{t('subtitle')}</p>
        </div>

        {/* Error */}
        {payError && (
          <div className="alert alert-error mb-8 max-w-2xl mx-auto shadow-warm">
            <AlertCircle className="w-5 h-5 shrink-0" />
            <span className="text-sm">{payError}</span>
            <button className="btn btn-ghost" onClick={() => setPayError(null)}>
              Dismiss
            </button>
          </div>
        )}

        {/* Plans */}
        <div className="grid grid-cols-1 md:grid-cols-3 gap-6 max-w-5xl mx-auto">
          {plans.map((plan) => (
            <div
              key={plan.key}
              className={`card bg-base-200/50 border shadow-warm transition-shadow hover:shadow-elevated ${
                plan.featured
                  ? 'border-primary/30 ring-1 ring-primary/10 scale-[1.02]'
                  : 'border-base-300/50'
              }`}
            >
              {plan.featured && (
                <div className="absolute -top-3 left-1/2 -translate-x-1/2">
                  <span className="badge badge-primary badge-sm font-bold">
                    {t('recommended')}
                  </span>
                </div>
              )}
              <div className="card-body p-6 sm:p-8 gap-5">
                <div>
                  <p className="text-label">{plan.label}</p>
                  <p className="text-xs text-base-content/40 mt-0.5">{plan.desc}</p>
                </div>

                <div>
                  <span className="text-3xl sm:text-4xl font-bold tracking-tight">
                    {plan.display}
                  </span>
                  {plan.suffix && (
                    <span className="text-sm text-base-content/40 ml-1">{plan.suffix}</span>
                  )}
                  {plan.strikethrough && (
                    <p className="text-sm text-base-content/30 line-through mt-1">
                      {plan.strikethrough}
                    </p>
                  )}
                </div>

                <div className="divider my-0" />

                <ul className="space-y-3 flex-1">
                  {plan.benefits.map((b, i) => (
                    <li key={i} className="flex items-start gap-2.5 text-sm">
                      <Check className={`w-4 h-4 shrink-0 mt-0.5 ${plan.featured ? 'text-primary' : 'text-base-content/30'}`} />
                      <span className="text-base-content/70">{b}</span>
                    </li>
                  ))}
                </ul>

                <button
                  onClick={() => handlePayment(plan.amount, plan.description)}
                  disabled={paying}
                  className={`btn w-full gap-2 ${plan.featured ? 'btn-primary' : 'btn-ghost border border-base-300/50'}`}
                >
                  {paying ? (
                    <span className="loading loading-spinner loading-sm" />
                  ) : (
                    <>
                      {plan.cta}
                      <ArrowRight className="w-4 h-4" />
                    </>
                  )}
                </button>
              </div>
            </div>
          ))}
        </div>

        {/* Disclaimer */}
        <div className="mt-16 text-center max-w-2xl mx-auto">
          <div className="card bg-base-200/30 border border-base-300/30">
            <div className="card-body p-6 items-center text-center">
              <ShieldCheck className="w-5 h-5 text-base-content/20 mb-1" />
              <p className="text-label mb-2">Protocol Disclosure</p>
              <p className="text-xs text-base-content/40 leading-relaxed max-w-md">
                {t('disclaimer', { merchant: debtor.merchant.name })}
              </p>
            </div>
          </div>
        </div>
      </div>
    </main>
  );
}
