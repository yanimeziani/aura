import { NextResponse } from 'next/server';
import { getMerchantId } from '@/lib/auth';
import { supabaseAdmin } from '@/lib/supabase-admin';

export const runtime = 'nodejs';

/** GET: Merchant fetches conversation with a debtor (spectator / read-only). */
export async function GET(
  _request: Request,
  context: { params: Promise<{ debtorId: string }> },
) {
  const merchantId = await getMerchantId();
  if (!merchantId) {
    return NextResponse.json({ error: 'Unauthorized' }, { status: 401 });
  }

  const { debtorId } = await context.params;
  if (!debtorId) {
    return NextResponse.json({ error: 'Missing debtorId' }, { status: 400 });
  }

  const { data: debtor, error: debtorError } = await supabaseAdmin
    .from('debtors')
    .select('id, merchant_id')
    .eq('id', debtorId)
    .eq('merchant_id', merchantId)
    .single();

  if (debtorError || !debtor) {
    return NextResponse.json({ error: 'Debtor not found' }, { status: 404 });
  }

  const { data: messages, error } = await supabaseAdmin
    .from('conversations')
    .select('id, role, message, created_at')
    .eq('debtor_id', debtorId)
    .order('created_at', { ascending: true });

  if (error) {
    return NextResponse.json({ error: 'Failed to load conversation' }, { status: 500 });
  }

  return NextResponse.json({ messages: messages ?? [] });
}
