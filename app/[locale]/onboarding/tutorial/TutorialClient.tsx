'use client';

import { useState } from 'react';
import { useTranslations } from 'next-intl';
import { useRouter } from '@/i18n/navigation';
import { completeOnboardingTutorial } from '@/app/actions/onboarding';

const steps = [
  { key: 'step1', title: 'step1Title', description: 'step1Desc' },
  { key: 'step2', title: 'step2Title', description: 'step2Desc' },
  { key: 'step3', title: 'step3Title', description: 'step3Desc' },
  { key: 'step4', title: 'step4Title', description: 'step4Desc' },
];

export default function TutorialClient() {
  const t = useTranslations('OnboardingTutorial');
  const router = useRouter();
  const [activeStep, setActiveStep] = useState(0);
  const [loading, setLoading] = useState(false);

  async function handleComplete() {
    setLoading(true);
    const result = await completeOnboardingTutorial();
    if (result.success) {
      router.push('/dashboard');
    } else {
      setLoading(false);
    }
  }

  const current = steps[activeStep];

  return (
    <div className="space-y-10">
      <div className="flex flex-col gap-4 sm:flex-row sm:items-start sm:justify-between">
        <div>
          <p className="text-label">{t('eyebrow')}</p>
          <h1 className="mt-2 text-3xl sm:text-4xl font-bold tracking-tight">{t('title')}</h1>
          <p className="mt-2 max-w-2xl text-sm text-base-content/60 sm:text-base">{t('subtitle')}</p>
        </div>
        <button
          type="button"
          onClick={handleComplete}
          className="btn btn-ghost text-xs uppercase tracking-widest self-start"
        >
          {t('skip')}
        </button>
      </div>

      <div className="card bg-base-200/50 border border-base-300 p-6 shadow-lg sm:p-8">
        <div className="mb-6 h-1.5 overflow-hidden rounded-full bg-base-300">
          <div
            className="h-full bg-primary transition-all duration-300"
            style={{ width: `${((activeStep + 1) / steps.length) * 100}%` }}
          />
        </div>

        <div className="flex flex-wrap items-center gap-2 mb-6">
          {steps.map((step, index) => (
            <span
              key={step.key}
              className={`badge ${
                index === activeStep ? 'badge-primary' : index < activeStep ? 'badge-success badge-outline' : 'badge-neutral badge-outline'
              } text-[10px] font-bold uppercase tracking-widest`}
            >
              {t('stepLabel', { count: index + 1 })}
            </span>
          ))}
        </div>

        <div className="space-y-4 py-4">
          <h2 className="text-2xl font-bold">{t(current.title)}</h2>
          <p className="whitespace-pre-line text-sm leading-relaxed text-base-content/65">
            {t(current.description)}
          </p>
        </div>

        <div className="flex items-center justify-between pt-6">
          <button
            type="button"
            disabled={activeStep === 0}
            onClick={() => setActiveStep((prev) => Math.max(prev - 1, 0))}
            className="btn btn-ghost text-xs uppercase tracking-widest disabled:opacity-40"
          >
            {t('back')}
          </button>
          {activeStep < steps.length - 1 ? (
            <button
              type="button"
              onClick={() => setActiveStep((prev) => Math.min(prev + 1, steps.length - 1))}
              className="btn btn-primary text-xs font-bold uppercase tracking-widest"
            >
              {t('next')}
            </button>
          ) : (
            <button
              type="button"
              onClick={handleComplete}
              disabled={loading}
              className="btn btn-primary text-xs font-bold uppercase tracking-widest"
            >
              {loading ? <span className="loading loading-spinner loading-sm" /> : t('finish')}
            </button>
          )}
        </div>
      </div>
    </div>
  );
}
