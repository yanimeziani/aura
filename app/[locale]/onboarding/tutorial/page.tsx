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
    <div className="min-h-screen bg-black text-white px-6 py-16">
      <div className="mx-auto w-full max-w-4xl">
        <TutorialClient />
      </div>
      <p className="mt-10 text-center text-xs text-white/30">{t('footer')}</p>
    </div>
  );
}
