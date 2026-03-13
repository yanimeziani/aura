import { getTranslations } from 'next-intl/server';
import { redirect } from '@/i18n/navigation';
import { getMerchantId } from '@/lib/auth';
import TutorialClient from './TutorialClient';

export default async function OnboardingTutorialPage({
  params,
}: {
  params: Promise<{ locale: string }>;
}) {
  const { locale } = await params;
  const t = await getTranslations('OnboardingTutorial');
  const merchantId = await getMerchantId();

  if (!merchantId) {
    redirect({ href: '/login', locale });
  }

  return (
    <div className="min-h-screen bg-base-100 px-4 py-10 text-base-content sm:px-6 sm:py-14">
      <div className="mx-auto w-full max-w-4xl">
        <TutorialClient />
      </div>
      <p className="mt-8 text-center text-xs text-base-content/50">{t('footer')}</p>
    </div>
  );
}
