import { getTranslations } from 'next-intl/server';
import { getCommsChannelStatus } from '@/lib/comms/config';
import { MessageSquare } from 'lucide-react';

interface Props {
  locale: string;
}

/** Renders when no comms channel is configured, so merchants know to set email or SMS. */
export default async function CommsChannelsAlert({ locale }: Props) {
  const status = getCommsChannelStatus();
  if (status.email || status.sms) return null;

  const t = await getTranslations('Dashboard');
  return (
    <div className="alert shadow-warm border-warning/30 bg-warning/5 flex-col sm:flex-row items-stretch sm:items-center gap-3 text-left">
      <div className="flex gap-3 flex-1 min-w-0">
        <MessageSquare className="h-5 w-5 shrink-0 text-warning" />
        <div className="min-w-0">
          <p className="font-semibold">{t('commsChannelsNotConfigured')}</p>
          <p className="text-sm opacity-80">{t('commsChannelsHint')}</p>
        </div>
      </div>
      <a
        href={`/${locale}/integrations`}
        className="btn btn-ghost btn-sm min-h-[44px] min-w-[44px] sm:shrink-0 touch-manipulation"
      >
        {t('commsViewIntegrations')}
      </a>
    </div>
  );
}
