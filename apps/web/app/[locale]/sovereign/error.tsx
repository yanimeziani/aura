'use client';

import { useEffect } from 'react';
import { Terminal, RefreshCcw, ShieldAlert } from 'lucide-react';

export default function SovereignError({
  error,
  reset,
}: {
  error: Error & { digest?: string };
  reset: () => void;
}) {
  useEffect(() => {
    console.error('Sovereign Dashboard Error:', error);
  }, [error]);

  return (
    <div className="min-h-screen bg-black text-red-500 font-mono p-8 flex flex-col items-center justify-center space-y-8 border-8 border-red-500/20">
      <div className="relative">
        <ShieldAlert className="w-24 h-24 animate-pulse" />
        <div className="absolute inset-0 bg-red-500/20 blur-2xl -z-10" />
      </div>

      <div className="text-center space-y-4 max-w-2xl">
        <h1 className="text-4xl font-black tracking-tighter uppercase leading-none">
          CRITICAL_SYSTEM_FAILURE
        </h1>
        <div className="bg-red-500/10 border-2 border-red-500 p-4 text-left">
          <p className="text-xs uppercase opacity-70 mb-2 underline decoration-red-500/50">Error Diagnostics</p>
          <p className="text-sm font-bold leading-relaxed break-words font-mono">
            {error.message || 'An unknown sovereign state error occurred.'}
          </p>
          {error.digest && (
            <p className="text-[10px] opacity-50 mt-4 uppercase">Digest: {error.digest}</p>
          )}
        </div>
      </div>

      <div className="flex gap-4">
        <button
          onClick={() => reset()}
          className="bg-red-500 text-black px-8 py-3 font-black uppercase tracking-tighter hover:bg-white transition-colors flex items-center gap-2"
        >
          <RefreshCcw className="w-4 h-4" /> REBOOT_SYSTEM
        </button>
        <button
          onClick={() => (window.location.href = '/')}
          className="border-2 border-red-500 text-red-500 px-8 py-3 font-black uppercase tracking-tighter hover:bg-red-500 hover:text-black transition-colors flex items-center gap-2"
        >
          TERMINATE_SESSION
        </button>
      </div>

      <div className="pt-12 flex items-center gap-4 text-[10px] opacity-30 uppercase font-bold tracking-[0.2em]">
        <span className="flex items-center gap-1">
          <Terminal className="w-3 h-3" /> SECURITY_BREACH_PROTOCOL
        </span>
        <span className="w-1 h-1 bg-red-500 rounded-full" />
        <span>RETRY_ATTEMPT_01</span>
      </div>
    </div>
  );
}
