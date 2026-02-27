import { useTranslations } from 'next-intl';
import { Link } from '@/i18n/navigation';
import { Check, ArrowRight, Zap } from 'lucide-react';

export default function PricingPage() {
  const t = useTranslations('Pricing');

  const plans = [
    {
      name: 'Starter',
      price: '$49',
      period: '/mo',
      description: 'For small business pilots validating automated recovery.',
      highlight: false,
      features: [
        'Up to 50 active debtor accounts',
        '5% recovery fee on collected funds',
        'AI negotiation with contract citation',
        'Stripe Connect settlement links',
        'Standard email support',
      ],
      cta: 'Start Pilot',
    },
    {
      name: 'Growth',
      price: '$149',
      period: '/mo',
      description: 'For teams scaling recovery operations across portfolios.',
      highlight: true,
      features: [
        'Up to 250 active debtor accounts',
        '5% recovery fee on collected funds',
        'Custom tone and escalation presets',
        'Priority queue scoring algorithm',
        'CSV export and audit trail access',
        'Priority support with SLA',
      ],
      cta: 'Choose Growth',
    },
    {
      name: 'Scale',
      price: '$399',
      period: '/mo',
      description: 'For larger portfolios requiring full operational control.',
      highlight: false,
      features: [
        'Up to 1,000 active debtor accounts',
        '5% recovery fee on collected funds',
        'Advanced analytics dashboard',
        'Multi-user team access',
        'API access for integrations',
        'Dedicated account manager',
        'Custom SLA and compliance review',
      ],
      cta: 'Choose Scale',
    },
  ];

  return (
    <main>
      <section className="hero-gradient py-16 sm:py-20">
        <div className="app-shell max-w-2xl space-y-5">
          <span className="badge badge-primary badge-outline text-[10px] font-bold uppercase tracking-widest">Pricing</span>
          <h1 className="text-4xl font-bold sm:text-5xl">
            Simple, <span className="text-base-content/40">transparent</span> pricing
          </h1>
          <p className="text-base text-base-content/60 leading-relaxed">
            Performance-based model. You only pay the recovery fee when funds are actually collected. No recovery, no fee.
          </p>
        </div>
      </section>

      <section className="py-16">
        <div className="app-shell grid gap-5 md:grid-cols-3">
          {plans.map((plan) => (
            <article
              key={plan.name}
              className={`surface-card relative ${plan.highlight ? 'border-primary/40 shadow-lg shadow-primary/5' : ''}`}
            >
              {plan.highlight && (
                <div className="absolute -top-3 left-6">
                  <span className="badge badge-primary gap-1 text-[10px] font-bold uppercase tracking-widest">
                    <Zap className="h-3 w-3" /> Most Popular
                  </span>
                </div>
              )}
              <div className="card-body p-6">
                <div>
                  <p className="text-label">{plan.name}</p>
                  <p className="mt-1 text-sm text-base-content/55">{plan.description}</p>
                </div>
                <div className="mt-4 flex items-baseline gap-1">
                  <span className="text-4xl font-bold">{plan.price}</span>
                  <span className="text-label">{plan.period}</span>
                </div>
                <div className="divider my-3" />
                <ul className="space-y-2.5">
                  {plan.features.map((feature) => (
                    <li key={feature} className="flex items-start gap-2.5 text-sm text-base-content/65">
                      <Check className="mt-0.5 h-4 w-4 text-success shrink-0" />
                      {feature}
                    </li>
                  ))}
                </ul>
                <Link href="/login" className={`btn mt-6 w-full gap-2 ${plan.highlight ? 'btn-primary' : 'btn-outline'}`}>
                  {plan.cta} <ArrowRight className="h-4 w-4" />
                </Link>
              </div>
            </article>
          ))}
        </div>
      </section>

      <section className="py-8">
        <div className="app-shell">
          <div className="surface-card">
            <div className="card-body p-6 sm:p-8 text-center">
              <span className="text-label">Performance-Based Model</span>
              <p className="mx-auto mt-3 max-w-3xl text-sm text-base-content/60 leading-relaxed">
                Dragun operates on a <span className="font-bold text-base-content">5% platform fee</span> applied only to
                successfully recovered funds processed through Stripe Connect. Monthly subscription covers platform access,
                AI compute, and support. No hidden fees. No long-term contracts. Cancel anytime.
              </p>
            </div>
          </div>
        </div>
      </section>

      <section className="py-12">
        <div className="app-shell">
          <div className="surface-card-elevated gradient-mesh">
            <div className="card-body p-8 sm:p-12 text-center">
              <h2 className="text-2xl font-bold sm:text-3xl">Need a custom plan?</h2>
              <p className="mx-auto mt-2 max-w-xl text-sm text-base-content/60">
                For portfolios exceeding 1,000 accounts, white-label requirements, or specific compliance needs.
              </p>
              <Link href="/contact" className="btn btn-primary btn-lg mt-6 gap-2">
                Contact Sales <ArrowRight className="h-4 w-4" />
              </Link>
            </div>
          </div>
        </div>
      </section>
    </main>
  );
}
