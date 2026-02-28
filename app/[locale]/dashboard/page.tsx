import { supabaseAdmin } from '@/lib/supabase-admin';
import { createClient } from '@/lib/supabase/server';
import { uploadContract } from '../../actions/upload-contract';
import { updateMerchantSettings } from '../../actions/merchant-settings';
import { addDebtor } from '../../actions/add-debtor';
import { revalidatePath } from 'next/cache';
import { Link, redirect } from '@/i18n/navigation';
import { getTranslations } from 'next-intl/server';
import { getMerchantId } from '@/lib/auth';
import { createStripeConnectAccount } from '@/app/actions/stripe-connect';
import { createSubscriptionCheckout } from '@/app/actions/subscription';
import { checkPaywall } from '@/lib/paywall';
import { updateRecoveryStatus } from '@/app/actions/recovery-actions';
import {
  BadgeDollarSign,
  TrendingUp,
  MessageSquare,
  CheckCircle2,
  CreditCard,
  Users,
  ArrowRight,
  AlertCircle,
  ShieldCheck,
} from 'lucide-react';

import Logo from '@/components/Logo';
import DashboardTopNav from '@/components/dashboard/DashboardTopNav';
import MobileBottomBar from '@/components/dashboard/MobileBottomBar';
import PaywallBanner from '@/components/dashboard/PaywallBanner';
import PendingSubscription from '@/components/dashboard/PendingSubscription';
import StatsGrid from '@/components/dashboard/StatsGrid';
import { getRecoveryScore } from '@/components/dashboard/DebtorTable';
import DebtorTableWithBulk from '@/components/dashboard/DebtorTableWithBulk';
import DebtorFilters from '@/components/dashboard/DebtorFilters';
import TopDebtors from '@/components/dashboard/TopDebtors';
import SettingsPanel from '@/components/dashboard/SettingsPanel';
import KnowledgePanel from '@/components/dashboard/KnowledgePanel';
import RecoveryAnalytics from '@/components/dashboard/RecoveryAnalytics';
import type { DebtorRow, RecoveryActionRow } from '@/components/dashboard/dashboard-types';

export default async function DashboardPage({
  searchParams,
  params,
}: {
  searchParams: Promise<{ [key: string]: string | string[] | undefined }>;
  params: Promise<{ locale: string }>;
}) {
  const t = await getTranslations('Dashboard');
  const merchantId = await getMerchantId();
  const search = await searchParams;
  const { locale } = await params;
  const stripeSuccess = search.stripe_success === 'true';
  const forceDashboard = search.force_dashboard === 'true';

  const statusFilter = String(
    (Array.isArray(search.status) ? search.status[0] : search.status) || 'all',
  );
  const overdueFilter = String(
    (Array.isArray(search.overdue) ? search.overdue[0] : search.overdue) || 'all',
  );
  const amountFilter = String(
    (Array.isArray(search.amount) ? search.amount[0] : search.amount) || 'all',
  );
  const sortBy = String(
    (Array.isArray(search.sort) ? search.sort[0] : search.sort) || 'score_desc',
  );

  if (!merchantId) {
    redirect({ href: '/login', locale });
  }

  // --- Merchant resolution ---
  const initialResponse = await supabaseAdmin
    .from('merchants')
    .select('*')
    .eq('id', merchantId)
    .single();

  let merchant = initialResponse.data;

  if (initialResponse.error || !merchant) {
    const supabase = await createClient();
    const {
      data: { user },
    } = await supabase.auth.getUser();

    if (user) {
      const { data: existingByEmail } = await supabaseAdmin
        .from('merchants')
        .select('*')
        .eq('email', user.email!)
        .single();

      if (existingByEmail) {
        if (existingByEmail.id !== user.id) {
          const { data: updated } = await supabaseAdmin
            .from('merchants')
            .update({ id: user.id })
            .eq('email', user.email!)
            .select()
            .single();
          merchant = updated;
        } else {
          merchant = existingByEmail;
        }
      } else {
        const { data: newMerchant, error: createError } = await supabaseAdmin
          .from('merchants')
          .insert({
            id: user.id,
            email: user.email!,
            name:
              user.user_metadata?.full_name ||
              user.email?.split('@')[0] ||
              'New Merchant',
          })
          .select()
          .single();

        if (!createError && newMerchant) {
          merchant = newMerchant;
          await supabaseAdmin.from('debtors').insert({
            merchant_id: user.id,
            name: 'John Sample',
            email: 'john@example.com',
            total_debt: 1250.0,
            currency: 'USD',
            status: 'pending',
          });
        }
      }
    }
  }

  if (!merchant) {
    return (
      <div className="min-h-screen bg-base-100 flex items-center justify-center p-6">
        <div className="card bg-base-200/50 border border-base-300/50 shadow-elevated max-w-md w-full">
          <div className="card-body items-center text-center">
            <div className="flex h-14 w-14 items-center justify-center rounded-2xl bg-base-300/50 mb-2">
              <ShieldCheck className="h-7 w-7 text-base-content/40" />
            </div>
            <h1 className="card-title">{t('notFound')}</h1>
            <p className="text-sm text-base-content/50">{t('notFoundHint')}</p>
          </div>
        </div>
      </div>
    );
  }

  const onboardingDone = merchant.onboarding_completed ?? merchant.onboarding_complete;
  if (!onboardingDone && !forceDashboard) {
    redirect({ href: '/onboarding/profile', locale });
  }

  const hasStripeAccount = !!merchant.stripe_account_id;
  const isOnboardingComplete = !!merchant.stripe_onboarding_complete;
  const subscriptionSuccess = search.subscription_success === 'true';

  // --- Data fetching ---
  const paywall = await checkPaywall(merchantId!);

  const { data: contract } = await supabaseAdmin
    .from('contracts')
    .select('*')
    .eq('merchant_id', merchantId)
    .order('created_at', { ascending: false })
    .limit(1)
    .single();

  const { data: debtorsData } = await supabaseAdmin
    .from('debtors')
    .select('*')
    .eq('merchant_id', merchantId);
  const debtors: DebtorRow[] = (debtorsData ?? []) as DebtorRow[];

  const { data: recoveryActionsData } = await supabaseAdmin
    .from('recovery_actions')
    .select('*')
    .eq('merchant_id', merchantId)
    .order('created_at', { ascending: false })
    .limit(250);
  const recoveryActions: RecoveryActionRow[] =
    (recoveryActionsData ?? []) as RecoveryActionRow[];

  // --- Server actions ---
  async function handleUpload(formData: FormData) {
    'use server';
    await uploadContract(formData);
    revalidatePath('/dashboard');
  }

  async function handleAddDebtor(formData: FormData) {
    'use server';
    const mid = await getMerchantId();
    if (mid) {
      const pw = await checkPaywall(mid);
      if (!pw.allowed)
        throw new Error(`Debtor limit reached (${pw.limit}). Upgrade your plan.`);
    }
    await addDebtor(formData);
    revalidatePath('/[locale]/dashboard', 'page');
  }

  async function handleSubscribe(formData: FormData) {
    'use server';
    await createSubscriptionCheckout(formData);
  }

  async function handleUpdateSettings(formData: FormData) {
    'use server';
    const name = formData.get('name') as string;
    const strictness = parseInt(formData.get('strictness') as string);
    const settlement = parseFloat(formData.get('settlement') as string) / 100;
    const retention = parseInt(formData.get('data_retention_days') as string) || 0;
    await updateMerchantSettings({
      name,
      strictness_level: strictness,
      settlement_floor: settlement,
      data_retention_days: retention,
    });
    revalidatePath('/dashboard');
  }

  async function handleRecoveryAction(formData: FormData) {
    'use server';
    await updateRecoveryStatus(formData);
    revalidatePath('/[locale]/dashboard', 'page');
  }

  // --- Derived data ---
  const actionableDebtors = debtors.filter((d) => d.status !== 'paid');

  const filteredDebtors = actionableDebtors.filter((d) => {
    if (statusFilter !== 'all' && d.status !== statusFilter) return false;
    const overdue = d.days_overdue ?? 0;
    if (overdueFilter === '0_30' && (overdue < 0 || overdue > 30)) return false;
    if (overdueFilter === '31_60' && (overdue < 31 || overdue > 60)) return false;
    if (overdueFilter === '61_plus' && overdue < 61) return false;
    const amount = d.total_debt;
    if (amountFilter === 'lt_200' && amount >= 200) return false;
    if (amountFilter === '200_999' && (amount < 200 || amount > 999)) return false;
    if (amountFilter === '1000_plus' && amount < 1000) return false;
    return true;
  });

  const prioritizedDebtors = [...filteredDebtors].sort((a, b) => {
    if (sortBy === 'amount_desc') return b.total_debt - a.total_debt;
    if (sortBy === 'overdue_desc')
      return (b.days_overdue ?? 0) - (a.days_overdue ?? 0);
    if (sortBy === 'created_desc')
      return new Date(b.created_at).getTime() - new Date(a.created_at).getTime();
    return getRecoveryScore(b) - getRecoveryScore(a);
  });

  const actionTimelineByDebtor = recoveryActions.reduce<
    Record<string, RecoveryActionRow[]>
  >((acc, action) => {
    acc[action.debtor_id] = acc[action.debtor_id] || [];
    if (acc[action.debtor_id].length < 3) acc[action.debtor_id].push(action);
    return acc;
  }, {});

  const totalOutstanding = debtors.reduce(
    (acc, d) => acc + (d.status !== 'paid' ? d.total_debt : 0),
    0,
  );
  const totalRecovered = debtors.reduce(
    (acc, d) => acc + (d.status === 'paid' ? d.total_debt : 0),
    0,
  );
  const totalPortfolio = totalOutstanding + totalRecovered;
  const recoveryRate = totalPortfolio > 0
    ? Math.round((totalRecovered / totalPortfolio) * 100)
    : 0;

  const today = new Date();
  const isToday = (d: Date) =>
    d.getUTCFullYear() === today.getUTCFullYear() &&
    d.getUTCMonth() === today.getUTCMonth() &&
    d.getUTCDate() === today.getUTCDate();

  const contactedToday = debtors.filter((d) => {
    if (!d.last_contacted) return false;
    return isToday(new Date(d.last_contacted));
  }).length;
  const promises = debtors.filter((d) => d.status === 'promise_to_pay').length;

  const paidToday = recoveryActions.filter(
    (a) => a.status_after === 'paid' && isToday(new Date(a.created_at)),
  ).length;

  const statusCounts: Record<string, number> = {};
  for (const d of debtors) {
    statusCounts[d.status] = (statusCounts[d.status] || 0) + 1;
  }

  const recentActions = recoveryActions.slice(0, 10);

  const stats = [
    {
      label: t('outstanding'),
      value: `$${totalOutstanding.toLocaleString()}`,
      icon: BadgeDollarSign,
      trend: `${debtors.length} ${t('debtors').toLowerCase()}`,
      sub: t('momChange'),
    },
    {
      label: t('recovered'),
      value: `$${totalRecovered.toLocaleString()}`,
      icon: TrendingUp,
      trend: `${recoveryRate}% rate`,
      sub: t('vsAvg'),
    },
    {
      label: t('contactedToday'),
      value: String(contactedToday),
      icon: MessageSquare,
      trend: `${Math.round((contactedToday / Math.max(1, actionableDebtors.length)) * 100)}%`,
      sub: t('queueTouched'),
    },
    {
      label: t('promises'),
      value: String(promises),
      icon: CheckCircle2,
      trend: `min ${Math.round(merchant.settlement_floor * 100)}%`,
      sub: t('promiseToPay'),
    },
    {
      label: t('paidToday'),
      value: String(paidToday),
      icon: BadgeDollarSign,
      trend: t('today'),
      sub: t('resolvedToday'),
    },
    {
      label: t('planLabel'),
      value: paywall.plan.toUpperCase(),
      icon: CreditCard,
      trend: `${paywall.currentCount}/${paywall.limit}`,
      sub: t('debtorsUsed'),
    },
  ];

  return (
    <div className="min-h-screen bg-base-100 pb-24 md:pb-8">
      {/* Navigation */}
      <nav className="sticky top-0 z-30 border-b border-base-300/50 bg-base-100/90 backdrop-blur-xl">
        <div className="app-shell flex h-16 items-center justify-between">
          <Link href="/" className="flex items-center">
            <Logo className="h-8 w-auto" />
          </Link>
          <DashboardTopNav
            merchantName={merchant.name}
            hasStripeAccount={hasStripeAccount}
            isOnboardingComplete={isOnboardingComplete}
            locale={locale}
          />
        </div>
      </nav>

      <main className="app-shell space-y-6 py-6">
        {/* Page header */}
        <div className="flex flex-col gap-1">
          <h1 className="text-2xl font-bold tracking-tight sm:text-3xl">
            {t('title')}
          </h1>
          <p className="text-sm text-base-content/50">{t('subtitle')}</p>
        </div>

        {/* Alerts */}
        {stripeSuccess && isOnboardingComplete && (
          <div className="alert alert-success shadow-warm">
            <CheckCircle2 className="h-5 w-5 shrink-0" />
            <div>
              <p className="font-semibold">{t('gatewayActivated')}</p>
              <p className="text-sm opacity-80">
                {t('gatewayActivatedDesc')}
              </p>
            </div>
            <Link href="/dashboard" className="btn btn-ghost min-h-10">
              {t('dismiss')}
            </Link>
          </div>
        )}

        {subscriptionSuccess && (
          <div className="alert alert-success shadow-warm">
            <CreditCard className="h-5 w-5 shrink-0" />
            <div>
              <p className="font-semibold">{t('subscriptionActivated')}</p>
              <p className="text-sm opacity-80">
                {t('subscriptionActivatedDesc', { plan: paywall.plan, limit: String(paywall.limit) })}
              </p>
            </div>
            <Link href="/dashboard" className="btn btn-ghost min-h-10">
              {t('dismiss')}
            </Link>
          </div>
        )}

        <PendingSubscription subscribeAction={handleSubscribe} />

        <PaywallBanner
          currentCount={paywall.currentCount}
          limit={paywall.limit}
          plan={paywall.plan}
          subscribeAction={handleSubscribe}
        />

        {/* Stripe onboarding CTA */}
        {!isOnboardingComplete && (
          <div className="alert shadow-warm">
            <AlertCircle className="h-5 w-5 shrink-0" />
            <div>
              <p className="font-semibold">
                {hasStripeAccount
                  ? t('completeGatewaySetup')
                  : t('activateGateway')}
              </p>
              <p className="text-sm opacity-70">
                {hasStripeAccount
                  ? t('finishOnboardingDesc')
                  : t('connectStripeDesc')}
              </p>
            </div>
            <form action={createStripeConnectAccount}>
              <input type="hidden" name="locale" value={locale} />
              <button className="btn btn-primary gap-1 min-h-11">
                {hasStripeAccount ? t('resume') : t('setupStripe')}
                <ArrowRight className="h-3.5 w-3.5" />
              </button>
            </form>
          </div>
        )}

        {/* Stats */}
        <StatsGrid stats={stats} />

        {/* Main content: table + sidebar */}
        <div className="grid grid-cols-1 gap-6 lg:grid-cols-12">
          {/* Debtor list */}
          <section className="lg:col-span-8">
            <div className="card bg-base-200/50 border border-base-300/50 shadow-warm overflow-hidden">
              <div className="flex flex-col gap-3 border-b border-base-300/50 p-4 sm:flex-row sm:items-center sm:justify-between">
                <div className="flex items-center gap-3">
                  <div className="flex h-9 w-9 items-center justify-center rounded-lg bg-base-300/50">
                    <Users className="h-4 w-4 text-base-content/60" />
                  </div>
                  <div>
                    <h2 className="font-bold">{t('activeRecoveries')}</h2>
                    <p className="text-[11px] text-base-content/40">
                      {t('activeCount', { count: prioritizedDebtors.length })} ·{' '}
                      {t('resolvedCount', { count: debtors.filter((d) => d.status === 'paid').length })}
                    </p>
                  </div>
                </div>
                <DebtorFilters
                  statusFilter={statusFilter}
                  overdueFilter={overdueFilter}
                  amountFilter={amountFilter}
                  sortBy={sortBy}
                />
              </div>

              <DebtorTableWithBulk
                debtors={prioritizedDebtors}
                actionTimeline={actionTimelineByDebtor}
                handleRecoveryAction={handleRecoveryAction}
                getRecoveryScore={getRecoveryScore}
                t={(key: string, values?: Record<string, string | number>) => t(key, values)}
              />
            </div>
          </section>

          {/* Sidebar */}
          <aside className="space-y-6 lg:col-span-4">
            <RecoveryAnalytics
              recoveryRate={recoveryRate}
              totalPortfolio={totalPortfolio}
              totalRecovered={totalRecovered}
              statusCounts={statusCounts}
              recentActions={recentActions}
              debtorNames={Object.fromEntries(debtors.map((d) => [d.id, d.name]))}
              t={(key: string, values?: Record<string, string | number>) => t(key, values)}
            />
            <TopDebtors debtors={prioritizedDebtors} t={(key: string, values?: Record<string, string | number>) => t(key, values)} />
            <SettingsPanel
              merchant={merchant}
              handleUpdateSettings={handleUpdateSettings}
              t={(key: string) => t(key)}
            />
            <KnowledgePanel
              contract={contract}
              handleUpload={handleUpload}
              t={(key: string) => t(key)}
            />
          </aside>
        </div>
      </main>

      <MobileBottomBar addDebtorAction={handleAddDebtor} />
    </div>
  );
}
