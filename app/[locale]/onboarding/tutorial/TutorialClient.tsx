'use client';

import { useState } from 'react';
import { useTranslations } from 'next-intl';
import { useRouter } from '@/i18n/navigation';
import { completeOnboardingTutorial } from '@/app/actions/onboarding';

const steps = [
  {
    key: 'step1',
    title: 'step1Title',
    description: 'step1Desc',
  },
  {
    key: 'step2',
    title: 'step2Title',
    description: 'step2Desc',
  },
  {
    key: 'step3',
    title: 'step3Title',
    description: 'step3Desc',
  },
  {
    key: 'step4',
    title: 'step4Title',
    description: 'step4Desc',
  },
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

  async function handleSkip() {
    await handleComplete();
  }

  const current = steps[activeStep];

  return (
    <div className="space-y-10">
      <div className="flex items-center justify-between">
        <div>
          <p className="text-xs uppercase tracking-[0.2em] text-white/40 font-semibold">
            {t('eyebrow')}
          </p>
          <h1 className="text-3xl sm:text-4xl font-black tracking-tight">
            {t('title')}
          </h1>
          <p className="text-white/60 text-sm sm:text-base mt-2 max-w-2xl">
            {t('subtitle')}
          </p>
        </div>
        <button
          type="button"
          onClick={handleSkip}
          className="text-xs font-semibold uppercase tracking-[0.2em] text-white/60 hover:text-white transition"
        >
          {t('skip')}
        </button>
      </div>

      <div className="rounded-[2.5rem] border border-white/10 bg-white/[0.03] p-8 sm:p-10 space-y-8">
        <div className="flex flex-wrap items-center gap-4">
          {steps.map((step, index) => {
            const isActive = index === activeStep;
            const isComplete = index < activeStep;
            return (
              <div
                key={step.key}
                className={`flex items-center gap-2 rounded-full border px-4 py-2 text-xs font-semibold uppercase tracking-[0.2em] ${
                  isActive
                    ? 'border-white/40 bg-white/15 text-white'
                    : isComplete
                    ? 'border-white/20 bg-white/10 text-white/80'
                    : 'border-white/10 text-white/40'
                }`}
              >
                <span>{t('stepLabel', { count: index + 1 })}</span>
              </div>
            );
          })}
        </div>

        <div className="space-y-4">
          <h2 className="text-2xl font-bold">{t(current.title)}</h2>
          <p className="text-white/60 text-sm leading-relaxed whitespace-pre-line">
            {t(current.description)}
          </p>
        </div>

        <div className="flex items-center justify-between">
          <button
            type="button"
            disabled={activeStep === 0}
            onClick={() => setActiveStep((prev) => Math.max(prev - 1, 0))}
            className="rounded-full border border-white/20 px-5 py-2 text-xs font-semibold uppercase tracking-[0.2em] text-white/70 transition hover:text-white disabled:opacity-40"
          >
            {t('back')}
          </button>
          {activeStep < steps.length - 1 ? (
            <button
              type="button"
              onClick={() => setActiveStep((prev) => Math.min(prev + 1, steps.length - 1))}
              className="rounded-full bg-white px-6 py-3 text-xs font-black uppercase tracking-[0.2em] text-black transition hover:opacity-90"
            >
              {t('next')}
            </button>
          ) : (
            <button
              type="button"
              onClick={handleComplete}
              disabled={loading}
              className="rounded-full bg-white px-6 py-3 text-xs font-black uppercase tracking-[0.2em] text-black transition hover:opacity-90 disabled:opacity-60"
            >
              {loading ? t('finishing') : t('finish')}
            </button>
          )}
        </div>
      </div>
    </div>
  );
}
