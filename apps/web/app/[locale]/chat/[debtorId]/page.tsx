import { verifyDebtorToken } from '@/lib/debtor-token';
import { supabaseAdmin } from '@/lib/supabase-admin';
import ChatClient from '@/components/debtor-portal/ChatClient';
import { ShieldCheck } from 'lucide-react';

export default async function ChatPage({
  params,
  searchParams,
}: {
  params: Promise<{ debtorId: string; locale: string }>;
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

  // Fetch debtor + merchant server-side (bypasses RLS via service role key)
  const { data: debtorRow } = await supabaseAdmin
    .from('debtors')
    .select('id, name, currency, total_debt, merchant:merchants(name, strictness_level)')
    .eq('id', debtorId)
    .single();

  const merchantRow = Array.isArray(debtorRow?.merchant)
    ? debtorRow?.merchant[0]
    : debtorRow?.merchant;
  const debtor = debtorRow && merchantRow
    ? {
        id: debtorRow.id,
        name: debtorRow.name,
        currency: debtorRow.currency,
        total_debt: debtorRow.total_debt,
        merchant: {
          name: merchantRow.name,
          strictness_level: merchantRow.strictness_level,
        },
      }
    : null;

  // Fetch existing conversation history server-side
  const { data: conversations } = await supabaseAdmin
    .from('conversations')
    .select('role, message')
    .eq('debtor_id', debtorId)
    .order('created_at', { ascending: true });

  return (
    <ChatClient
      debtorId={debtorId}
      token={token!}
      initialDebtor={debtor ?? undefined}
      initialConversations={conversations ?? undefined}
    />
  );
}
