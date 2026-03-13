/**
 * Outreach etiquette: algorithmic guardrails so businesses respect debtors’ complex lives.
 * Controlled by OUTREACH_ETIQUETTE_LEVEL (env). Ensures a minimum of respect and spacing
 * regardless of merchant, so debtors aren’t bombarded and businesses keep a baseline of etiquette.
 */

import { supabaseAdmin } from '@/lib/supabase-admin';

/** Action types that count as “outreach” for spacing and weekly cap. */
const OUTREACH_ACTION_TYPES = [
  'sms_initial',
  'sms_follow_up',
  'sms_reminder',
  'email_outreach',
  'email_follow_up',
] as const;

export type EtiquetteLevel = 0 | 1 | 2 | 3;

export interface EtiquetteRules {
  /** Min hours between any two outreaches to the same debtor. */
  minHoursBetweenAny: number;
  /** Max outreach actions (any channel) per debtor per rolling 7 days. */
  maxPerWeek: number;
  /** Start of allowed send window (hour UTC, 0–23). */
  windowStartHourUtc: number;
  /** End of allowed send window (hour UTC, 0–23). */
  windowEndHourUtc: number;
  /** If true, no SMS on Saturday or Sunday (UTC). */
  noSmsWeekend: boolean;
  /** Human-readable level name for messages. */
  label: string;
}

const RULES_BY_LEVEL: Record<EtiquetteLevel, EtiquetteRules> = {
  0: {
    minHoursBetweenAny: 0,
    maxPerWeek: 99,
    windowStartHourUtc: 0,
    windowEndHourUtc: 23,
    noSmsWeekend: false,
    label: 'minimal',
  },
  1: {
    minHoursBetweenAny: 24,
    maxPerWeek: 5,
    windowStartHourUtc: 7,
    windowEndHourUtc: 21,
    noSmsWeekend: false,
    label: 'moderate',
  },
  2: {
    minHoursBetweenAny: 48,
    maxPerWeek: 3,
    windowStartHourUtc: 8,
    windowEndHourUtc: 20,
    noSmsWeekend: true, // no SMS on Sunday only; we'll do no Sat/Sun for simplicity
    label: 'strict',
  },
  3: {
    minHoursBetweenAny: 72,
    maxPerWeek: 2,
    windowStartHourUtc: 9,
    windowEndHourUtc: 19,
    noSmsWeekend: true,
    label: 'maximum',
  },
};

/** Parse OUTREACH_ETIQUETTE_LEVEL: 0|1|2|3 or minimal|moderate|strict|maximum. Default 0. */
export function getEtiquetteLevel(): EtiquetteLevel {
  const raw = (process.env.OUTREACH_ETIQUETTE_LEVEL ?? '0').toString().trim().toLowerCase();
  const num = parseInt(raw, 10);
  if (Number.isInteger(num) && num >= 0 && num <= 3) return num as EtiquetteLevel;
  const map: Record<string, EtiquetteLevel> = {
    minimal: 0,
    moderate: 1,
    strict: 2,
    maximum: 3,
  };
  return map[raw] ?? 0;
}

export function getEtiquetteRules(level?: EtiquetteLevel): EtiquetteRules {
  const l = level ?? getEtiquetteLevel();
  return RULES_BY_LEVEL[l];
}

export interface EtiquetteCheckResult {
  allowed: boolean;
  reason?: string;
}

/**
 * Returns whether sending this channel to this debtor is allowed under the current
 * etiquette level. Use before send-sms and send-outreach.
 */
export async function checkOutreachEtiquette(
  debtorId: string,
  channel: 'sms' | 'email',
): Promise<EtiquetteCheckResult> {
  const level = getEtiquetteLevel();
  const rules = getEtiquetteRules(level);

  if (level === 0) {
    return { allowed: true };
  }

  const now = new Date();
  const weekAgo = new Date(now.getTime() - 7 * 24 * 60 * 60 * 1000);

  const { data: recent, error } = await supabaseAdmin
    .from('recovery_actions')
    .select('action_type, created_at')
    .eq('debtor_id', debtorId)
    .in('action_type', [...OUTREACH_ACTION_TYPES])
    .gte('created_at', weekAgo.toISOString())
    .order('created_at', { ascending: false });

  if (error) {
    return { allowed: true }; // fail open so we don't block on DB errors
  }

  const actions = recent ?? [];

  // 1) Max per week
  if (actions.length >= rules.maxPerWeek) {
    return {
      allowed: false,
      reason: `Outreach limit reached for this debtor (max ${rules.maxPerWeek} per week). Etiquette level: ${rules.label}.`,
    };
  }

  // 2) Min hours since last outreach (any channel)
  if (rules.minHoursBetweenAny > 0 && actions.length > 0) {
    const lastAt = new Date(actions[0].created_at);
    const hoursSince = (now.getTime() - lastAt.getTime()) / (1000 * 60 * 60);
    if (hoursSince < rules.minHoursBetweenAny) {
      const nextAt = new Date(lastAt.getTime() + rules.minHoursBetweenAny * 60 * 60 * 1000);
      return {
        allowed: false,
        reason: `Please wait until ${nextAt.toLocaleString()} before the next contact. Minimum spacing: ${rules.minHoursBetweenAny}h (etiquette: ${rules.label}).`,
      };
    }
  }

  // 3) Send window (UTC)
  const hourUtc = now.getUTCHours();
  if (hourUtc < rules.windowStartHourUtc || hourUtc > rules.windowEndHourUtc) {
    return {
      allowed: false,
      reason: `Outreach is only allowed between ${rules.windowStartHourUtc}:00 and ${rules.windowEndHourUtc}:00 UTC (etiquette: ${rules.label}).`,
    };
  }

  // 4) No SMS on weekend (Sat/Sun UTC)
  if (channel === 'sms' && rules.noSmsWeekend) {
    const dayUtc = now.getUTCDay(); // 0 = Sun, 6 = Sat
    if (dayUtc === 0 || dayUtc === 6) {
      return {
        allowed: false,
        reason: `SMS is not sent on weekends (etiquette: ${rules.label}). Please try on a weekday.`,
      };
    }
  }

  return { allowed: true };
}
