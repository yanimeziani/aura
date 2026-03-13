'use client';

import { useEffect } from 'react';
import * as Sentry from '@sentry/nextjs';
import { AlertCircle, RotateCcw } from 'lucide-react';

export default function DashboardError({
  error,
  reset,
}: {
  error: Error & { digest?: string };
  reset: () => void;
}) {
  useEffect(() => {
    Sentry.captureException(error);
  }, [error]);

  return (
    <div className="min-h-screen bg-base-100 flex items-center justify-center p-6">
      <div className="card bg-base-200/50 border border-base-300/50 shadow-elevated max-w-md w-full">
        <div className="card-body items-center text-center gap-4">
          <div className="flex h-14 w-14 items-center justify-center rounded-2xl bg-error/10">
            <AlertCircle className="h-7 w-7 text-error" />
          </div>
          <h1 className="text-xl font-bold">Something went wrong</h1>
          <p className="text-sm text-base-content/50">
            An unexpected error occurred loading the dashboard. The error has been reported automatically.
          </p>
          {error.digest && (
            <code className="text-xs text-base-content/30 bg-base-300/30 px-3 py-1 rounded-full">
              {error.digest}
            </code>
          )}
          <button onClick={reset} className="btn btn-primary gap-2 mt-2">
            <RotateCcw className="h-4 w-4" />
            Try again
          </button>
        </div>
      </div>
    </div>
  );
}
