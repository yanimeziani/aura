import { supabaseAdmin } from './supabase-admin';

export type PlanTier = 'free' | 'starter' | 'growth' | 'scale';

const PLAN_LIMITS: Record<PlanTier, number> = {
  free: 3,
  starter: 50,
  growth: 250,
  scale: 1000,
};

export function getDebtorLimit(plan: PlanTier): number {
  return PLAN_LIMITS[plan] ?? 3;
}

export function isPlanActive(merchant: { plan?: string; plan_active_until?: string | null }): boolean {
  if (!merchant.plan || merchant.plan === 'free') return true;
  if (!merchant.plan_active_until) return false;
  return new Date(merchant.plan_active_until) > new Date();
}

export function getEffectivePlan(merchant: { plan?: string; plan_active_until?: string | null }): PlanTier {
  const plan = (merchant.plan ?? 'free') as PlanTier;
  if (plan === 'free') return 'free';
  if (!isPlanActive(merchant)) return 'free';
  return plan;
}

export async function checkPaywall(merchantId: string): Promise<{
  allowed: boolean;
  currentCount: number;
  limit: number;
  plan: PlanTier;
}> {
  const { data: merchant } = await supabaseAdmin
    .from('merchants')
    .select('plan, plan_active_until')
    .eq('id', merchantId)
    .single();

  const plan = getEffectivePlan(merchant ?? {});
  const limit = getDebtorLimit(plan);

  const { count } = await supabaseAdmin
    .from('debtors')
    .select('id', { count: 'exact', head: true })
    .eq('merchant_id', merchantId)
    .neq('status', 'paid');

  const currentCount = count ?? 0;

  return {
    allowed: currentCount < limit,
    currentCount,
    limit,
    plan,
  };
}
