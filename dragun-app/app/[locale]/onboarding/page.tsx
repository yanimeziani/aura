'use client';

import { useState } from 'react';
import { useTranslations, useLocale } from 'next-intl';
import { useRouter } from '@/i18n/navigation';
import {
  ChevronRight,
  ChevronLeft,
  Building2,
  ShieldCheck,
  FileText,
  Rocket,
  CheckCircle2,
  Plus,
  Wallet,
} from 'lucide-react';

export default function OnboardingPage() {
  const t = useTranslations('Onboarding');
  const locale = useLocale();
  const router = useRouter();
  const [step, setStep] = useState(1);
  const [loading, setLoading] = useState(false);

  const [name, setName] = useState('');
  const [strictness, setStrictness] = useState(5);
  const [settlement, setSettlement] = useState(80);
  const [file, setFile] = useState<File | null>(null);

  const totalSteps = 5;

  const handleNext = () => step < totalSteps && setStep(step + 1);
  const handleBack = () => step > 1 && setStep(step - 1);

  async function handleConnectStripe() {
    setLoading(true);
    try {
      const { createStripeConnectAccount } = await import('@/app/actions/stripe-connect');
      const formData = new FormData();
      formData.append('locale', locale);
      await createStripeConnectAccount(formData);
    } catch {
      setLoading(false);
    }
  }

  async function handleFinish() {
    setLoading(true);
    try {
      const { completeOnboarding } = await import('@/app/actions/merchant-settings');
      const { uploadContract } = await import('@/app/actions/upload-contract');

      if (file) {
        const formData = new FormData();
        formData.append('contract', file);
        const uploadResult = await uploadContract(formData);
        if (!uploadResult.success) throw new Error(uploadResult.error || 'Upload failed');
      }

      const onboardingResult = await completeOnboarding({
        name,
        strictness_level: strictness,
        settlement_floor: settlement / 100,
      });

      if (!onboardingResult.success) throw new Error(onboardingResult.error || 'Onboarding update failed');
      router.push('/dashboard');
    } catch (error) {
      const message = error instanceof Error ? error.message : 'Setup failed';
      alert(`${message}. Please check your connection and try again.`);
    } finally {
      setLoading(false);
    }
  }

  const stepIcons = [Building2, ShieldCheck, FileText, Wallet, Rocket];
  const stepLabels = ['Business', 'Policy', 'Docs', 'Stripe', 'Launch'];

  return (
    <div className="min-h-screen bg-base-100 text-base-content flex flex-col items-center justify-center p-6 relative overflow-hidden">
      <div className="absolute top-[-10%] left-[-10%] w-[60%] h-[60%] bg-primary/5 blur-[120px] rounded-full pointer-events-none" />
      <div className="absolute bottom-[-10%] right-[-10%] w-[50%] h-[50%] bg-accent/5 blur-[120px] rounded-full pointer-events-none" />

      <div className="w-full max-w-2xl z-10">
        <div className="text-center mb-12">
          <h1 className="text-4xl font-black tracking-tighter uppercase mb-2">
            {t('title')} <span className="text-primary">DRAGUN.</span>
          </h1>
          <p className="text-base-content/40 text-sm font-medium tracking-tight">{t('subtitle')}</p>
        </div>

        {/* Stepper */}
        <div className="flex justify-between items-center mb-12 relative">
          <div className="absolute left-0 top-1/2 -translate-y-1/2 h-[2px] bg-base-300 w-full -z-10" />
          <div
            className="absolute left-0 top-1/2 -translate-y-1/2 h-[2px] bg-primary transition-all duration-500 -z-10"
            style={{ width: `${((step - 1) / (totalSteps - 1)) * 100}%` }}
          />
          {Array.from({ length: totalSteps }, (_, i) => i + 1).map((s) => (
            <div key={s} className="flex flex-col items-center gap-1">
              <div
                className={`w-10 h-10 rounded-xl flex items-center justify-center border-2 transition-all duration-300 ${
                  s <= step ? 'bg-primary border-primary text-primary-content' : 'bg-base-200 border-base-300 text-base-content/40'
                }`}
              >
                {s < step ? <CheckCircle2 className="w-5 h-5" /> : <span className="text-xs font-black">{s}</span>}
              </div>
              <span className="text-[9px] font-bold uppercase tracking-widest text-base-content/40 hidden sm:block">
                {stepLabels[s - 1]}
              </span>
            </div>
          ))}
        </div>

        {/* Form Container */}
        <div className="card bg-base-200/50 backdrop-blur-xl border border-base-300 shadow-xl p-8 sm:p-10 min-h-[400px] flex flex-col">
          {/* Step 1: Business Profile */}
          {step === 1 && (
            <div className="space-y-8 animate-in fade-in slide-in-from-right-4 duration-500">
              <div className="flex items-center gap-4 mb-4">
                <div className="w-12 h-12 bg-base-300 rounded-2xl flex items-center justify-center">
                  <Building2 className="w-6 h-6" />
                </div>
                <div>
                  <h2 className="text-xl font-black uppercase tracking-widest">{t('step1')}</h2>
                  <p className="text-label">{t('step1Desc')}</p>
                </div>
              </div>
              <div className="space-y-3">
                <label className="text-label">{t('businessName')}</label>
                <input
                  type="text"
                  value={name}
                  onChange={(e) => setName(e.target.value)}
                  placeholder={t('businessNamePlaceholder')}
                  className="input input-bordered w-full text-lg font-bold"
                  autoFocus
                />
              </div>
            </div>
          )}

          {/* Step 2: Policy */}
          {step === 2 && (
            <div className="space-y-10 animate-in fade-in slide-in-from-right-4 duration-500">
              <div className="flex items-center gap-4">
                <div className="w-12 h-12 bg-base-300 rounded-2xl flex items-center justify-center">
                  <ShieldCheck className="w-6 h-6" />
                </div>
                <div>
                  <h2 className="text-xl font-black uppercase tracking-widest">{t('step2')}</h2>
                  <p className="text-label">{t('step2Desc')}</p>
                </div>
              </div>
              <div className="space-y-8">
                <div className="space-y-4">
                  <div className="flex justify-between items-end">
                    <label className="text-label">Strictness Profile</label>
                    <span className="text-2xl font-black">{strictness}<span className="text-xs opacity-30 ml-1">/10</span></span>
                  </div>
                  <input
                    type="range"
                    min="1" max="10"
                    value={strictness}
                    onChange={(e) => setStrictness(parseInt(e.target.value))}
                    className="range range-primary range-xs"
                  />
                </div>
                <div className="space-y-4">
                  <div className="flex justify-between items-end">
                    <label className="text-label">Settlement Floor</label>
                    <span className="text-2xl font-black">{settlement}<span className="text-xs opacity-30 ml-1">%</span></span>
                  </div>
                  <input
                    type="range"
                    min="50" max="100"
                    value={settlement}
                    onChange={(e) => setSettlement(parseInt(e.target.value))}
                    className="range range-primary range-xs"
                  />
                </div>
              </div>
            </div>
          )}

          {/* Step 3: Document Upload */}
          {step === 3 && (
            <div className="space-y-8 animate-in fade-in slide-in-from-right-4 duration-500">
              <div className="flex items-center gap-4">
                <div className="w-12 h-12 bg-base-300 rounded-2xl flex items-center justify-center text-info">
                  <FileText className="w-6 h-6" />
                </div>
                <div>
                  <h2 className="text-xl font-black uppercase tracking-widest">{t('step3')}</h2>
                  <p className="text-label">{t('step3Desc')}</p>
                </div>
              </div>
              <div className="relative group">
                <input
                  type="file"
                  accept=".pdf"
                  onChange={(e) => setFile(e.target.files?.[0] || null)}
                  className="hidden"
                  id="onboarding-upload"
                />
                <label
                  htmlFor="onboarding-upload"
                  className={`w-full h-48 border-2 border-dashed rounded-2xl flex flex-col items-center justify-center gap-4 transition-all cursor-pointer ${
                    file ? 'border-success bg-success/10' : 'border-base-300 hover:border-primary hover:bg-base-300/50'
                  }`}
                >
                  {file ? (
                    <>
                      <CheckCircle2 className="w-10 h-10 text-success" />
                      <span className="text-xs font-black uppercase tracking-widest">{file.name}</span>
                    </>
                  ) : (
                    <>
                      <Plus className="w-10 h-10 text-base-content/20 group-hover:text-base-content/60" />
                      <span className="text-label">{t('uploadDesc')}</span>
                    </>
                  )}
                </label>
              </div>
              <p className="text-xs text-base-content/40 text-center">Optional -- you can upload later from settings</p>
            </div>
          )}

          {/* Step 4: Stripe Connect */}
          {step === 4 && (
            <div className="space-y-8 animate-in fade-in slide-in-from-right-4 duration-500">
              <div className="flex items-center gap-4">
                <div className="w-12 h-12 bg-base-300 rounded-2xl flex items-center justify-center text-secondary">
                  <Wallet className="w-6 h-6" />
                </div>
                <div>
                  <h2 className="text-xl font-black uppercase tracking-widest">Connect Stripe</h2>
                  <p className="text-label">Required to receive debtor payments</p>
                </div>
              </div>
              <div className="space-y-4">
                <div className="rounded-2xl border border-base-300 bg-base-100 p-6 space-y-4">
                  <div className="flex items-start gap-3">
                    <CheckCircle2 className="w-5 h-5 text-success mt-0.5 shrink-0" />
                    <div>
                      <p className="text-sm font-bold">Instant payouts to your bank</p>
                      <p className="text-xs text-base-content/50">Stripe Express handles KYC, compliance, and transfers</p>
                    </div>
                  </div>
                  <div className="flex items-start gap-3">
                    <CheckCircle2 className="w-5 h-5 text-success mt-0.5 shrink-0" />
                    <div>
                      <p className="text-sm font-bold">5% platform fee on recovered debts</p>
                      <p className="text-xs text-base-content/50">No upfront costs -- you only pay when we collect</p>
                    </div>
                  </div>
                  <div className="flex items-start gap-3">
                    <ShieldCheck className="w-5 h-5 text-info mt-0.5 shrink-0" />
                    <div>
                      <p className="text-sm font-bold">PCI-DSS Level 1 compliant</p>
                      <p className="text-xs text-base-content/50">Your debtors&apos; card details never touch our servers</p>
                    </div>
                  </div>
                </div>
                <button
                  onClick={handleConnectStripe}
                  disabled={loading}
                  className="btn btn-secondary w-full h-14 text-sm font-bold uppercase tracking-widest"
                >
                  {loading ? <span className="loading loading-spinner loading-sm" /> : (
                    <>
                      <Wallet className="w-5 h-5" />
                      Connect Stripe Account
                    </>
                  )}
                </button>
                <p className="text-[10px] text-base-content/30 text-center uppercase tracking-widest">
                  You&apos;ll be redirected to Stripe and return here automatically
                </p>
              </div>
            </div>
          )}

          {/* Step 5: Launch */}
          {step === 5 && (
            <div className="text-center space-y-8 py-8 animate-in zoom-in-95 duration-500">
              <div className="w-24 h-24 bg-base-200 border border-base-300 rounded-[2.5rem] flex items-center justify-center shadow-xl mx-auto relative group">
                <div className="absolute inset-0 bg-primary/20 blur-2xl group-hover:blur-3xl transition-all rounded-full" />
                <Rocket className="w-10 h-10 relative z-10" />
              </div>
              <div className="space-y-2">
                <h2 className="text-3xl font-black uppercase tracking-tight">{t('finishTitle')}</h2>
                <p className="text-base-content/50 text-sm font-medium max-w-sm mx-auto">{t('finishDesc')}</p>
              </div>
            </div>
          )}

          {/* Navigation Controls */}
          <div className="mt-auto pt-10 flex gap-4">
            {step > 1 && (
              <button
                onClick={handleBack}
                disabled={loading}
                className="btn btn-outline flex-1 h-14 text-xs font-bold uppercase tracking-widest"
              >
                <ChevronLeft className="w-4 h-4" />
                {t('back')}
              </button>
            )}

            {step < totalSteps ? (
              <button
                onClick={step === 4 ? handleConnectStripe : handleNext}
                disabled={(step === 1 && !name) || loading}
                className={`btn flex-[2] h-14 text-xs font-bold uppercase tracking-widest ${
                  step === 4 ? 'btn-secondary' : 'btn-primary'
                }`}
              >
                {loading ? (
                  <span className="loading loading-spinner loading-sm" />
                ) : step === 4 ? (
                  <>
                    <Wallet className="w-4 h-4" />
                    Connect Stripe
                  </>
                ) : (
                  <>
                    {t('next')}
                    <ChevronRight className="w-4 h-4" />
                  </>
                )}
              </button>
            ) : (
              <button
                onClick={handleFinish}
                disabled={loading}
                className="btn btn-primary flex-[2] h-14 text-xs font-bold uppercase tracking-widest"
              >
                {loading ? <span className="loading loading-spinner loading-sm" /> : (
                  <>
                    {t('complete')}
                    <Rocket className="w-4 h-4" />
                  </>
                )}
              </button>
            )}
          </div>
        </div>
      </div>
    </div>
  );
}
