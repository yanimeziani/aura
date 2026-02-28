import { verifyDebtorToken } from '@/lib/debtor-token';
import PayClient from '@/components/debtor-portal/PayClient';
import { ShieldCheck } from 'lucide-react';

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

  return <PayClient debtorId={debtorId} token={token!} />;
}
