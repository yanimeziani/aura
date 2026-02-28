import { NextResponse } from 'next/server';
import { supabaseAdmin } from '@/lib/supabase-admin';
import { getMerchantId } from '@/lib/auth';
import * as Sentry from '@sentry/nextjs';

function toCsvRow(values: Array<string | number | null | undefined>): string {
  return values
    .map((value) => {
      const s = String(value ?? '');
      if (s.includes(',') || s.includes('"') || s.includes('\n')) {
        return `"${s.replace(/"/g, '""')}"`;
      }
      return s;
    })
    .join(',');
}

export async function GET(req: Request) {
  try {
    const merchantId = await getMerchantId();
    if (!merchantId) {
      return NextResponse.json({ error: 'Unauthorized' }, { status: 401 });
    }

    const { searchParams } = new URL(req.url);
    const idsParam = searchParams.get('ids');
    const ids = idsParam ? idsParam.split(',').map((s) => s.trim()).filter(Boolean) : null;

    let query = supabaseAdmin
      .from('debtors')
      .select('id,name,email,phone,total_debt,currency,status,days_overdue,last_contacted,created_at')
      .eq('merchant_id', merchantId)
      .order('created_at', { ascending: false });

    if (ids?.length) {
      query = query.in('id', ids);
    }

    const { data, error } = await query;

    if (error) {
      Sentry.captureException(error);
      return NextResponse.json({ error: error.message }, { status: 500 });
    }

    const header = [
      'id',
      'name',
      'email',
      'phone',
      'total_debt',
      'currency',
      'status',
      'days_overdue',
      'last_contacted',
      'created_at',
    ];

    const rows = (data ?? []).map((d) =>
      toCsvRow([
        d.id,
        d.name,
        d.email,
        d.phone,
        d.total_debt,
        d.currency,
        d.status,
        d.days_overdue,
        d.last_contacted,
        d.created_at,
      ])
    );

    const csv = [toCsvRow(header), ...rows].join('\n');

    return new NextResponse(csv, {
      status: 200,
      headers: {
        'Content-Type': 'text/csv; charset=utf-8',
        'Content-Disposition': `attachment; filename="dragun-recovery-export-${new Date().toISOString().slice(0, 10)}.csv"`,
        'Cache-Control': 'no-store',
      },
    });
  } catch (error) {
    Sentry.captureException(error);
    return NextResponse.json({ error: 'Export failed' }, { status: 500 });
  }
}
