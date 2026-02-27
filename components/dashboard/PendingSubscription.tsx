'use client';

import { useEffect, useRef, useState } from 'react';
import { ArrowRight, CreditCard } from 'lucide-react';

interface Props {
  subscribeAction: (formData: FormData) => Promise<void>;
}

export default function PendingSubscription({ subscribeAction }: Props) {
  const [pendingPlan, setPendingPlan] = useState<string | null>(null);
  const [submitting, setSubmitting] = useState(false);
  const formRef = useRef<HTMLFormElement>(null);

  useEffect(() => {
    const plan = localStorage.getItem('pending_plan');
    if (plan && ['starter', 'growth', 'scale'].includes(plan)) {
      setPendingPlan(plan);
      localStorage.removeItem('pending_plan');
    }
  }, []);

  if (!pendingPlan) return null;

  async function handleSubmit() {
    setSubmitting(true);
    const fd = new FormData();
    fd.set('plan', pendingPlan!);
    await subscribeAction(fd);
  }

  const planDetails: Record<string, { price: string; debtors: string }> = {
    starter: { price: '$49/mo', debtors: '50 debtors' },
    growth: { price: '$149/mo', debtors: '250 debtors' },
    scale: { price: '$399/mo', debtors: '1,000 debtors' },
  };

  const details = planDetails[pendingPlan] ?? planDetails.starter;

  return (
    <div className="alert shadow-elevated border-primary/30 bg-primary/5">
      <CreditCard className="h-5 w-5 text-primary shrink-0" />
      <div className="flex-1">
        <p className="font-semibold">
          Complete your {pendingPlan.charAt(0).toUpperCase() + pendingPlan.slice(1)} subscription
        </p>
        <p className="text-sm text-base-content/60 mt-0.5">
          {details.price} &middot; {details.debtors} &middot; Cancel anytime
        </p>
      </div>
      <div className="flex gap-2">
        <button
          onClick={() => setPendingPlan(null)}
          className="btn btn-ghost btn-sm"
        >
          Dismiss
        </button>
        <button
          onClick={handleSubmit}
          disabled={submitting}
          className="btn btn-primary btn-sm gap-1.5"
        >
          {submitting ? (
            <span className="loading loading-spinner loading-xs" />
          ) : (
            <>
              Subscribe
              <ArrowRight className="h-3.5 w-3.5" />
            </>
          )}
        </button>
      </div>
    </div>
  );
}
