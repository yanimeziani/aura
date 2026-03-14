import type { DebtorRow } from '@/components/dashboard/dashboard-types';

export type NextActionKey =
  | 'send_outreach'
  | 'follow_up'
  | 'wait_promise'
  | 'wait_contacted'
  | 'escalate'
  | 'none';

export interface NextAction {
  key: NextActionKey;
  label: string;
  priority: number; // higher = more urgent
}

const DAY_MS = 24 * 60 * 60 * 1000;

export function getNextAction(d: DebtorRow): NextAction {
  if (d.status === 'paid') return { key: 'none', label: 'Resolved', priority: 0 };

  const lastContacted = d.last_contacted ? new Date(d.last_contacted).getTime() : 0;
  const daysSinceContact = lastContacted ? Math.floor((Date.now() - lastContacted) / DAY_MS) : 999;

  if (d.status === 'pending' && !lastContacted) {
    return { key: 'send_outreach', label: 'Send initial outreach', priority: 80 };
  }

  if (d.status === 'pending' && daysSinceContact >= 7) {
    return { key: 'send_outreach', label: 'Send initial outreach', priority: 75 };
  }

  if (d.status === 'promise_to_pay') {
    if (daysSinceContact >= 3) return { key: 'follow_up', label: 'Follow up on promise', priority: 90 };
    return { key: 'wait_promise', label: 'Wait for promise date', priority: 20 };
  }

  if (d.status === 'contacted' && daysSinceContact >= 7) {
    return { key: 'follow_up', label: 'Send follow-up', priority: 85 };
  }

  if (d.status === 'no_answer' && daysSinceContact >= 5) {
    return { key: 'follow_up', label: 'Retry contact', priority: 70 };
  }

  if (d.status === 'contacted' && daysSinceContact < 2) {
    return { key: 'wait_contacted', label: 'Recently contacted', priority: 10 };
  }

  if (d.status === 'escalated') {
    return { key: 'none', label: 'Escalated', priority: 0 };
  }

  return { key: 'follow_up', label: 'Consider follow-up', priority: 50 };
}
