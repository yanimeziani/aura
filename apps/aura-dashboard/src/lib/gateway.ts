const GATEWAY_URL =
  typeof window !== "undefined"
    ? (window as unknown as Record<string, string>).__AURA_GATEWAY__ ||
      process.env.NEXT_PUBLIC_GATEWAY_URL ||
      "http://localhost:8765"
    : process.env.NEXT_PUBLIC_GATEWAY_URL || "http://localhost:8765";

function tokenParam(token: string | null): string {
  return token ? `?token=${encodeURIComponent(token)}` : "";
}

export async function validateToken(
  token: string
): Promise<{ valid: boolean; owner?: string }> {
  const res = await fetch(`${GATEWAY_URL}/api/validate-token`, {
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
  const res = await fetch(`${GATEWAY_URL}/health`);
  return res.json();
}

export async function fetchProviders(): Promise<{
  providers: Array<{ id: string; enabled: boolean; openai_compatible: boolean }>;
}> {
  const res = await fetch(`${GATEWAY_URL}/providers`);
  return res.json();
}

export async function fetchModels(): Promise<{
  data: Array<{ id: string; source: string }>;
}> {
  const res = await fetch(`${GATEWAY_URL}/v1/models`);
  if (!res.ok) return { data: [] };
  return res.json();
}

export async function fetchLogsTail(
  token: string | null,
  n: number = 40
): Promise<Record<string, string[]>> {
  const res = await fetch(
    `${GATEWAY_URL}/logs/tail?n=${n}${token ? `&token=${encodeURIComponent(token)}` : ""}`
  );
  if (!res.ok) return {};
  return res.json();
}

export async function fetchLeads(
  token: string | null
): Promise<Array<{ email: string; company_name?: string; ts: number }>> {
  const res = await fetch(`${GATEWAY_URL}/api/leads`, {
    headers: token ? { Authorization: `Bearer ${token}` } : {},
  });
  if (!res.ok) return [];
  return res.json();
}

export function logStreamUrl(name: string, token: string | null): string {
  return `${GATEWAY_URL}/logs/stream/${name}${tokenParam(token)}`;
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
  const res = await fetch(`${GATEWAY_URL}/api/outreach/globe`, {
    headers: token ? { Authorization: `Bearer ${token}` } : {},
  });
  if (!res.ok) throw new Error(`HTTP ${res.status}`);
  return res.json();
}

export function getGatewayUrl(): string {
  return GATEWAY_URL;
}
