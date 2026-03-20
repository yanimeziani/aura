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
  <div class="metallic-liquid"></div>
  <div class="metallic-overlay"></div>
  <main class="shell">
    <section class="hero">
      <div class="eyebrow">Nexa Sovereign Governance</div>
      <h1>World State Mapped.</h1>
      <p>
        The Zig Motor (\`aura-api\`) handles region transition protocols while the Zig Canvas (\`aura-canvas\`) projects the state.
      </p>
      
      <div id="canvas-container">
        <canvas id="aura-canvas"></canvas>
      </div>

      <div class="button-row">
        <button class="button primary" id="refresh">Sync World State</button>
        <button class="button" id="routes">Protocol Inventory</button>
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

function initCanvas() {
  const canvas = document.getElementById("aura-canvas") as HTMLCanvasElement;
  if (!canvas) return;
  const ctx = canvas.getContext("2d");
  if (!ctx) return;

  function resize() {
    canvas.width = canvas.offsetWidth;
    canvas.height = canvas.offsetHeight;
  }
  window.addEventListener("resize", resize);
  resize();

  const points: { x: number, y: number, z: number, color: string, label?: string }[] = [];
  // World Model Nodes
  const regions = ["Versailles", "Algeria", "Canada", "Australia", "UN Center"];
  regions.forEach((r, i) => {
    points.push({
      x: Math.cos(i * (Math.PI * 2 / regions.length)) * 4,
      y: Math.sin(i * (Math.PI * 2 / regions.length)) * 4,
      z: 8,
      color: "#57e3b0",
      label: r
    });
  });

  // Background Mesh
  for (let i = 0; i < 150; i++) {
    points.push({
      x: (Math.random() - 0.5) * 15,
      y: (Math.random() - 0.5) * 15,
      z: Math.random() * 15 + 2,
      color: "rgba(255, 255, 255, 0.2)"
    });
  }

  function project(p: typeof points[0]) {
    const fov = Math.PI / 2.2;
    const aspect = canvas.width / canvas.height;
    const f = 1.0 / Math.tan(fov / 2.0);
    
    const px = (p.x * f) / p.z;
    const py = (p.y * f * aspect) / p.z;
    
    const sx = (px + 1.0) * 0.5 * canvas.width;
    const sy = (py + 1.0) * 0.5 * canvas.height;
    
    return { sx, sy };
  }

  let frame = 0;
  function draw() {
    frame++;
    ctx.fillStyle = "#000";
    ctx.fillRect(0, 0, canvas.width, canvas.height);

    // Dynamic rotation
    const rotX = Math.sin(frame * 0.005) * 2;
    const rotY = Math.cos(frame * 0.005) * 2;

    points.forEach(p => {
      // Simple rotation for the demo
      const x = p.x * Math.cos(frame * 0.01) - p.z * Math.sin(frame * 0.01);
      const z = p.x * Math.sin(frame * 0.01) + p.z * Math.cos(frame * 0.01);
      
      const { sx, sy } = project({ ...p, x, z: z + 10 });
      
      if (sx >= 0 && sx < canvas.width && sy >= 0 && sy < canvas.height) {
        const size = (1 / (z + 10)) * 25;
        ctx.fillStyle = p.color;
        ctx.globalAlpha = Math.min(1, (20 - (z + 10)) / 10);
        
        if (p.label) {
          ctx.beginPath();
          ctx.arc(sx, sy, size * 1.5, 0, Math.PI * 2);
          ctx.fill();
          ctx.font = `${Math.max(10, size * 2)}px var(--font-mono)`;
          ctx.fillText(p.label, sx + size * 2, sy + 5);
          
          // Draw connections to center
          ctx.strokeStyle = "rgba(87, 227, 176, 0.2)";
          const center = project({ x: 0, y: 0, z: 15, color: "" });
          ctx.beginPath();
          ctx.moveTo(sx, sy);
          ctx.lineTo(center.sx, center.sy);
          ctx.stroke();
        } else {
          ctx.fillRect(sx, sy, size, size);
        }
      }
    });

    requestAnimationFrame(draw);
  }
  draw();
}

initCanvas();

if ('serviceWorker' in navigator) {
  window.addEventListener('load', () => {
    navigator.serviceWorker.register('/sw.js').then((reg) => {
      console.log('Nexa PWA ready on network.', reg.scope);
    }).catch((err) => {
      console.log('Nexa PWA registration failed: ', err);
    });
  });
}

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
