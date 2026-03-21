"use client";

import { useState, useEffect } from "react";
import { Globe } from "lucide-react";
import { fetchRegionClusters } from "@/lib/gateway";

interface Cluster {
  country: string;
  locale: string;
  visits: number;
}

const COUNTRY_NAMES: Record<string, string> = {
  CA: "Canada",
  US: "United States",
  AU: "Australia",
  DZ: "Algeria",
  XX: "Unknown",
};

export default function RegionClusters() {
  const [clusters, setClusters] = useState<Cluster[]>([]);
  const [lastFetch, setLastFetch] = useState("");

  useEffect(() => {
    async function load() {
      try {
        const data = await fetchRegionClusters();
        setClusters(data.clusters || []);
        setLastFetch(
          new Date().toLocaleTimeString("en-US", { hour12: false })
        );
      } catch {
        setClusters([]);
      }
    }
    load();
    const id = setInterval(load, 60_000);
    return () => clearInterval(id);
  }, []);

  const total = clusters.reduce((s, c) => s + c.visits, 0);

  return (
    <div className="border-4 border-white p-0">
      <div className="bg-white text-black p-2 px-4 font-bold uppercase text-xs tracking-widest flex items-center justify-between">
        <span className="flex items-center gap-2">
          <Globe className="w-3.5 h-3.5" /> Region Clusters
        </span>
        <span className="text-[10px] font-mono">
          {total} visits
        </span>
      </div>
      <div className="p-4 space-y-2">
        {clusters.length === 0 ? (
          <div className="text-[10px] opacity-50 uppercase text-center py-4">
            No landing telemetry yet
          </div>
        ) : (
          clusters.slice(0, 10).map((c) => (
            <div
              key={`${c.country}-${c.locale}`}
              className="flex items-center justify-between py-1.5 border-b border-white/5 last:border-0"
            >
              <div className="flex items-center gap-2.5">
                <span className="text-xs font-bold uppercase w-6">
                  {c.country}
                </span>
                <span className="text-[10px] opacity-70">
                  {COUNTRY_NAMES[c.country] ?? c.country}
                </span>
                <span className="text-[10px] opacity-50">{c.locale}</span>
              </div>
              <span className="text-terminal text-[10px] font-mono tabular-nums">
                {c.visits}
              </span>
            </div>
          ))
        )}
        <div className="pt-2 text-[9px] opacity-20 uppercase text-center tabular-nums">
          NEXA MESH // LANDING VISITS BY CLUSTER // {lastFetch || "..."}
        </div>
      </div>
    </div>
  );
}
