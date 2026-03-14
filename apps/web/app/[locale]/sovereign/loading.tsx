import { Terminal, Shield } from 'lucide-react';

export default function SovereignLoading() {
  return (
    <div className="min-h-screen bg-black text-white font-mono p-8 flex flex-col items-center justify-center space-y-6">
      <div className="relative">
        <Shield className="w-16 h-16 animate-pulse text-white/20" />
        <Terminal className="absolute inset-0 m-auto w-6 h-6 animate-bounce" />
      </div>
      
      <div className="space-y-2 text-center">
        <p className="text-[10px] font-bold uppercase tracking-[0.5em] animate-pulse">
          INITIALIZING_CERBERUS_RUNTIME
        </p>
        <div className="w-64 h-1 bg-white/10 overflow-hidden relative">
          <div className="absolute inset-0 bg-white animate-progress-indefinite" />
        </div>
        <p className="text-[9px] opacity-30 uppercase tracking-widest">
          Establishing secure handshake with sovereign-node-01
        </p>
      </div>
    </div>
  );
}
