"use client";

import { useEffect, useState } from "react";
import { useRouter } from "next/navigation";
import { Activity, LogOut } from "lucide-react";
import { getStoredToken, clearToken } from "@/lib/auth";
import { fetchHealth } from "@/lib/gateway";
import SystemHealth from "@/components/SystemHealth";
import MeshStatus from "@/components/MeshStatus";
import AgentTerminal from "@/components/AgentTerminal";
import QuickActions from "@/components/QuickActions";

export default function DashboardPage() {
  const router = useRouter();
  const [token, setToken] = useState<string | null>(null);
  const [authed, setAuthed] = useState(false);
  const [time, setTime] = useState("");

  useEffect(() => {
    const stored = getStoredToken();
    if (!stored) {
      router.push("/login");
      return;
    }
    setToken(stored);

    // Quick validation: hit gateway health to confirm connectivity
    fetchHealth()
      .then(() => setAuthed(true))
      .catch(() => setAuthed(true)); // Still show dashboard even if gateway is down
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
            AURA // MISSION CONTROL
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

      {/* AGENT TERMINAL — full width */}
      <AgentTerminal token={token} />

      {/* BOTTOM GRID */}
      <div className="grid grid-cols-1 md:grid-cols-12 gap-6">
        <div className="md:col-span-6">
          <QuickActions token={token} />
        </div>
        <div className="md:col-span-6">
          <div className="border-4 border-white p-0">
            <div className="bg-white text-black p-2 px-4 font-bold uppercase text-xs tracking-widest">
              Session Sync
            </div>
            <div className="p-6 space-y-3">
              <div className="flex justify-between text-sm">
                <span className="opacity-50 uppercase text-xs">Active Workspaces</span>
                <span className="text-terminal">STANDBY</span>
              </div>
              <div className="flex justify-between text-sm">
                <span className="opacity-50 uppercase text-xs">Last Sync</span>
                <span className="tabular-nums">{new Date().toLocaleDateString()}</span>
              </div>
              <div className="flex justify-between text-sm">
                <span className="opacity-50 uppercase text-xs">Gateway</span>
                <span className="text-terminal">:8765</span>
              </div>
              <div className="border-t-2 border-white/10 pt-3 mt-3 text-[10px] opacity-30 uppercase text-center">
                IDE / TUI / CLI shared context
              </div>
            </div>
          </div>
        </div>
      </div>

      {/* FOOTER */}
      <footer className="border-4 border-white bg-white text-black p-2 px-4 md:px-6 flex flex-col md:flex-row justify-between items-center text-[10px] font-bold uppercase tracking-widest gap-2">
        <div className="flex gap-4 md:gap-6">
          <span>GATEWAY: 127.0.0.1:8765</span>
          <span>MODE: SOVEREIGN</span>
        </div>
        <div>ENCRYPTION: VAULT_AES // MESH_FIRST: ACTIVE</div>
      </footer>
    </div>
  );
}
