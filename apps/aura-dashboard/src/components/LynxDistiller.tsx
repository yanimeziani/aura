"use client";

import { useState } from "react";
import { Zap, Globe, Loader2, ArrowRight, Sparkles } from "lucide-react";
import { fetchDistill } from "@/lib/gateway";

export default function LynxDistiller() {
  const [url, setUrl] = useState("");
  const [result, setResult] = useState<string | null>(null);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);

  const handleDistill = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!url) return;
    setLoading(true);
    setError(null);
    setResult(null);
    try {
      const data = await fetchDistill(url);
      if (data.error) {
        setError(data.error);
      } else if (data.distilled) {
        setResult(data.distilled);
      }
    } catch (err) {
      setError("Failed to connect to Nexa Gateway");
    } finally {
      setLoading(false);
    }
  };

  return (
    <div className="border-4 border-white p-0 bg-black text-white">
      <div className="bg-white text-black p-2 px-4 font-bold uppercase text-xs tracking-widest flex items-center justify-between">
        <span className="flex items-center gap-2">
          <Zap className="w-3.5 h-3.5 fill-current" /> Lynx Distiller
        </span>
        <span className="text-[10px] font-mono opacity-50">
          ZIG-CORE / BYTEDANCE-INSPIRED
        </span>
      </div>
      
      <div className="p-6 space-y-6">
        <form onSubmit={handleDistill} className="relative group">
          <div className="absolute -inset-0.5 bg-gradient-to-r from-blue-500 to-purple-600 rounded opacity-20 group-hover:opacity-40 transition duration-500 blur"></div>
          <div className="relative flex items-center bg-black border border-white/20 rounded overflow-hidden">
            <div className="pl-4 text-white/40">
              <Globe className="w-4 h-4" />
            </div>
            <input
              type="text"
              value={url}
              onChange={(e) => setUrl(e.target.value)}
              placeholder="http://bytedance.com/blog"
              className="w-full bg-transparent border-none focus:ring-0 text-sm py-3 px-4 placeholder:opacity-30 outline-none"
            />
            <button
              disabled={loading || !url}
              className="bg-white text-black hover:bg-white/90 disabled:opacity-50 px-6 py-3 transition-all flex items-center gap-2 font-bold uppercase text-[10px] tracking-widest border-l border-white/20"
            >
              {loading ? <Loader2 className="w-3.5 h-3.5 animate-spin" /> : <ArrowRight className="w-3.5 h-3.5" />}
              Distill
            </button>
          </div>
        </form>

        {error && (
          <div className="p-4 bg-red-900/20 border border-red-500/50 text-red-200 text-xs font-mono rounded">
            ERROR: {error}
          </div>
        )}

        {result && (
          <div className="space-y-4 animate-in fade-in slide-in-from-top-4 duration-700">
            <div className="flex items-center gap-2 text-[10px] font-bold uppercase tracking-widest opacity-50">
              <Sparkles className="w-3 h-3 text-blue-400" /> Distilled Essence
            </div>
            <div className="p-5 bg-white/5 border border-white/10 rounded leading-relaxed text-sm font-medium text-white/90 whitespace-pre-wrap selection:bg-blue-500/30">
              {result}
            </div>
            <div className="flex justify-end gap-3 text-[9px] font-mono opacity-30 uppercase">
              <span>Zig 0.15.2</span>
              <span>//</span>
              <span>Distilled-Qwen-R1</span>
              <span>//</span>
              <span>{new Date().toISOString().split('T')[0]}</span>
            </div>
          </div>
        )}

        {!result && !loading && !error && (
          <div className="py-12 flex flex-col items-center justify-center opacity-20 space-y-4">
            <Zap className="w-12 h-12 stroke-[1]" />
            <p className="text-[10px] font-bold uppercase tracking-[0.2em] text-center max-w-[200px]">
              Input a URL to extract the high-performance essence via Zig
            </p>
          </div>
        )}
      </div>
    </div>
  );
}
