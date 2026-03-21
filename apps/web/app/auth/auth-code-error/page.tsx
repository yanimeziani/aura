import Link from 'next/link';
import { AlertCircle } from 'lucide-react';
import Logo from '@/components/Logo';

export default function AuthCodeErrorPage() {
  return (
    <div className="min-h-screen flex items-center justify-center bg-base-100 px-4 relative">
      <div className="absolute inset-0 -z-10 overflow-hidden pointer-events-none">
        <div className="absolute top-[-10%] left-[-10%] w-[60%] h-[60%] bg-primary/5 blur-[120px] rounded-full" />
        <div className="absolute bottom-[-10%] right-[-10%] w-[50%] h-[50%] bg-secondary/10 blur-[120px] rounded-full" />
      </div>

      <div className="w-full max-w-[400px] z-10">
        <div className="text-center mb-10">
          <div className="mb-6 inline-flex items-center justify-center">
            <Logo className="h-8 w-auto" />
          </div>
        </div>

        <div className="card bg-base-200/50 border border-base-300/50 shadow-elevated">
          <div className="card-body p-8 items-center text-center gap-4">
            <div className="flex h-14 w-14 items-center justify-center rounded-2xl bg-error/10">
              <AlertCircle className="h-7 w-7 text-error" />
            </div>
            <h1 className="text-xl font-semibold tracking-tight text-base-content">
              Sign-in link invalid or expired
            </h1>
            <p className="text-base-content/60 text-sm">
              The sign-in link may have been used already or has expired. Please try signing in again from the login page.
            </p>
            <Link href="/en/login" className="btn btn-primary mt-2">
              Back to sign in
            </Link>
          </div>
        </div>
      </div>
    </div>
  );
}
