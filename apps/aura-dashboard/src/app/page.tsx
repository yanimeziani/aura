"use client";

import { useEffect, useState, useCallback } from "react";
import { useRouter } from "next/navigation";
import { Activity, LogOut } from "lucide-react";
import { getStoredToken, clearToken } from "@/lib/auth";
import { fetchCatchUp, getGatewayLabel } from "@/lib/gateway";
import SystemHealth from "@/components/SystemHealth";
import MeshStatus from "@/components/MeshStatus";
import AgentTerminal from "@/components/AgentTerminal";
import QuickActions from "@/components/QuickActions";
import RegionClusters from "@/components/RegionClusters";
import LynxDistiller from "@/components/LynxDistiller";

export default function DashboardPage() {
  const router = useRouter();
  const [token, setToken] = useState<string | null>(null);
  const [authed, setAuthed] = useState(false);
  const [time, setTime] = useState("");
  const [reconnectLogs, setReconnectLogs] = useState<Record<string, string[]> | null>(null);
  const [gatewayLabel, setGatewayLabel] = useState("resolving");

  useEffect(() => {
    const stored = getStoredToken();
    if (!stored) {
      router.replace("/login");
      return;
    }
    setToken(stored);
    setAuthed(true);
  }, [router]);

  useEffect(() => {
    const tick = () =>
      setTime(
        new Date().toLocaleTimeString("en-US", {
          hour12: false,
          hour: "2-digit",
          minute: "2-digit",
          second: "2-digit",
        })
      );
    tick();
    const id = setInterval(tick, 1000);
    return () => clearInterval(id);
  }, []);

  useEffect(() => {
    setGatewayLabel(getGatewayLabel());
  }, []);

  // When phone/tab returns: stream back from VPS (process kept running there)
  const onVisibilityChange = useCallback(() => {
    if (typeof document === "undefined" || document.visibilityState !== "visible") return;
    const t = getStoredToken();
    if (!t) return;
    fetchCatchUp(t, "aura", 100).then(({ logs_tail }) => {
      if (logs_tail && Object.keys(logs_tail).length > 0) setReconnectLogs(logs_tail);
    });
  }, []);
  useEffect(() => {
    document.addEventListener("visibilitychange", onVisibilityChange);
    return () => document.removeEventListener("visibilitychange", onVisibilityChange);
  }, [onVisibilityChange]);

  function handleLogout() {
    clearToken();
    router.push("/login");
  }

  if (!authed) {
    return (
      <div className="min-h-screen bg-black text-white font-mono flex items-center justify-center">
        <div className="text-center space-y-2">
          <Activity className="w-8 h-8 mx-auto animate-pulse text-terminal" />
          <p className="text-sm opacity-50 uppercase">
            Connecting to mesh...
          </p>
        </div>
      </div>
    );
  }

  return (
    <div className="min-h-screen bg-black text-white font-mono p-4 md:p-6 space-y-6 selection:bg-white selection:text-black">
      {/* HEADER */}
      <header className="border-4 border-white p-4 md:p-6 flex flex-col md:flex-row justify-between items-start md:items-center gap-4">
        <div>
          <h1 className="text-3xl md:text-4xl font-black tracking-tighter uppercase leading-none">
            NEXA // MISSION CONTROL
          </h1>
          <p className="text-xs opacity-50 mt-1">
            v0.1.0 // SOVEREIGN_MESH // OPERATOR_DASHBOARD
          </p>
        </div>
        <div className="flex items-center gap-6">
          <div className="flex flex-col items-end">
            <span className="text-[10px] uppercase opacity-50">Local Time</span>
            <span className="text-sm tabular-nums">{time}</span>
          </div>
          <div className="flex flex-col items-end text-terminal">
            <span className="text-[10px] uppercase opacity-50">System</span>
            <span className="flex items-center gap-1.5 text-sm">
              <Activity className="w-3.5 h-3.5 animate-pulse" />
              ONLINE
            </span>
          </div>
          <button
            onClick={handleLogout}
            className="border-2 border-white/30 p-2 hover:bg-white hover:text-black transition-all"
            title="Logout"
          >
            <LogOut className="w-4 h-4" />
          </button>
        </div>
      </header>

      {/* MAIN GRID */}
      <div className="grid grid-cols-1 md:grid-cols-12 gap-6">
        {/* LEFT: System Health */}
        <div className="md:col-span-6">
          <SystemHealth />
        </div>

        {/* RIGHT: Mesh Status */}
        <div className="md:col-span-6">
          <MeshStatus />
        </div>
      </div>

      {/* AGENT TERMINAL — full width; stream-back from VPS when phone returns */}
      <AgentTerminal
        token={token}
        reconnectLogs={reconnectLogs}
        onReconnectApplied={() => setReconnectLogs(null)}
      />

      {/* BOTTOM GRID */}
      <div className="grid grid-cols-1 md:grid-cols-12 gap-6">
        <div className="md:col-span-4">
          <QuickActions token={token} />
        </div>
        <div className="md:col-span-4">
          <RegionClusters />
        </div>
        <div className="md:col-span-4">
          <LynxDistiller />
        </div>
      </div>

      {/* FOOTER */}
      <footer className="border-4 border-white bg-white text-black p-2 px-4 md:px-6 flex flex-col md:flex-row justify-between items-center text-[10px] font-bold uppercase tracking-widest gap-2 flex-wrap">
        <div className="flex gap-4 md:gap-6">
          <span>GATEWAY: {gatewayLabel.toUpperCase()}</span>
          <span>MODE: SOVEREIGN</span>
        </div>
        <div className="flex items-center gap-4">
          <span>ENCRYPTION: VAULT_AES // MESH_FIRST: ACTIVE</span>
          <a href="https://github.com/meziani-ai/aura/blob/main/DISCLAIMER.md" target="_blank" rel="noopener noreferrer" className="normal-case opacity-70 hover:opacity-100">Disclaimer</a>
        </div>
      </footer>
    </div>
  );
}
