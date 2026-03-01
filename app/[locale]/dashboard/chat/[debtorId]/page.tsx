import { redirect } from '@/i18n/navigation';
import { getMerchantId } from '@/lib/auth';
import { supabaseAdmin } from '@/lib/supabase-admin';
import { getTranslations } from 'next-intl/server';
import { getRecoveryScore } from '@/lib/recovery-score';
import type { DebtorRow } from '@/components/dashboard/dashboard-types';
import SpectatorChat from '@/components/dashboard/SpectatorChat';

export default async function DashboardChatSpectatorPage({
  params,
}: {
  params: Promise<{ debtorId: string; locale: string }>;
}) {
  const { debtorId, locale } = await params;
  const merchantId = await getMerchantId();

  if (!merchantId) {
    redirect({ href: '/login', locale });
  }

  const { data: debtor, error: debtorError } = await supabaseAdmin
    .from('debtors')
    .select('id, name, status, total_debt, currency, last_contacted, days_overdue')
    .eq('id', debtorId)
    .eq('merchant_id', merchantId)
    .single();

  if (debtorError || !debtor) {
    redirect({ href: '/dashboard', locale });
  }

  const d = debtor as NonNullable<typeof debtor>;

  const { data: messages } = await supabaseAdmin
    .from('conversations')
    .select('id, role, message, created_at')
    .eq('debtor_id', debtorId)
    .order('created_at', { ascending: true });

  const debtorRow: DebtorRow = {
    id: d.id,
    name: d.name,
    email: '',
    currency: d.currency ?? 'USD',
    total_debt: Number(d.total_debt),
    status: d.status ?? 'pending',
    last_contacted: d.last_contacted,
    days_overdue: d.days_overdue ?? null,
    created_at: '',
  };
  const recoveryScore = getRecoveryScore(debtorRow);

  const t = await getTranslations('Dashboard');

  return (
    <div className="min-h-screen bg-base-100 py-4 px-4">
      <div className="app-shell max-w-6xl mx-auto">
        <p className="text-sm text-base-content/50 mb-3">
          {t('spectatorDescription')}
        </p>
        <SpectatorChat
          debtorId={debtorId}
          debtorName={d.name}
          debtorSummary={{
            status: debtorRow.status,
            currency: debtorRow.currency,
            total_debt: debtorRow.total_debt,
            last_contacted: debtorRow.last_contacted,
            recoveryScore,
          }}
          initialMessages={(messages ?? []).map((m) => ({
            id: m.id,
            role: m.role,
            message: m.message,
            created_at: m.created_at,
          }))}
          locale={locale}
        />
      </div>
    </div>
  );
}
