"use client";

import { useState, useEffect } from "react";
import { Activity } from "lucide-react";
import { fetchServiceHealth } from "@/lib/gateway";

interface ServiceState {
  name: string;
  port: number;
  status: "online" | "offline" | "checking";
}

export default function SystemHealth() {
  const [services, setServices] = useState<ServiceState[]>([
    { name: "Gateway", port: 8765, status: "checking" },
    { name: "Aura API", port: 3001, status: "checking" },
    { name: "Aura Flow", port: 3002, status: "checking" },
    { name: "Ollama", port: 11434, status: "checking" },
  ]);
  const [lastCheck, setLastCheck] = useState("");

  useEffect(() => {
    async function check() {
      try {
        const data = await fetchServiceHealth();
        setServices(
          data.services.map((s) => ({
            name: s.name,
            port: s.port,
            status: s.status as "online" | "offline",
          }))
        );
      } catch {
        // Gateway itself is down — mark everything offline except show gateway as offline
        setServices((prev) =>
          prev.map((s) => ({ ...s, status: "offline" as const }))
        );
      }
      setLastCheck(new Date().toLocaleTimeString("en-US", { hour12: false }));
    }

    check();
    const id = setInterval(check, 30_000);
    return () => clearInterval(id);
  }, []);

  function StatusDot({ status }: { status: string }) {
    const color =
      status === "online"
        ? "bg-terminal"
        : status === "checking"
          ? "bg-yellow-400 animate-pulse"
          : "bg-danger";
    return <span className={`w-2.5 h-2.5 rounded-full ${color}`} />;
  }

  return (
    <div className="border-4 border-white p-0">
      <div className="bg-white text-black p-2 px-4 font-bold uppercase text-xs tracking-widest flex items-center gap-2">
        <Activity className="w-3.5 h-3.5" /> System Health
      </div>
      <div className="p-6 space-y-4">
        {services.map((svc) => (
          <div
            key={svc.name}
            className="flex items-center justify-between border-b border-white/10 pb-3 last:border-0 last:pb-0"
          >
            <div className="flex items-center gap-3">
              <StatusDot status={svc.status} />
              <div>
                <span className="text-sm font-bold uppercase">{svc.name}</span>
                <span className="text-xs opacity-40 ml-2">:{svc.port}</span>
              </div>
            </div>
            <span
              className={`text-xs font-bold uppercase ${
                svc.status === "online"
                  ? "text-terminal"
                  : svc.status === "checking"
                    ? "text-yellow-400"
                    : "text-danger"
              }`}
            >
              {svc.status}
            </span>
          </div>
        ))}
        <div className="border-t-2 border-white/10 pt-3 text-[10px] opacity-30 uppercase text-center">
          Last check: {lastCheck || "..."}
        </div>
      </div>
    </div>
  );
}
