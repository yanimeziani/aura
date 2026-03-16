type HealthResponse = {
  status: string;
  service: string;
  zig: string;
  surface: string;
};

type StatusResponse = {
  control_plane: string;
  mesh: string;
  frontend: string;
  risk_mode: string;
};

type ServiceHealthResponse = {
  services: Array<{ name: string; port: number; status: string }>;
};

type ProvidersResponse = {
  providers: Array<{ id: string; enabled: boolean; openai_compatible?: boolean; mesh?: boolean }>;
};

type ModelsResponse = {
  data: Array<{ id: string; source: string; mesh?: boolean }>;
};

type RegionClustersResponse = {
  clusters: Array<{ country: string; locale: string; visits: number }>;
};

const app = document.querySelector<HTMLDivElement>("#app");

if (!app) {
  throw new Error("missing #app root");
}

app.innerHTML = `
  <main class="shell">
    <section class="hero">
      <div class="eyebrow">Nexa Lite Control Surface</div>
      <h1>Reduce supply chain. Keep operator speed.</h1>
      <p>
        This shell is the replacement target for the current Next.js-heavy surface:
        lightweight TypeScript, local design system, and API routes served by a Zig gateway.
      </p>
      <div class="button-row">
        <button class="button primary" id="refresh">Refresh Gateway State</button>
        <button class="button" id="routes">Show Route Inventory</button>
      </div>
    </section>

    <section class="grid wide">
      <article class="panel">
        <h2>Gateway Health</h2>
        <div class="metric"><span>Status</span><strong id="health-status">loading</strong></div>
        <div class="metric"><span>Service</span><strong id="health-service">loading</strong></div>
        <div class="metric"><span>Zig</span><strong id="health-zig">loading</strong></div>
        <div class="metric"><span>Surface</span><strong id="health-surface">loading</strong></div>
        <div class="metric"><span>Upstream</span><strong id="gateway-base" class="mono">resolving</strong></div>
      </article>

      <article class="panel">
        <h2>Control Plane</h2>
        <div class="metric"><span>Mode</span><strong id="status-control-plane">loading</strong></div>
        <div class="metric"><span>Mesh</span><strong id="status-mesh">loading</strong></div>
        <div class="metric"><span>Frontend</span><strong id="status-frontend">loading</strong></div>
        <div class="metric"><span>Risk Mode</span><strong id="status-risk">loading</strong></div>
      </article>
    </section>

    <section class="grid wide">
      <article class="panel">
        <h2>System Health</h2>
        <div class="stack" id="system-health-list"></div>
      </article>

      <article class="panel">
        <h2>Mesh Status</h2>
        <div class="stack">
          <div>
            <div class="label">Providers</div>
            <div class="list" id="providers-list"></div>
          </div>
          <div>
            <div class="label">Models</div>
            <div class="list" id="models-list"></div>
          </div>
        </div>
      </article>

      <article class="panel">
        <h2>Region Clusters</h2>
        <div class="list" id="regions-list"></div>
      </article>
    </section>

    <section class="panel">
      <h2>Operator Log</h2>
      <div class="log" id="log">booting\n</div>
    </section>
  </main>
`;

const logEl = byId("log");

function byId(id: string): HTMLElement {
  const el = document.getElementById(id);
  if (!el) throw new Error(`missing element: ${id}`);
  return el;
}

function setText(id: string, value: string, tone?: "ok" | "warn"): void {
  const el = byId(id);
  el.textContent = value;
  el.className = tone === "ok" ? "status-ok" : tone === "warn" ? "status-warn" : "";
}

function appendLog(line: string): void {
  logEl.textContent = `${logEl.textContent}${new Date().toISOString()} ${line}\n`;
}

function gatewayBase(): string {
  const runtime = window as unknown as Record<string, string>;
  if (runtime.__NEXA_GATEWAY__) {
    return runtime.__NEXA_GATEWAY__.replace(/\/$/, "");
  }
  return "http://127.0.0.1:8765";
}

async function fetchJson<T>(path: string, absolute = false): Promise<T> {
  const target = absolute ? path : `${gatewayBase()}${path}`;
  const response = await fetch(target, {
    headers: {
      "Accept": "application/json",
    },
  });
  if (!response.ok) {
    throw new Error(`${target} returned ${response.status}`);
  }
  return response.json() as Promise<T>;
}

function renderServices(payload: ServiceHealthResponse): void {
  const target = byId("system-health-list");
  target.innerHTML = payload.services
    .map((service) => {
      const tone = service.status === "online" ? "status-ok" : "status-warn";
      return `
        <div class="item">
          <div class="row">
            <strong>${service.name}</strong>
            <span class="pill ${tone}">${service.status}</span>
          </div>
          <div class="row">
            <span class="tiny">TCP port</span>
            <span class="mono subtle">:${service.port}</span>
          </div>
        </div>
      `;
    })
    .join("");
}

function renderProviders(payload: ProvidersResponse): void {
  const target = byId("providers-list");
  if (payload.providers.length === 0) {
    target.innerHTML = `<div class="tiny">No providers detected</div>`;
    return;
  }
  target.innerHTML = payload.providers
    .map((provider) => `
      <div class="item">
        <div class="row wrap">
          <strong>${provider.id}</strong>
          <span class="pill ${provider.enabled ? "status-ok" : "status-warn"}">${provider.enabled ? "online" : "off"}</span>
        </div>
        <div class="row">
          <span class="tiny">OpenAI compatible</span>
          <span class="mono subtle">${provider.openai_compatible ? "yes" : "no"}</span>
        </div>
      </div>
    `)
    .join("");
}

function renderModels(payload: ModelsResponse): void {
  const target = byId("models-list");
  if (payload.data.length === 0) {
    target.innerHTML = `<div class="tiny">No models exposed by gateway</div>`;
    return;
  }
  target.innerHTML = payload.data
    .slice(0, 12)
    .map((model) => `
      <div class="item">
        <div class="row wrap">
          <strong class="mono">${model.id}</strong>
          <span class="pill">${model.source}</span>
        </div>
      </div>
    `)
    .join("");
}

function renderRegions(payload: RegionClustersResponse): void {
  const target = byId("regions-list");
  if (payload.clusters.length === 0) {
    target.innerHTML = `<div class="tiny">No landing telemetry yet</div>`;
    return;
  }
  target.innerHTML = payload.clusters
    .slice(0, 8)
    .map((cluster) => `
      <div class="item">
        <div class="row wrap">
          <strong>${cluster.country}</strong>
          <span class="pill">${cluster.locale}</span>
        </div>
        <div class="row">
          <span class="tiny">Visits</span>
          <span class="mono status-ok">${cluster.visits}</span>
        </div>
      </div>
    `)
    .join("");
}

async function refresh(): Promise<void> {
  appendLog("refresh requested");
  setText("gateway-base", gatewayBase());

  const [health, status, services, providers, models, regions] = await Promise.all([
    fetchJson<HealthResponse>("/api/health", true),
    fetchJson<StatusResponse>("/api/status", true),
    fetchJson<ServiceHealthResponse>("/health/services"),
    fetchJson<ProvidersResponse>("/providers"),
    fetchJson<ModelsResponse>("/v1/models"),
    fetchJson<RegionClustersResponse>("/telemetry/regions"),
  ]);

  setText("health-status", health.status, health.status === "ok" ? "ok" : "warn");
  setText("health-service", health.service);
  setText("health-zig", health.zig);
  setText("health-surface", health.surface);

  setText("status-control-plane", status.control_plane);
  setText("status-mesh", status.mesh);
  setText("status-frontend", status.frontend, "ok");
  setText("status-risk", status.risk_mode, "warn");

  renderServices(services);
  renderProviders(providers);
  renderModels(models);
  renderRegions(regions);

  appendLog("refresh complete");
}

async function showRoutes(): Promise<void> {
  const routes = await fetchJson<{ routes: string[] }>("/api/routes");
  appendLog(`route inventory: ${routes.routes.join(", ")}`);
}

byId("refresh").addEventListener("click", () => {
  refresh().catch((error: unknown) => {
    appendLog(`refresh failed: ${String(error)}`);
  });
});

byId("routes").addEventListener("click", () => {
  showRoutes().catch((error: unknown) => {
    appendLog(`route fetch failed: ${String(error)}`);
  });
});

refresh().catch((error: unknown) => {
  appendLog(`initial refresh failed: ${String(error)}`);
});
