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
    <div className="min-h-screen bg-base-100 text-base-content px-4 py-10 sm:px-6 sm:py-14">
      <div className="mx-auto w-full max-w-3xl space-y-10">
        <div className="space-y-3">
          <p className="text-label">{t('eyebrow')}</p>
          <h1 className="text-3xl sm:text-4xl font-bold tracking-tight">{t('title')}</h1>
          <p className="text-sm text-base-content/60 sm:text-base">{t('subtitle')}</p>
        </div>
        <div className="card bg-base-200/50 border border-base-300 p-6 shadow-lg sm:p-8">
          <ProfileForm />
        </div>
      </div>
    </div>
  );
}
