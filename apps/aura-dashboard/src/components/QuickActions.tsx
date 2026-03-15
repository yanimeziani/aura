"use client";

import { useState } from "react";
import {
  ExternalLink,
  Users,
  Download,
  Shield,
  Globe,
} from "lucide-react";
import { fetchLeads } from "@/lib/gateway";

interface Lead {
  email: string;
  company_name?: string;
  ts: number;
}

export default function QuickActions({ token }: { token: string | null }) {
  const [leads, setLeads] = useState<Lead[] | null>(null);
  const [showLeads, setShowLeads] = useState(false);

  async function handleViewLeads() {
    if (showLeads) {
      setShowLeads(false);
      return;
    }
    try {
      const data = await fetchLeads(token);
      setLeads(data);
      setShowLeads(true);
    } catch {
      setLeads([]);
      setShowLeads(true);
    }
  }

  return (
    <div className="border-4 border-white p-0">
      <div className="bg-white text-black p-2 px-4 font-bold uppercase text-xs tracking-widest flex items-center gap-2">
        <Shield className="w-3.5 h-3.5" /> Quick Actions
      </div>
      <div className="p-6 space-y-3">
        <a
          href="/globe"
          className="w-full border-2 border-terminal text-terminal p-3 font-bold uppercase text-sm flex items-center justify-between hover:bg-terminal hover:text-black transition-all block"
        >
          Planetary Outreach
          <Globe className="w-4 h-4" />
        </a>

        <a
          href="https://aura.meziani.org"
          target="_blank"
          rel="noopener noreferrer"
          className="w-full border-2 border-white p-3 font-bold uppercase text-sm flex items-center justify-between hover:bg-white hover:text-black transition-all block"
        >
          Open Landing Page
          <ExternalLink className="w-4 h-4" />
        </a>

        <button
          onClick={handleViewLeads}
          className="w-full border-2 border-white p-3 font-bold uppercase text-sm flex items-center justify-between hover:bg-white hover:text-black transition-all"
        >
          {showLeads ? "Hide Leads" : "View Leads"}
          <Users className="w-4 h-4" />
        </button>

        {showLeads && (
          <div className="border-2 border-white/30 p-3 max-h-40 overflow-y-auto space-y-2">
            {!leads || leads.length === 0 ? (
              <p className="text-xs opacity-40">No leads captured yet</p>
            ) : (
              leads.map((lead, i) => (
                <div key={i} className="text-xs flex justify-between">
                  <span className="font-bold">{lead.email}</span>
                  <span className="opacity-40">
                    {new Date(lead.ts * 1000).toLocaleDateString()}
                  </span>
                </div>
              ))
            )}
          </div>
        )}

        <button
          className="w-full border-2 border-white p-3 font-bold uppercase text-sm flex items-center justify-between hover:bg-white hover:text-black transition-all"
          onClick={() =>
            window.open(
              `http://localhost:8765/logs/tail?n=200${token ? `&token=${encodeURIComponent(token)}` : ""}`,
              "_blank"
            )
          }
        >
          Export Logs (JSON)
          <Download className="w-4 h-4" />
        </button>
      </div>
    </div>
  );
}
