'use client';

import { Link } from '@/i18n/navigation';
import { useTranslations } from 'next-intl';
import { ArrowLeft, MessageCircle } from 'lucide-react';
import Logo from '@/components/Logo';

export default function NotFound() {
  const t = useTranslations('NotFound');

  return (
    <div className="min-h-screen bg-base-100 flex items-center justify-center p-6">
      <div className="text-center max-w-md space-y-6">
        <Logo className="h-8 w-auto mx-auto" />
        <div className="space-y-2">
          <p className="text-6xl font-bold tracking-tight text-base-content/20">404</p>
          <h1 className="text-xl font-bold">{t('title')}</h1>
          <p className="text-sm text-base-content/50">
            {t('description')}
          </p>
        </div>
        <div className="flex flex-col sm:flex-row gap-3 justify-center">
          <Link href="/" className="btn btn-primary gap-2">
            <ArrowLeft className="h-4 w-4" />
            {t('backToHome')}
          </Link>
          <Link href="/contact" className="btn btn-ghost border border-base-300 gap-2">
            <MessageCircle className="h-4 w-4" />
            {t('contactSupport')}
          </Link>
        </div>
      </div>
    </div>
  );
}
