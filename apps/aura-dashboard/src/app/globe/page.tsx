"use client";

import { useEffect, useState, Suspense } from "react";
import { useRouter } from "next/navigation";
import dynamic from "next/dynamic";
import { ArrowLeft, Activity, Globe, RefreshCw } from "lucide-react";
import { getStoredToken } from "@/lib/auth";
import { getGatewayUrl } from "@/lib/gateway";

// Dynamic import — Three.js can't SSR
const PlanetaryGlobe = dynamic(
  () => import("@/components/PlanetaryGlobe"),
  { ssr: false }
);

interface GlobeData {
  nodes: Array<{
    id: string;
    type: "sovereign" | "org" | "lead";
    label: string;
    country: string;
    tier: string;
    agents?: number;
  }>;
  connections: Array<{
    from: string;
    to: string;
    type: "mesh" | "outreach";
    strength: number;
  }>;
  meta?: {
    total_orgs: number;
    total_leads: number;
    sovereign: string | null;
  };
}

export default function GlobePage() {
  const router = useRouter();
  const [data, setData] = useState<GlobeData | null>(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState("");

  async function fetchGlobeData() {
    const token = getStoredToken();
    if (!token) {
      router.push("/login");
      return;
    }

    setLoading(true);
    setError("");

    try {
      const res = await fetch(`${getGatewayUrl()}/api/outreach/globe`, {
        headers: { Authorization: `Bearer ${token}` },
      });
      if (res.status === 401) {
        router.push("/login");
        return;
      }
      if (!res.ok) throw new Error(`HTTP ${res.status}`);
      const json = await res.json();
      setData(json);
    } catch {
      setError("Gateway unreachable — showing demo data");
      // Fallback demo data
      setData({
        nodes: [
          { id: "nexa-core", type: "sovereign", label: "Nexa Core", country: "CA", tier: "sovereign", agents: 3 },
          { id: "demo-uk", type: "org", label: "Demo Corp UK", country: "GB", tier: "registry_verified", agents: 2 },
          { id: "demo-de", type: "org", label: "Demo GmbH", country: "DE", tier: "domain_verified", agents: 1 },
          { id: "demo-jp", type: "lead", label: "Prospect Tokyo", country: "JP", tier: "prospect" },
          { id: "demo-br", type: "lead", label: "Prospect Sao Paulo", country: "BR", tier: "prospect" },
          { id: "demo-au", type: "lead", label: "Prospect Sydney", country: "AU", tier: "prospect" },
          { id: "demo-sg", type: "lead", label: "Prospect Singapore", country: "SG", tier: "prospect" },
          { id: "demo-in", type: "lead", label: "Prospect Mumbai", country: "IN", tier: "prospect" },
          { id: "demo-fr", type: "org", label: "Agence Paris", country: "FR", tier: "unverified" },
          { id: "demo-ng", type: "lead", label: "Prospect Lagos", country: "NG", tier: "prospect" },
          { id: "demo-us", type: "lead", label: "Prospect NYC", country: "US", tier: "prospect" },
          { id: "demo-mx", type: "lead", label: "Prospect CDMX", country: "MX", tier: "prospect" },
        ],
        connections: [
          { from: "nexa-core", to: "demo-uk", type: "mesh", strength: 0.75 },
          { from: "nexa-core", to: "demo-de", type: "mesh", strength: 0.5 },
          { from: "nexa-core", to: "demo-fr", type: "mesh", strength: 0.1 },
          { from: "nexa-core", to: "demo-jp", type: "outreach", strength: 0.2 },
          { from: "nexa-core", to: "demo-br", type: "outreach", strength: 0.2 },
          { from: "nexa-core", to: "demo-au", type: "outreach", strength: 0.2 },
          { from: "nexa-core", to: "demo-sg", type: "outreach", strength: 0.2 },
          { from: "nexa-core", to: "demo-in", type: "outreach", strength: 0.2 },
          { from: "nexa-core", to: "demo-ng", type: "outreach", strength: 0.2 },
          { from: "nexa-core", to: "demo-us", type: "outreach", strength: 0.2 },
          { from: "nexa-core", to: "demo-mx", type: "outreach", strength: 0.2 },
        ],
      });
    } finally {
      setLoading(false);
    }
  }

  useEffect(() => {
    fetchGlobeData();
  }, []);

  return (
    <div className="h-screen w-screen bg-black text-white font-mono flex flex-col overflow-hidden">
      {/* Top bar */}
      <div className="border-b-2 border-white/20 px-4 py-2 flex items-center justify-between shrink-0">
        <div className="flex items-center gap-4">
          <button
            onClick={() => router.push("/")}
            className="flex items-center gap-1.5 text-xs opacity-60 hover:opacity-100 transition-opacity"
          >
            <ArrowLeft className="w-3.5 h-3.5" />
            MISSION CONTROL
          </button>
          <div className="h-4 w-px bg-white/20" />
          <div className="flex items-center gap-2">
            <Globe className="w-4 h-4 text-terminal" />
            <h1 className="text-sm font-bold uppercase tracking-wider">
              Planetary Outreach
            </h1>
          </div>
        </div>
        <div className="flex items-center gap-4">
          {error && (
            <span className="text-warn text-[10px] uppercase">{error}</span>
          )}
          {data?.meta && (
            <div className="text-[10px] opacity-50 uppercase flex gap-4">
              <span>
                Orgs:{" "}
                <span className="text-terminal font-bold">
                  {data.meta.total_orgs}
                </span>
              </span>
              <span>
                Leads:{" "}
                <span className="text-orange-400 font-bold">
                  {data.meta.total_leads}
                </span>
              </span>
            </div>
          )}
          <button
            onClick={fetchGlobeData}
            className="p-1.5 border border-white/20 hover:bg-white/10 transition-colors"
            title="Refresh data"
          >
            <RefreshCw className={`w-3.5 h-3.5 ${loading ? "animate-spin" : ""}`} />
          </button>
        </div>
      </div>

      {/* Globe */}
      <div className="flex-1 relative">
        {loading && !data ? (
          <div className="absolute inset-0 flex items-center justify-center">
            <div className="text-center space-y-3">
              <Activity className="w-8 h-8 mx-auto animate-pulse text-terminal" />
              <p className="text-xs opacity-50 uppercase">
                Loading outreach data...
              </p>
            </div>
          </div>
        ) : data ? (
          <Suspense
            fallback={
              <div className="absolute inset-0 flex items-center justify-center">
                <Activity className="w-8 h-8 animate-pulse text-terminal" />
              </div>
            }
          >
            <PlanetaryGlobe data={data} />
          </Suspense>
        ) : null}
      </div>

      {/* Bottom bar */}
      <div className="border-t-2 border-white/20 px-4 py-1.5 flex justify-between text-[9px] opacity-30 uppercase tracking-wider shrink-0">
        <span>Real-time mesh topology // Org trust visualization</span>
        <span>Click nodes for details // Scroll to zoom // Drag to rotate</span>
      </div>
    </div>
  );
}
