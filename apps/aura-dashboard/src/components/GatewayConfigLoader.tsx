"use client";

import { useEffect } from "react";

/** Load optional runtime gateway URL from /aura-config.json so deploy can override without rebuild. */
export function GatewayConfigLoader() {
  useEffect(() => {
    fetch("/aura-config.json")
      .then((r) => (r.ok ? r.json() : null))
      .then((data: { gatewayUrl?: string; gatewayPort?: string | number } | null) => {
        if (data?.gatewayUrl) {
          (window as unknown as Record<string, string>).__AURA_GATEWAY__ =
            data.gatewayUrl.replace(/\/$/, "");
        }
        if (data?.gatewayPort) {
          (window as unknown as Record<string, string>).__AURA_GATEWAY_PORT__ =
            String(data.gatewayPort);
        }
      })
      .catch(() => {});
  }, []);
  return null;
}
