import { NextResponse } from 'next/server';
import { supabaseAdmin } from '@/lib/supabase-admin';
import { sendFollowUpEmail } from '@/lib/outreach';

export const runtime = 'nodejs';
export const maxDuration = 120;

const CRON_SECRET = process.env.CRON_SECRET;
const FOLLOW_UP_DAYS = 7;

export async function GET(req: Request) {
  const authHeader = req.headers.get('authorization');
  const bearer = authHeader?.startsWith('Bearer ') ? authHeader.slice(7) : null;
  if (!CRON_SECRET || bearer !== CRON_SECRET) {
    return NextResponse.json({ error: 'Unauthorized' }, { status: 401 });
  }

  try {
    const cutoff = new Date();
    cutoff.setDate(cutoff.getDate() - FOLLOW_UP_DAYS);
    const cutoffIso = cutoff.toISOString();

    const { data: debtors } = await supabaseAdmin
      .from('debtors')
      .select('id')
      .in('status', ['pending', 'contacted', 'promise_to_pay'])
      .or(`last_contacted.is.null,last_contacted.lt.${cutoffIso}`)
      .limit(50);

    if (!debtors?.length) {
      return NextResponse.json({ processed: 0, message: 'No debtors due for follow-up' });
    }

    let sent = 0;
    for (const d of debtors) {
      const res = await sendFollowUpEmail(d.id);
      if (res.success) sent++;
    }

    return NextResponse.json({ processed: debtors.length, sent });
  } catch (error) {
    console.error('[cron/scheduled-follow-up]', error);
    return NextResponse.json({ error: 'Internal error' }, { status: 500 });
  }
}
