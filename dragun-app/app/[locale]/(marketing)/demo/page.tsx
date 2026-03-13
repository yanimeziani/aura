import type { Metadata } from 'next';
import { getTranslations } from 'next-intl/server';
import { Link } from '@/i18n/navigation';
import { ArrowLeft } from 'lucide-react';
import InteractiveRecoveryDemo from '@/components/InteractiveRecoveryDemo';

type Props = { params: Promise<{ locale: string }> };

export async function generateMetadata({ params }: Props): Promise<Metadata> {
  const { locale } = await params;
  const t = await getTranslations({ locale, namespace: 'Demo' });
  return {
    title: t('metaTitle'),
    description: t('metaDesc'),
    openGraph: {
      title: t('metaTitle'),
      description: t('metaDesc'),
    },
  };
}

export default async function DemoPage({ params }: Props) {
  const { locale } = await params;
  const t = await getTranslations({ locale, namespace: 'Home' });

  return (
    <main className="min-h-screen">
      <div className="app-shell max-w-3xl py-8 sm:py-12">
        <Link
          href="/"
          className="inline-flex items-center gap-2 text-sm text-base-content/60 hover:text-base-content mb-8"
        >
          <ArrowLeft className="h-4 w-4" />
          {t('backToHome')}
        </Link>
        <div className="text-center mb-10">
          <h1 className="text-3xl sm:text-4xl font-bold tracking-tight">
            {t('demoTitle')}
          </h1>
          <p className="text-base-content/50 mt-3 max-w-xl mx-auto">
            {t('demoDesc')}
          </p>
        </div>
        <InteractiveRecoveryDemo />
      </div>
    </main>
  );
}
