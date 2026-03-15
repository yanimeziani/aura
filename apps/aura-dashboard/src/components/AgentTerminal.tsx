"use client";

import { useState, useEffect, useRef, useCallback } from "react";
import { Terminal } from "lucide-react";
import { logStreamUrl, fetchLogsTail } from "@/lib/gateway";

const LOG_TABS = ["agency", "server", "flow", "watchdog", "maid", "n8n", "fulfiller"] as const;
type LogName = (typeof LOG_TABS)[number];

export default function AgentTerminal({ token }: { token: string | null }) {
  const [activeTab, setActiveTab] = useState<LogName>("agency");
  const [lines, setLines] = useState<string[]>([]);
  const [connected, setConnected] = useState(false);
  const [error, setError] = useState("");
  const scrollRef = useRef<HTMLDivElement>(null);
  const esRef = useRef<EventSource | null>(null);

  const connect = useCallback(
    (tab: LogName) => {
      // Close existing connection
      if (esRef.current) {
        esRef.current.close();
        esRef.current = null;
      }
      setLines([]);
      setConnected(false);
      setError("");

      const url = logStreamUrl(tab, token);
      const es = new EventSource(url);
      esRef.current = es;

      es.onopen = () => {
        setConnected(true);
        setError("");
      };

      es.onmessage = (event) => {
        setLines((prev) => {
          const next = [...prev, event.data];
          // Keep last 500 lines to avoid memory bloat
          return next.length > 500 ? next.slice(-500) : next;
        });
      };

      es.onerror = () => {
        setConnected(false);
        setError("SSE disconnected — retrying...");
      };
    },
    [token]
  );

  // Fallback: fetch static tail if SSE fails after 3s
  useEffect(() => {
    connect(activeTab);

    const fallbackTimeout = setTimeout(async () => {
      if (!esRef.current || esRef.current.readyState !== EventSource.OPEN) {
        try {
          const allLogs = await fetchLogsTail(token, 40);
          const tabLines = allLogs[activeTab];
          if (tabLines && tabLines.length > 0) {
            setLines(tabLines);
            setError("Live stream unavailable — showing cached logs");
          } else {
            setError("Gateway unreachable");
          }
        } catch {
          setError("Gateway unreachable");
        }
      }
    }, 3000);

    return () => {
      clearTimeout(fallbackTimeout);
      if (esRef.current) {
        esRef.current.close();
        esRef.current = null;
      }
    };
  }, [activeTab, connect, token]);

  // Auto-scroll
  useEffect(() => {
    if (scrollRef.current) {
      scrollRef.current.scrollTop = scrollRef.current.scrollHeight;
    }
  }, [lines]);

  return (
    <div className="border-4 border-white">
      {/* Title bar */}
      <div className="bg-white text-black p-2 px-4 flex justify-between items-center">
        <h2 className="font-bold uppercase tracking-widest flex items-center gap-2 text-xs">
          <Terminal className="w-4 h-4" /> Agent Terminal
        </h2>
        <div className="flex items-center gap-3">
          {connected ? (
            <span className="flex items-center gap-1.5 text-[10px]">
              <span className="w-2 h-2 rounded-full bg-green-500 animate-pulse" />
              LIVE
            </span>
          ) : (
            <span className="flex items-center gap-1.5 text-[10px] text-red-600">
              <span className="w-2 h-2 rounded-full bg-red-500" />
              OFFLINE
            </span>
          )}
          <div className="flex gap-1">
            <span className="w-2 h-2 rounded-full bg-red-500" />
            <span className="w-2 h-2 rounded-full bg-yellow-500" />
            <span className="w-2 h-2 rounded-full bg-green-500" />
          </div>
        </div>
      </div>

      {/* Tab bar */}
      <div className="flex border-b-2 border-white overflow-x-auto">
        {LOG_TABS.map((tab) => (
          <button
            key={tab}
            onClick={() => setActiveTab(tab)}
            className={`px-4 py-2 text-xs font-bold uppercase tracking-wider transition-all whitespace-nowrap ${
              activeTab === tab
                ? "bg-white text-black"
                : "text-white/60 hover:text-white hover:bg-white/10"
            }`}
          >
            {tab}
          </button>
        ))}
      </div>

      {/* Log output */}
      <div
        ref={scrollRef}
        className="h-72 md:h-80 overflow-y-auto p-4 bg-black text-sm text-terminal leading-relaxed font-mono relative scanlines"
      >
        {error && (
          <p className="text-warn mb-2 text-xs">[{error}]</p>
        )}
        {lines.length === 0 && !error && (
          <p className="text-white/30 text-xs">
            Waiting for log data from {activeTab}...
          </p>
        )}
        {lines.map((line, i) => (
          <p key={i} className="break-all">
            {line}
          </p>
        ))}
        <span className="cursor-blink text-terminal">_</span>
      </div>
    </div>
  );
}
