import subprocess
import sys
from datetime import datetime
from pathlib import Path

from fastapi import FastAPI, HTTPException
from fastapi.responses import HTMLResponse, JSONResponse

from life_dashboard import (
    ENV_TARGETS,
    GOALS_FILE,
    PROFILE_FILE,
    VAULT_JSON,
    _file_status,
    _service_status,
    get_mode,
    get_today_focus,
    load_json,
)


APP_DIR = Path("/home/yani/Aura/vault")
PACKETS_DIR = APP_DIR / "notebooklm_packets"

LOG_SOURCES = {
    "payment_server": Path("/home/yani/Aura/ai_agency_wealth/server.log"),
    "payment_server_debug": Path("/home/yani/Aura/ai_agency_wealth/server_debug.log"),
    "agency_metrics": Path("/home/yani/Aura/ai_agency_wealth/agency_metrics.log"),
    "n8n": Path("/home/yani/Aura/ai_agency_wealth/n8n.log"),
    "fulfiller": Path("/home/yani/Aura/ai_agency_wealth/fulfiller.log"),
}


app = FastAPI(title="Aura Mission Control GUI")


def _iso_now() -> str:
    return datetime.now().isoformat(timespec="seconds")


def _tail_text(path: Path, lines: int = 200) -> str:
    if not path.exists():
        return ""
    try:
        with path.open("r", errors="replace") as f:
            data = f.readlines()
        return "".join(data[-lines:])
    except Exception:
        return ""


def _list_packets(limit: int = 20) -> list[dict]:
    if not PACKETS_DIR.exists():
        return []
    files = sorted(PACKETS_DIR.glob("*.md"), key=lambda p: p.stat().st_mtime, reverse=True)
    out: list[dict] = []
    for p in files[:limit]:
        out.append(
            {
                "name": p.name,
                "path": str(p),
                "mtime": datetime.fromtimestamp(p.stat().st_mtime).isoformat(timespec="seconds"),
                "size": p.stat().st_size,
            }
        )
    return out


@app.get("/", response_class=HTMLResponse)
def index():
    html = """
<!doctype html>
<html>
<head>
  <meta charset="utf-8" />
  <meta name="viewport" content="width=device-width, initial-scale=1" />
  <title>Aura Mission Control</title>
  <style>
    :root {{
      --bg: #0b0f14;
      --panel: #0f1620;
      --muted: #9fb0c0;
      --text: #e8eef6;
      --ok: #1ee3a2;
      --warn: #ffcc66;
      --bad: #ff5d6c;
      --line: rgba(255,255,255,0.08);
      --mono: ui-monospace, SFMono-Regular, Menlo, Monaco, Consolas, "Liberation Mono", "Courier New", monospace;
      --sans: ui-sans-serif, system-ui, -apple-system, Segoe UI, Roboto, Helvetica, Arial, "Apple Color Emoji","Segoe UI Emoji";
    }}
    * {{ box-sizing: border-box; }}
    body {{
      margin: 0;
      background: radial-gradient(1200px 800px at 20% 10%, rgba(64, 190, 255, 0.08), transparent),
                  radial-gradient(1000px 700px at 80% 40%, rgba(30, 227, 162, 0.06), transparent),
                  var(--bg);
      color: var(--text);
      font-family: var(--sans);
    }}
    header {{
      position: sticky; top: 0;
      backdrop-filter: blur(10px);
      background: rgba(11,15,20,0.75);
      border-bottom: 1px solid var(--line);
      padding: 14px 18px;
      display: flex; align-items: center; justify-content: space-between;
      gap: 12px;
      z-index: 2;
    }}
    .brand {{
      display: flex; flex-direction: column;
      line-height: 1.1;
    }}
    .brand .title {{
      font-weight: 700;
      letter-spacing: 0.08em;
      text-transform: uppercase;
      font-size: 13px;
      color: rgba(232,238,246,0.9);
    }}
    .brand .sub {{
      font-family: var(--mono);
      font-size: 12px;
      color: var(--muted);
      margin-top: 4px;
    }}
    .controls {{
      display: flex; align-items: center; gap: 10px;
      font-family: var(--mono);
      font-size: 12px;
      color: var(--muted);
    }}
    .pill {{
      border: 1px solid var(--line);
      background: rgba(255,255,255,0.03);
      padding: 8px 10px;
      border-radius: 999px;
      display: inline-flex; gap: 8px; align-items: center;
      cursor: pointer;
      user-select: none;
    }}
    .pill:hover {{ border-color: rgba(255,255,255,0.18); }}
    .grid {{
      padding: 18px;
      display: grid;
      grid-template-columns: 1.2fr 1fr;
      gap: 14px;
    }}
    .panel {{
      background: linear-gradient(180deg, rgba(255,255,255,0.03), rgba(255,255,255,0.01));
      border: 1px solid var(--line);
      border-radius: 14px;
      overflow: hidden;
    }}
    .panel header {{
      position: relative;
      background: transparent;
      border-bottom: 1px solid var(--line);
      padding: 12px 14px;
    }}
    .panel h3 {{
      margin: 0;
      font-size: 12px;
      letter-spacing: 0.12em;
      text-transform: uppercase;
      color: rgba(232,238,246,0.9);
      font-weight: 700;
    }}
    .panel .content {{
      padding: 14px;
    }}
    .kv {{
      display: grid;
      grid-template-columns: 140px 1fr;
      gap: 10px 12px;
      font-family: var(--mono);
      font-size: 12px;
      color: rgba(232,238,246,0.92);
    }}
    .kv .k {{ color: var(--muted); }}
    .badge {{
      font-family: var(--mono);
      font-size: 12px;
      padding: 3px 8px;
      border-radius: 999px;
      border: 1px solid var(--line);
      background: rgba(255,255,255,0.02);
      display: inline-block;
    }}
    .ok {{ color: var(--ok); border-color: rgba(30,227,162,0.35); }}
    .warn {{ color: var(--warn); border-color: rgba(255,204,102,0.35); }}
    .bad {{ color: var(--bad); border-color: rgba(255,93,108,0.35); }}
    ul {{ margin: 0; padding-left: 16px; }}
    li {{ margin: 6px 0; color: rgba(232,238,246,0.9); }}
    .mono {{ font-family: var(--mono); font-size: 12px; color: rgba(232,238,246,0.9); }}
    pre {{
      margin: 0;
      padding: 12px;
      background: rgba(0,0,0,0.35);
      border: 1px solid var(--line);
      border-radius: 12px;
      overflow: auto;
      max-height: 340px;
      font-family: var(--mono);
      font-size: 12px;
      color: rgba(232,238,246,0.92);
      white-space: pre-wrap;
    }}
    .row {{
      display: flex;
      align-items: center;
      justify-content: space-between;
      gap: 10px;
      margin-bottom: 10px;
    }}
    select, button {{
      font-family: var(--mono);
      font-size: 12px;
      background: rgba(255,255,255,0.03);
      color: var(--text);
      border: 1px solid var(--line);
      border-radius: 10px;
      padding: 8px 10px;
    }}
    button {{
      cursor: pointer;
    }}
    button:hover {{
      border-color: rgba(255,255,255,0.18);
    }}
    a {{ color: rgba(64, 190, 255, 0.95); text-decoration: none; }}
    a:hover {{ text-decoration: underline; }}
    .packets {{ display: grid; gap: 10px; }}
    .packet {{
      border: 1px solid var(--line);
      background: rgba(255,255,255,0.02);
      border-radius: 12px;
      padding: 10px 12px;
      font-family: var(--mono);
      font-size: 12px;
      color: rgba(232,238,246,0.92);
      display: flex;
      align-items: baseline;
      justify-content: space-between;
      gap: 10px;
    }}
    .packet .meta {{ color: var(--muted); font-size: 11px; }}
    @media (max-width: 980px) {{
      .grid {{ grid-template-columns: 1fr; }}
      .kv {{ grid-template-columns: 120px 1fr; }}
    }}
  </style>
</head>
<body>
  <header>
    <div class="brand">
      <div class="title">Aura Mission Control</div>
      <div class="sub" id="subline">loading…</div>
    </div>
    <div class="controls">
      <div class="pill" id="refreshBtn">refresh</div>
      <div class="pill" id="autoBtn">auto: on</div>
      <div class="pill" id="tick">—</div>
    </div>
  </header>

  <div class="grid">
    <section class="panel">
      <header><h3>State</h3></header>
      <div class="content">
        <div class="kv" id="stateKv"></div>
        <div style="height:12px"></div>
        <div class="row">
          <div class="mono">Today focus</div>
          <span class="badge" id="modeBadge">—</span>
        </div>
        <ul id="todayList"></ul>
      </div>
    </section>

    <section class="panel">
      <header><h3>Mission Health</h3></header>
      <div class="content">
        <div class="row"><div class="mono">Vault + env</div><div class="mono" id="healthTs">—</div></div>
        <div class="kv" id="healthKv"></div>
        <div style="height:12px"></div>
        <div class="row"><div class="mono">Services</div><div class="mono">systemd</div></div>
        <div class="kv" id="svcKv"></div>
      </div>
    </section>

    <section class="panel">
      <header><h3>NotebookLM Packets</h3></header>
      <div class="content">
        <div class="row">
          <div class="mono">Latest packets</div>
          <div style="display:flex; gap:8px; align-items:center;">
            <select id="packetSource">
              <option value="agency_metrics">agency_metrics</option>
              <option value="payment_server">payment_server</option>
              <option value="n8n">n8n</option>
              <option value="fulfiller">fulfiller</option>
            </select>
            <button id="makePacketBtn">make packet</button>
          </div>
        </div>
        <div class="packets" id="packetList"></div>
      </div>
    </section>

    <section class="panel">
      <header><h3>Live Logs</h3></header>
      <div class="content">
        <div class="row">
          <div style="display:flex; gap:8px; align-items:center;">
            <select id="logSel">
              <option value="agency_metrics">agency_metrics</option>
              <option value="payment_server">payment_server</option>
              <option value="n8n">n8n</option>
              <option value="fulfiller">fulfiller</option>
            </select>
            <select id="logLines">
              <option value="120">120 lines</option>
              <option value="240" selected>240 lines</option>
              <option value="400">400 lines</option>
            </select>
          </div>
          <div class="mono" id="logMeta">—</div>
        </div>
        <pre id="logBox">loading…</pre>
      </div>
    </section>
  </div>

  <script>
    let auto = true;
    let timer = null;

    const $ = (id) => document.getElementById(id);
    const classify = (v) => {{
      const s = (v || '').toString().toLowerCase();
      if (s.includes('active') || s === 'ok') return 'ok';
      if (s.includes('missing') || s.includes('failed') || s.includes('empty')) return 'bad';
      if (s.includes('inactive') || s.includes('unknown') || s.includes('warning') || s.includes('degraded')) return 'warn';
      return '';
    }};

    async function fetchJson(url, opts) {{
      const r = await fetch(url, opts);
      if (!r.ok) throw new Error(await r.text());
      return await r.json();
    }}

    function badge(text, cls) {{
      return `<span class="badge ${cls}">${text}</span>`;
    }}

    async function refreshAll() {{
      const tick = new Date().toISOString().replace('T',' ').slice(0,19);
      $('tick').textContent = tick;

      const state = await fetchJson('/api/state');
      $('subline').textContent = `${state.owner} | ${state.operating_mode} | profile ${state.profile_sync}`;

      $('modeBadge').textContent = state.operating_mode || '—';

      const kv = [];
      kv.push(`<div class="k">owner</div><div>${state.owner}</div>`);
      kv.push(`<div class="k">profile</div><div>${state.profile_sync}</div>`);
      kv.push(`<div class="k">signal</div><div>${(state.high_signal_entities || []).slice(0,8).join(', ')}</div>`);
      $('stateKv').innerHTML = kv.join('');

      const today = state.today_focus || [];
      $('todayList').innerHTML = today.length ? today.map(x => `<li>${x}</li>`).join('') : `<li style="color:rgba(159,176,192,0.95)">no explicit today focus</li>`;

      const health = await fetchJson('/api/health');
      $('healthTs').textContent = health.at;
      const hk = [];
      hk.push(`<div class="k">vault</div><div>${badge(health.vault, classify(health.vault))}</div>`);
      (health.envs || []).forEach(e => {{
        hk.push(`<div class="k">${e.path}</div><div>${badge(e.status, classify(e.status))}</div>`);
      }});
      $('healthKv').innerHTML = hk.join('');

      const sk = [];
      (health.services || []).forEach(s => {{
        sk.push(`<div class="k">${s.name}</div><div>${badge(s.status, classify(s.status))}</div>`);
      }});
      $('svcKv').innerHTML = sk.join('');

      const packets = await fetchJson('/api/packets?limit=12');
      $('packetList').innerHTML = packets.length ? packets.map(p => {{
        const link = `/api/packet/${encodeURIComponent(p.name)}`;
        return `<div class="packet">
          <div>
            <div><a href="${link}" target="_blank" rel="noopener">${p.name}</a></div>
            <div class="meta">${p.mtime} • ${(p.size/1024).toFixed(1)} KB</div>
          </div>
          <div class="meta">md</div>
        </div>`;
      }}).join('') : `<div class="mono" style="color:var(--muted)">no packets yet</div>`;

      await refreshLog();
    }}

    async function refreshLog() {{
      const src = $('logSel').value;
      const lines = parseInt($('logLines').value, 10);
      const r = await fetchJson(`/api/log/${encodeURIComponent(src)}?lines=${lines}`);
      $('logMeta').textContent = `${src} • ${r.path} • tail(${lines})`;
      $('logBox').textContent = r.text || '(empty)';
    }}

    function setAuto(v) {{
      auto = v;
      $('autoBtn').textContent = auto ? 'auto: on' : 'auto: off';
      if (timer) clearInterval(timer);
      if (auto) timer = setInterval(() => refreshAll().catch(console.error), 2000);
    }}

    $('refreshBtn').onclick = () => refreshAll().catch(console.error);
    $('autoBtn').onclick = () => setAuto(!auto);
    $('logSel').onchange = () => refreshLog().catch(console.error);
    $('logLines').onchange = () => refreshLog().catch(console.error);
    $('makePacketBtn').onclick = async () => {{
      const source = $('packetSource').value;
      $('makePacketBtn').textContent = 'working…';
      try {{
        await fetchJson('/api/make_packet', {{
          method: 'POST',
          headers: {{ 'content-type': 'application/json' }},
          body: JSON.stringify({{ source, tail: 1500, audio: false }})
        }});
        await refreshAll();
      }} catch (e) {{
        alert('packet failed: ' + e);
      }} finally {{
        $('makePacketBtn').textContent = 'make packet';
      }}
    }};

    setAuto(true);
    refreshAll().catch(console.error);
  </script>
</body>
</html>
"""
    return HTMLResponse(html)


@app.get("/api/state")
def api_state():
    goals = load_json(GOALS_FILE) or {}
    profile = load_json(PROFILE_FILE) or {}

    owner = goals.get("owner") or profile.get("owner") or "Unknown owner"
    profile_sync = profile.get("last_updated") or "unknown"

    return JSONResponse(
        {
            "at": _iso_now(),
            "owner": owner,
            "profile_sync": profile_sync,
            "operating_mode": get_mode(goals, profile),
            "today_focus": get_today_focus(goals),
            "high_signal_entities": goals.get("high_signal_entities", []),
        }
    )


@app.get("/api/health")
def api_health():
    return JSONResponse(
        {
            "at": _iso_now(),
            "vault": _file_status(VAULT_JSON),
            "envs": [{"path": str(p), "status": _file_status(p)} for p in ENV_TARGETS],
            "services": [{"name": s, "status": _service_status(s)} for s in ("ai_pay", "aura_autopilot")],
        }
    )


@app.get("/api/log/{source}")
def api_log(source: str, lines: int = 240):
    if source not in LOG_SOURCES:
        raise HTTPException(status_code=404, detail="unknown source")
    p = LOG_SOURCES[source]
    return JSONResponse({"source": source, "path": str(p), "text": _tail_text(p, lines=lines)})


@app.get("/api/packets")
def api_packets(limit: int = 12):
    return JSONResponse(_list_packets(limit=limit))


@app.get("/api/packet/{name}", response_class=HTMLResponse)
def api_packet(name: str):
    # Prevent path traversal.
    if "/" in name or "\\" in name or ".." in name:
        raise HTTPException(status_code=400, detail="invalid name")
    p = PACKETS_DIR / name
    if not p.exists():
        raise HTTPException(status_code=404, detail="not found")
    text = p.read_text(encoding="utf-8", errors="replace")
    # Simple plain HTML render, keeps it super readable in browser.
    return HTMLResponse("<pre style='white-space:pre-wrap; font-family: ui-monospace, monospace; padding: 16px;'>" + _escape_html(text) + "</pre>")


def _escape_html(s: str) -> str:
    return s.replace("&", "&amp;").replace("<", "&lt;").replace(">", "&gt;")


@app.post("/api/make_packet")
def api_make_packet(payload: dict):
    source = payload.get("source") or "agency_metrics"
    tail = int(payload.get("tail") or 1500)
    audio = bool(payload.get("audio") or False)

    cmd = [
        sys.executable,
        str(APP_DIR / "log2notebooklm.py"),
        "--source",
        str(source),
        "--tail",
        str(tail),
    ]
    if audio:
        cmd.append("--audio")

    PACKETS_DIR.mkdir(parents=True, exist_ok=True)
    r = subprocess.run(cmd, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True)
    return JSONResponse({"ok": r.returncode == 0, "code": r.returncode, "output": r.stdout[-4000:]})

