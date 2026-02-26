import { getTranslations } from 'next-intl/server';
import { redirect } from '@/i18n/navigation';
import { getMerchantId } from '@/lib/auth';
import ProfileForm from './ProfileForm';

export default async function OnboardingProfilePage({
  params,
}: {
  params: Promise<{ locale: string }>;
}) {
  const { locale } = await params;
  const t = await getTranslations('OnboardingProfile');
  const merchantId = await getMerchantId();

  if (!merchantId) {
    redirect({ href: '/login', locale });
  }

  return (
    <div className="min-h-screen bg-black text-white flex items-center justify-center px-6 py-16">
      <div className="w-full max-w-3xl space-y-10">
        <div className="space-y-3">
          <p className="text-xs uppercase tracking-[0.2em] text-white/40 font-semibold">
            {t('eyebrow')}
          </p>
          <h1 className="text-3xl sm:text-4xl font-black tracking-tight">
            {t('title')}
          </h1>
          <p className="text-white/60 text-sm sm:text-base">
            {t('subtitle')}
          </p>
        </div>
        <div className="rounded-[2.5rem] border border-white/10 bg-white/[0.03] p-8 sm:p-10 shadow-2xl">
          <ProfileForm />
        </div>
      </div>
    </div>
  );
}
