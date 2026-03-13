import { verifyDebtorToken } from '@/lib/debtor-token';
import PayClient from '@/components/debtor-portal/PayClient';
import { ShieldCheck } from 'lucide-react';
import { supabaseAdmin } from '@/lib/supabase-admin';
import { getRagSnippet, RAG_QUERIES } from '@/lib/rag';

export default async function PaymentPage({
  params,
  searchParams,
}: {
  params: Promise<{ debtorId: string }>;
  searchParams: Promise<{ token?: string }>;
}) {
  const { debtorId } = await params;
  const { token } = await searchParams;

  const verified = token ? verifyDebtorToken(token) : null;
  if (!verified || verified.debtorId !== debtorId) {
    return (
      <div className="min-h-screen bg-base-100 flex flex-col items-center justify-center p-10 gap-4">
        <ShieldCheck className="w-12 h-12 text-base-content/20" />
        <p className="text-base-content/60 font-semibold text-sm">This link has expired or is invalid.</p>
        <p className="text-xs text-base-content/40 max-w-sm text-center">
          Please use the link from your outreach email, or request a new one from the business.
        </p>
      </div>
    );
  }

  const { data: debtorRow } = await supabaseAdmin
    .from('debtors')
    .select('merchant_id')
    .eq('id', debtorId)
    .single();
  const contractSnippet = debtorRow?.merchant_id
    ? await getRagSnippet(debtorRow.merchant_id, RAG_QUERIES.payPage, 200)
    : '';

  const { data: debtorRowFull } = await supabaseAdmin
    .from('debtors')
    .select('id, merchant_id, name, currency, total_debt, merchant:merchants(name, settlement_floor)')
    .eq('id', debtorId)
    .single();

  const merchantRow = Array.isArray(debtorRowFull?.merchant)
    ? debtorRowFull?.merchant[0]
    : debtorRowFull?.merchant;
  const debtor = debtorRowFull && merchantRow
    ? {
        id: debtorRowFull.id,
        merchant_id: debtorRowFull.merchant_id,
        name: debtorRowFull.name,
        currency: debtorRowFull.currency,
        total_debt: debtorRowFull.total_debt,
        merchant: {
          name: merchantRow.name,
          settlement_floor: merchantRow.settlement_floor,
        },
      }
    : null;

  return (
    <PayClient
      debtorId={debtorId}
      token={token!}
      initialDebtor={debtor ?? undefined}
      contractSnippet={contractSnippet || undefined}
    />
  );
}
