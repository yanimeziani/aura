"use client";

import { useState, useEffect } from "react";
import { Activity } from "lucide-react";
import { fetchServiceHealth } from "@/lib/gateway";

interface ServiceState {
  name: string;
  port: number;
  status: "online" | "offline" | "checking";
}

const INITIAL_SERVICES: ServiceState[] = [
  { name: "Gateway", port: 8765, status: "checking" },
  { name: "Cerberus", port: 3000, status: "checking" },
  { name: "Nexa API", port: 3001, status: "checking" },
  { name: "Nexa Flow", port: 3002, status: "checking" },
  { name: "Ollama", port: 11434, status: "checking" },
  { name: "Pegasus API", port: 8080, status: "checking" },
  { name: "Dashboard", port: 3003, status: "checking" },
];

export default function SystemHealth() {
  const [services, setServices] = useState<ServiceState[]>(INITIAL_SERVICES);
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

  const online = services.filter((s) => s.status === "online").length;

  return (
    <div className="border-4 border-white p-0">
      <div className="bg-white text-black p-2 px-4 font-bold uppercase text-xs tracking-widest flex items-center justify-between">
        <span className="flex items-center gap-2">
          <Activity className="w-3.5 h-3.5" /> System Health
        </span>
        <span className="text-[10px] font-mono">
          {online}/{services.length} TCP
        </span>
      </div>
      <div className="p-4 space-y-2">
        {services.map((svc) => (
          <div
            key={svc.name}
            className="flex items-center justify-between py-1.5 border-b border-white/5 last:border-0"
          >
            <div className="flex items-center gap-2.5">
              <span
                className={`w-2 h-2 rounded-full ${
                  svc.status === "online"
                    ? "bg-terminal"
                    : svc.status === "checking"
                      ? "bg-yellow-400 animate-pulse"
                      : "bg-red-500"
                }`}
              />
              <span className="text-xs font-bold uppercase">{svc.name}</span>
            </div>
            <div className="flex items-center gap-3">
              <span className="text-[10px] opacity-30 tabular-nums">
                :{svc.port}
              </span>
              <span
                className={`text-[10px] font-bold uppercase w-12 text-right ${
                  svc.status === "online"
                    ? "text-terminal"
                    : svc.status === "checking"
                      ? "text-yellow-400"
                      : "text-red-500"
                }`}
              >
                {svc.status === "online" ? "UP" : svc.status === "checking" ? "..." : "DOWN"}
              </span>
            </div>
          </div>
        ))}
        <div className="pt-2 text-[9px] opacity-20 uppercase text-center tabular-nums">
          RAW TCP PROBE // {lastCheck || "..."}
        </div>
      </div>
    </div>
  );
}
