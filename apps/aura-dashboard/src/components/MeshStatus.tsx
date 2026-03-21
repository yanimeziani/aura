"use client";

import { useState, useEffect } from "react";
import { Globe, Cpu, Cloud } from "lucide-react";
import { fetchProviders, fetchModels } from "@/lib/gateway";

interface Provider {
  id: string;
  enabled: boolean;
  mesh?: boolean;
}

interface Model {
  id: string;
  source: string;
  mesh?: boolean;
}

export default function MeshStatus() {
  const [providers, setProviders] = useState<Provider[]>([]);
  const [models, setModels] = useState<Model[]>([]);

  useEffect(() => {
    async function load() {
      try {
        const [prov, mod] = await Promise.all([fetchProviders(), fetchModels()]);
        setProviders(prov.providers || []);
        setModels(mod.data || []);
      } catch {
        // Gateway down — show empty state
      }
    }
    load();
    const id = setInterval(load, 60_000);
    return () => clearInterval(id);
  }, []);

  return (
    <div className="border-4 border-white p-0">
      <div className="bg-white text-black p-2 px-4 font-bold uppercase text-xs tracking-widest flex items-center gap-2">
        <Globe className="w-3.5 h-3.5" /> Mesh Status
      </div>
      <div className="p-6 space-y-5">
        {/* Providers */}
        <div>
          <h3 className="text-[10px] uppercase opacity-50 mb-3">Providers</h3>
          <div className="space-y-2">
            {providers.length === 0 && (
              <p className="text-xs opacity-30">No providers detected</p>
            )}
            {providers.map((p) => (
              <div
                key={p.id}
                className="flex items-center justify-between text-sm"
              >
                <div className="flex items-center gap-2">
                  {p.mesh ? (
                    <Cpu className="w-3.5 h-3.5 text-terminal" />
                  ) : (
                    <Cloud className="w-3.5 h-3.5 opacity-50" />
                  )}
                  <span className="font-bold uppercase">{p.id}</span>
                  {p.mesh && (
                    <span className="text-[9px] border border-terminal text-terminal px-1">
                      MESH
                    </span>
                  )}
                </div>
                <span
                  className={`text-xs font-bold ${p.enabled ? "text-terminal" : "text-danger"}`}
                >
                  {p.enabled ? "ONLINE" : "OFF"}
                </span>
              </div>
            ))}
          </div>
        </div>

        {/* Models */}
        <div>
          <h3 className="text-[10px] uppercase opacity-50 mb-3">
            Models ({models.length})
          </h3>
          <div className="max-h-32 overflow-y-auto space-y-1">
            {models.length === 0 && (
              <p className="text-xs opacity-30">No models available</p>
            )}
            {models.map((m, i) => (
              <div
                key={`${m.id}-${i}`}
                className="flex items-center justify-between text-xs"
              >
                <span className="truncate mr-2 font-mono">{m.id}</span>
                <span
                  className={`shrink-0 text-[9px] px-1 border ${
                    m.mesh
                      ? "border-terminal text-terminal"
                      : "border-white/30 text-white/50"
                  }`}
                >
                  {m.source}
                </span>
              </div>
            ))}
          </div>
        </div>

        <div className="border-t-2 border-white/10 pt-3 text-[10px] opacity-30 uppercase text-center">
          Mesh-first routing // Local models prioritized
        </div>
      </div>
    </div>
  );
}
