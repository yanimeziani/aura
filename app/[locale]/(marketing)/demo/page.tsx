import type { Metadata } from 'next';
import { useTranslations } from 'next-intl';
import { Link } from '@/i18n/navigation';
import { ArrowLeft } from 'lucide-react';
import InteractiveRecoveryDemo from '@/components/InteractiveRecoveryDemo';

export const metadata: Metadata = {
  title: 'Live Demo | Dragun.app',
  description: 'Try the AI debt recovery agent in real time. See how Dragun negotiates with empathy and cites your contract.',
  openGraph: {
    title: 'Live Demo | Dragun.app',
    description: 'Try the AI debt recovery agent in real time.',
  },
};

export default function DemoPage() {
  const t = useTranslations('Home');

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
