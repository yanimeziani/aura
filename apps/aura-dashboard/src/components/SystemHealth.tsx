"use client";

import { useState, useEffect } from "react";
import { Activity, Server, Wifi, WifiOff } from "lucide-react";
import { fetchHealth } from "@/lib/gateway";

interface HealthState {
  gateway: "online" | "offline" | "checking";
}

export default function SystemHealth() {
  const [health, setHealth] = useState<HealthState>({ gateway: "checking" });
  const [lastCheck, setLastCheck] = useState<string>("");

  useEffect(() => {
    async function check() {
      try {
        const data = await fetchHealth();
        setHealth({ gateway: data.status === "ok" ? "online" : "offline" });
      } catch {
        setHealth({ gateway: "offline" });
      }
      setLastCheck(new Date().toLocaleTimeString("en-US", { hour12: false }));
    }

    check();
    const id = setInterval(check, 30_000);
    return () => clearInterval(id);
  }, []);

  const services = [
    { name: "Gateway", status: health.gateway, port: ":8765" },
    { name: "Aura API", status: "standby" as const, port: ":3001" },
    { name: "Aura Flow", status: "standby" as const, port: ":3002" },
    { name: "Ollama", status: "standby" as const, port: ":11434" },
  ];

  function StatusDot({ status }: { status: string }) {
    const color =
      status === "online"
        ? "bg-terminal"
        : status === "checking"
          ? "bg-yellow-400 animate-pulse"
          : status === "standby"
            ? "bg-yellow-600"
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
                <span className="text-xs opacity-40 ml-2">{svc.port}</span>
              </div>
            </div>
            <span
              className={`text-xs font-bold uppercase ${
                svc.status === "online"
                  ? "text-terminal"
                  : svc.status === "standby"
                    ? "text-yellow-600"
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
