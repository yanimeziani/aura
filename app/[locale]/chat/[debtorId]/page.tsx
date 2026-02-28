import { redirect } from '@/i18n/navigation';
import { verifyDebtorToken } from '@/lib/debtor-token';
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

  return <ChatClient debtorId={debtorId} token={token!} />;
}
