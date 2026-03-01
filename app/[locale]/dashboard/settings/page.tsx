import { redirect } from '@/i18n/navigation';
import { getMerchantId } from '@/lib/auth';
import { supabaseAdmin } from '@/lib/supabase-admin';
import { getTranslations } from 'next-intl/server';
import { Link } from '@/i18n/navigation';
import { ArrowLeft } from 'lucide-react';
import SettingsPageForm from '@/components/dashboard/SettingsPageForm';

export default async function DashboardSettingsPage({
  params,
}: {
  params: Promise<{ locale: string }>;
}) {
  const { locale } = await params;
  const t = await getTranslations('Dashboard');
  const merchantId = await getMerchantId();

  if (!merchantId) {
    redirect({ href: '/login', locale });
  }

  const { data: merchant, error } = await supabaseAdmin
    .from('merchants')
    .select('name, strictness_level, settlement_floor, data_retention_days, currency_preference, phone')
    .eq('id', merchantId)
    .single();

  if (error || !merchant) {
    redirect({ href: '/dashboard', locale });
  }

  return (
    <div className="min-h-screen bg-base-100 py-6 px-4">
      <div className="app-shell max-w-2xl mx-auto">
        <Link
          href="/dashboard"
          className="inline-flex items-center gap-2 text-sm text-base-content/60 hover:text-base-content mb-6"
        >
          <ArrowLeft className="h-4 w-4" />
          {t('backToDashboard')}
        </Link>
        <h1 className="text-2xl font-bold mb-2">{t('agentParams')}</h1>
        <p className="text-sm text-base-content/60 mb-8">
          {t('settingsPageDescription')}
        </p>
        <SettingsPageForm
          merchant={{
            name: merchant.name,
            strictness_level: merchant.strictness_level ?? 5,
            settlement_floor: Number(merchant.settlement_floor) || 0.8,
            data_retention_days: merchant.data_retention_days,
            currency_preference: merchant.currency_preference,
            phone: merchant.phone,
          }}
        />
      </div>
    </div>
  );
}
