const DEFAULT_GATEWAY = "http://127.0.0.1:8765";

function browserDefaultGateway(): string {
  if (typeof window === "undefined") {
    return process.env.NEXT_PUBLIC_GATEWAY_URL || DEFAULT_GATEWAY;
  }
  const { protocol, hostname, port, origin } = window.location;
  const explicitPort = (window as unknown as Record<string, string>).__AURA_GATEWAY_PORT__;
  if (port && port !== "3003") {
    return `${origin.replace(/\/$/, "")}/gw`;
  }
  const resolvedPort = explicitPort || process.env.NEXT_PUBLIC_GATEWAY_PORT || "8765";
  return `${protocol}//${hostname}:${resolvedPort}`;
}

/** Resolve gateway URL at call time so runtime config (aura-config.json or window.__AURA_GATEWAY__) applies. */
export function getGatewayUrl(): string {
  if (typeof window !== "undefined") {
    const w = window as unknown as Record<string, string>;
    if (w.__AURA_GATEWAY__) return w.__AURA_GATEWAY__;
  }
  return process.env.NEXT_PUBLIC_GATEWAY_URL || browserDefaultGateway();
}

export function getGatewayLabel(): string {
  try {
    const url = new URL(getGatewayUrl(), typeof window !== "undefined" ? window.location.origin : DEFAULT_GATEWAY);
    return url.host + url.pathname.replace(/\/$/, "");
  } catch {
    return getGatewayUrl().replace(/^https?:\/\//, "");
  }
}

const FETCH_RETRIES = 3;
const FETCH_RETRY_DELAY_MS = 1000;

/** Resilient fetch: retry with backoff on network/5xx. */
async function fetchWithRetry(
  input: RequestInfo | URL,
  init?: RequestInit,
  retries = FETCH_RETRIES
): Promise<Response> {
  let lastRes: Response | null = null;
  for (let i = 0; i <= retries; i++) {
    try {
      const res = await fetch(input, init);
      if (res.ok || res.status < 500) return res;
      lastRes = res;
    } catch {
      lastRes = null;
    }
    if (i < retries) {
      await new Promise((r) => setTimeout(r, FETCH_RETRY_DELAY_MS * (i + 1)));
    }
  }
  return lastRes ?? new Response(null, { status: 0 });
}

function tokenParam(token: string | null): string {
  return token ? `?token=${encodeURIComponent(token)}` : "";
}

export async function validateToken(
  token: string
): Promise<{ valid: boolean; owner?: string }> {
  const res = await fetch(`${getGatewayUrl()}/api/validate-token`, {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({ token }),
  });
  if (!res.ok) return { valid: false };
  return res.json();
}

export async function fetchHealth(): Promise<{
  status: string;
  service: string;
}> {
  const res = await fetch(`${getGatewayUrl()}/health`);
  return res.json();
}

export async function fetchProviders(): Promise<{
  providers: Array<{ id: string; enabled: boolean; openai_compatible: boolean }>;
}> {
  const res = await fetchWithRetry(`${getGatewayUrl()}/providers`);
  if (!res.ok) return { providers: [] };
  return res.json();
}

export async function fetchModels(): Promise<{
  data: Array<{ id: string; source: string }>;
}> {
  const res = await fetchWithRetry(`${getGatewayUrl()}/v1/models`);
  if (!res.ok) return { data: [] };
  return res.json();
}

export async function fetchLogsTail(
  token: string | null,
  n: number = 40
): Promise<Record<string, string[]>> {
  const res = await fetch(
    `${getGatewayUrl()}/logs/tail?n=${n}${token ? `&token=${encodeURIComponent(token)}` : ""}`
  );
  if (!res.ok) return {};
  return res.json();
}

export async function fetchLeads(
  token: string | null
): Promise<Array<{ email: string; company_name?: string; ts: number }>> {
  const res = await fetch(`${getGatewayUrl()}/api/leads`, {
    headers: token ? { Authorization: `Bearer ${token}` } : {},
  });
  if (!res.ok) return [];
  return res.json();
}

export function logStreamUrl(name: string, token: string | null): string {
  return `${getGatewayUrl()}/logs/stream/${name}${tokenParam(token)}`;
}

/** One-shot state when reconnecting (e.g. phone back from sleep). VPS kept running; stream back session + logs then resume live. */
export async function fetchCatchUp(
  token: string | null,
  workspaceId: string = "aura",
  n: number = 100
): Promise<{
  session: { workspace_id: string; payload: unknown };
  logs_tail: Record<string, string[]>;
}> {
  if (!token) return { session: { workspace_id: workspaceId, payload: null }, logs_tail: {} };
  const res = await fetch(
    `${getGatewayUrl()}/sync/catch-up?workspace_id=${encodeURIComponent(workspaceId)}&n=${n}`,
    { headers: { Authorization: `Bearer ${token}` } }
  );
  if (!res.ok) return { session: { workspace_id: workspaceId, payload: null }, logs_tail: {} };
  return res.json();
}

export async function fetchOutreachGlobe(token: string | null): Promise<{
  nodes: Array<{
    id: string;
    type: string;
    label: string;
    country: string;
    tier: string;
    agents?: number;
  }>;
  connections: Array<{
    from: string;
    to: string;
    type: string;
    strength: number;
  }>;
  meta?: { total_orgs: number; total_leads: number; sovereign: string | null };
}> {
  const res = await fetch(`${getGatewayUrl()}/api/outreach/globe`, {
    headers: token ? { Authorization: `Bearer ${token}` } : {},
  });
  if (!res.ok) throw new Error(`HTTP ${res.status}`);
  return res.json();
}

export async function fetchServiceHealth(): Promise<{
  services: Array<{ name: string; port: number; status: string }>;
}> {
  const res = await fetchWithRetry(`${getGatewayUrl()}/health/services`);
  if (!res.ok) throw new Error(`HTTP ${res.status}`);
  return res.json();
}

export async function fetchDistill(
  url: string,
  token: string | null = null
): Promise<{ distilled?: string; error?: string }> {
  const res = await fetch(`${getGatewayUrl()}/api/distill`, {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
      ...(token ? { Authorization: `Bearer ${token}` } : {}),
    },
    body: JSON.stringify({ url }),
  });
  if (!res.ok) {
    const err = await res.json();
    return { error: err.error || `HTTP ${res.status}` };
  }
  return res.json();
}

export async function fetchRegionClusters(): Promise<{
  clusters: Array<{ country: string; locale: string; visits: number }>;
}> {
  const res = await fetchWithRetry(`${getGatewayUrl()}/telemetry/regions`);
  if (!res.ok) return { clusters: [] };
  return res.json();
}
