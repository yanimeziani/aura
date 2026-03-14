import { NextResponse } from 'next/server';
import { supabaseAdmin } from '@/lib/supabase-admin';

export const runtime = 'nodejs';
export const maxDuration = 60;

const CRON_SECRET = process.env.CRON_SECRET;

export async function GET(req: Request) {
  const authHeader = req.headers.get('authorization');
  const bearer = authHeader?.startsWith('Bearer ') ? authHeader.slice(7) : null;
  if (!CRON_SECRET || !bearer || bearer !== CRON_SECRET) {
    return NextResponse.json({ error: 'Unauthorized' }, { status: 401 });
  }

  try {
    const { data: merchants } = await supabaseAdmin
      .from('merchants')
      .select('id, data_retention_days')
      .gt('data_retention_days', 0);

    if (!merchants?.length) {
      return NextResponse.json({ processed: 0, message: 'No merchants with retention policy' });
    }

    let totalDeleted = 0;

    for (const m of merchants) {
      const cutoffDate = new Date();
      cutoffDate.setDate(cutoffDate.getDate() - m.data_retention_days);
      const cutoffIso = cutoffDate.toISOString();

      const { data: oldDebtors } = await supabaseAdmin
        .from('debtors')
        .select('id')
        .eq('merchant_id', m.id)
        .lt('created_at', cutoffIso);

      if (!oldDebtors?.length) continue;

      const debtorIds = oldDebtors.map((d) => d.id);

      await supabaseAdmin.from('conversations').delete().in('debtor_id', debtorIds);
      await supabaseAdmin.from('payments').delete().in('debtor_id', debtorIds);
      await supabaseAdmin.from('recovery_actions').delete().in('debtor_id', debtorIds);
      const { error } = await supabaseAdmin.from('debtors').delete().in('id', debtorIds);

      if (!error) totalDeleted += debtorIds.length;
    }

    return NextResponse.json({ processed: merchants.length, deleted: totalDeleted });
  } catch (error) {
    console.error('[cron/data-retention]', error);
    return NextResponse.json({ error: 'Internal error' }, { status: 500 });
  }
}
