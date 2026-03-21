import json
import os
import signal
import subprocess
import sys
from datetime import datetime
from pathlib import Path

from fastapi import FastAPI, HTTPException
from fastapi.responses import FileResponse, HTMLResponse, JSONResponse
from fastapi.staticfiles import StaticFiles

from life_dashboard import (
    AURA_ROOT,
    BASE_DIR as VAULT_DIR,
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

APP_DIR = VAULT_DIR
STATIC_DIR = APP_DIR / "static"
PACKETS_DIR = APP_DIR / "notebooklm_packets"
RADIO_DIR = APP_DIR / "radio"
RADIO_STATE_PATH = RADIO_DIR / "deck_state.json"
RADIO_PID_PATH = RADIO_DIR / "deck.pid"

_AGENCY = AURA_ROOT / "ai_agency_wealth"
LOG_SOURCES = {
    "payment_server": _AGENCY / "server.log",
    "payment_server_debug": _AGENCY / "server_debug.log",
    "agency_metrics": _AGENCY / "agency_metrics.log",
    "n8n": _AGENCY / "n8n.log",
    "fulfiller": _AGENCY / "fulfiller.log",
    "voice_stream": AURA_ROOT / ".aura" / "voice" / "voice.log",
}


app = FastAPI(title="Aura Mission Control GUI")
app.mount("/static", StaticFiles(directory=str(STATIC_DIR)), name="static")


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


def _load_json(path: Path) -> dict:
    try:
        return json.loads(path.read_text(encoding="utf-8"))
    except Exception:
        return {}


def _list_radio(limit: int = 20) -> list[dict]:
    if not RADIO_DIR.exists():
        return []
    files = sorted(RADIO_DIR.glob("*.json"), key=lambda p: p.stat().st_mtime, reverse=True)
    out: list[dict] = []
    for p in files[:limit]:
        if p.name == RADIO_STATE_PATH.name:
            continue
        data = _load_json(p)
        if not data.get("bulletin"):
            continue
        file_map = data.get("files") or {}
        out.append(
            {
                "name": p.name,
                "mtime": datetime.fromtimestamp(p.stat().st_mtime).isoformat(timespec="seconds"),
                "title": data.get("title") or p.stem,
                "source_name": data.get("source_name") or "unknown",
                "provider_used": data.get("provider_used") or "unknown",
                "model": data.get("model") or "",
                "audio_ok": bool(data.get("audio_ok")),
                "bulletin": data.get("bulletin") or "",
                "files": file_map,
            }
        )
    return out


def _pid_alive(pid: int) -> bool:
    try:
        os.kill(pid, 0)
        return True
    except Exception:
        return False


def _radio_deck_state() -> dict:
    data = _load_json(RADIO_STATE_PATH)
    pid = int(data.get("pid") or 0) if str(data.get("pid") or "").isdigit() else 0
    running = bool(pid and _pid_alive(pid))
    if data:
        data["running"] = running and bool(data.get("running", True))
    else:
        data = {"running": False}
    return data


@app.get("/", response_class=HTMLResponse)
def index():
    html = """
<!doctype html>
<html>
<head>
  <meta charset="utf-8" />
  <meta name="viewport" content="width=device-width, initial-scale=1" />
  <title>Aura Mission Control</title>
  <link rel="stylesheet" href="/static/mission_control.css" />
</head>
<body>
  <div class="shell">
    <header class="topbar">
      <div class="brand">
        <div class="eyebrow">Aura Mission Control</div>
        <h1>Full GUI Radio Deck</h1>
        <div class="sub" id="subline">loading…</div>
      </div>
      <div class="top-actions">
        <div class="pill" id="refreshBtn">refresh</div>
        <div class="pill" id="autoBtn">auto: on</div>
        <div class="pill" id="tick">—</div>
      </div>
    </header>

    <main class="layout">
      <section class="hero">
        <article class="panel hero-card">
          <div class="panel-body hero-grid">
            <div class="hero-copy">
              <div class="status-strip">
                <span class="chip ok" id="modeBadge">—</span>
                <span class="chip" id="radioDeckStatus">stopped</span>
              </div>
              <h2>Live log intelligence, spoken like a control room.</h2>
              <p>
                This surface is for constant radio, live status, and browser-first operation.
                No terminal choreography. Pick a source, lock a provider, and run the deck.
              </p>
              <div class="control-block">
                <div class="control-row grow">
                  <select id="radioSource">
                    <option value="agency_metrics">agency_metrics</option>
                    <option value="payment_server">payment_server</option>
                    <option value="n8n">n8n</option>
                    <option value="fulfiller">fulfiller</option>
                    <option value="voice_stream">voice_stream</option>
                  </select>
                  <select id="radioProvider">
                    <option value="auto">auto</option>
                    <option value="gemini">gemini</option>
                    <option value="groq">groq</option>
                    <option value="local">local</option>
                  </select>
                  <select id="radioInterval">
                    <option value="15">15s</option>
                    <option value="30">30s</option>
                    <option value="60" selected>60s</option>
                    <option value="120">120s</option>
                  </select>
                </div>
                <div class="control-row">
                  <button class="button-primary" id="makeRadioBtn">broadcast now</button>
                  <button class="button-primary" id="startDeckBtn">start deck</button>
                  <button class="button-danger" id="stopDeckBtn">stop deck</button>
                  <div class="pill" id="radioStatus">manual mode</div>
                </div>
              </div>
            </div>

            <div class="player-card">
              <div class="now-playing-label">Now Playing</div>
              <div class="visualizer" id="visualizer">
                <span></span><span></span><span></span><span></span><span></span><span></span><span></span><span></span>
              </div>
              <div class="now-playing-title" id="nowPlayingTitle">No live bulletin yet</div>
              <div class="now-playing-copy" id="nowPlayingCopy">Start a broadcast or run the deck to hear the current state.</div>
              <audio id="radioPlayer" controls></audio>
            </div>
          </div>
        </article>

        <article class="panel">
          <div class="panel-header">
            <div class="panel-title">Radio History</div>
          </div>
          <div class="panel-body">
            <div class="entry-list" id="radioList"></div>
          </div>
        </article>
      </section>

      <aside class="side-stack">
        <article class="panel">
          <div class="panel-header">
            <div class="panel-title">System State</div>
          </div>
          <div class="panel-body">
            <div class="kv-grid">
              <div class="metric">
                <div class="metric-label">Owner</div>
                <div class="metric-value" id="stateOwner">—</div>
              </div>
              <div class="metric">
                <div class="metric-label">Profile Sync</div>
                <div class="metric-value" id="stateProfile">—</div>
              </div>
              <div class="metric">
                <div class="metric-label">High Signal</div>
                <div class="metric-value" id="stateSignal">—</div>
              </div>
              <div class="metric">
                <div class="metric-label">Vault</div>
                <div class="metric-value" id="vaultStatus">—</div>
              </div>
            </div>
            <div style="height: 18px;"></div>
            <div class="panel-title" style="margin-bottom: 12px;">Today Focus</div>
            <ul class="list" id="todayList"></ul>
          </div>
        </article>

        <article class="panel">
          <div class="panel-header">
            <div class="panel-title">Mission Health</div>
            <div class="muted" id="healthTs">—</div>
          </div>
          <div class="panel-body">
            <div class="panel-title" style="margin-bottom: 12px;">Env Targets</div>
            <div class="entry-list" id="envList"></div>
            <div style="height: 18px;"></div>
            <div class="panel-title" style="margin-bottom: 12px;">Services</div>
            <div class="entry-list" id="serviceList"></div>
          </div>
        </article>
      </aside>

      <section class="lower-grid">
        <article class="panel">
          <div class="panel-header">
            <div class="panel-title">Live Logs</div>
            <div class="control-row">
              <select id="logSel">
                <option value="agency_metrics">agency_metrics</option>
                <option value="payment_server">payment_server</option>
                <option value="n8n">n8n</option>
                <option value="fulfiller">fulfiller</option>
                <option value="voice_stream">voice_stream</option>
              </select>
              <select id="logLines">
                <option value="120">120 lines</option>
                <option value="240" selected>240 lines</option>
                <option value="400">400 lines</option>
              </select>
            </div>
          </div>
          <div class="panel-body">
            <div class="muted" id="logMeta" style="margin-bottom: 12px;">—</div>
            <pre class="mono-block" id="logBox">loading…</pre>
          </div>
        </article>

        <article class="panel">
          <div class="panel-header">
            <div class="panel-title">NotebookLM Packets</div>
            <div class="control-row">
              <select id="packetSource">
                <option value="agency_metrics">agency_metrics</option>
                <option value="payment_server">payment_server</option>
                <option value="n8n">n8n</option>
                <option value="fulfiller">fulfiller</option>
                <option value="voice_stream">voice_stream</option>
              </select>
              <button id="makePacketBtn">make packet</button>
            </div>
          </div>
          <div class="panel-body">
            <div class="entry-list" id="packetList"></div>
          </div>
        </article>
      </section>
    </main>
  </div>
  <script src="/static/mission_control.js"></script>
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
    return JSONResponse({"source": source, "text": _tail_text(p, lines=lines)})


@app.get("/api/packets")
def api_packets(limit: int = 12):
    return JSONResponse(_list_packets(limit=limit))


@app.get("/api/radio")
def api_radio(limit: int = 12):
    return JSONResponse(_list_radio(limit=limit))


@app.get("/api/radio_deck")
def api_radio_deck():
    return JSONResponse(_radio_deck_state())


@app.post("/api/radio_deck")
def api_radio_deck_start(payload: dict):
    state = _radio_deck_state()
    if state.get("running"):
        return JSONResponse(state)

    source = payload.get("source") or "agency_metrics"
    provider = payload.get("provider") or "auto"
    tail = int(payload.get("tail") or 240)
    interval = int(payload.get("interval") or 60)
    audio = bool(payload.get("audio") or False)

    RADIO_DIR.mkdir(parents=True, exist_ok=True)
    log_path = APP_DIR.parent / ".aura" / "logs" / "radio_deck.log"
    log_path.parent.mkdir(parents=True, exist_ok=True)
    with log_path.open("a", encoding="utf-8") as log_file:
        subprocess.Popen(
            [
                sys.executable,
                str(APP_DIR / "log_radio_deck.py"),
                "--source",
                str(source),
                "--provider",
                str(provider),
                "--tail",
                str(tail),
                "--interval",
                str(interval),
                "--out",
                str(RADIO_DIR),
                *(["--audio"] if audio else []),
            ],
            cwd=str(APP_DIR),
            stdout=log_file,
            stderr=subprocess.STDOUT,
            start_new_session=True,
        )
    return JSONResponse({"ok": True, "starting": True})


@app.delete("/api/radio_deck")
def api_radio_deck_stop():
    state = _radio_deck_state()
    pid = int(state.get("pid") or 0) if str(state.get("pid") or "").isdigit() else 0
    if pid and _pid_alive(pid):
        os.kill(pid, signal.SIGTERM)
        return JSONResponse({"ok": True, "stopping": True})
    return JSONResponse({"ok": True, "stopping": False})


@app.get("/api/radio_asset/{name}")
def api_radio_asset(name: str):
    if "/" in name or "\\" in name or ".." in name:
        raise HTTPException(status_code=400, detail="invalid name")
    path = RADIO_DIR / name
    if not path.exists():
        raise HTTPException(status_code=404, detail="not found")
    return FileResponse(path)


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


@app.post("/api/make_radio")
def api_make_radio(payload: dict):
    source = payload.get("source") or "agency_metrics"
    provider = payload.get("provider") or "auto"
    tail = int(payload.get("tail") or 240)
    audio = bool(payload.get("audio") or False)

    cmd = [
        sys.executable,
        str(APP_DIR / "log_radio.py"),
        "--source",
        str(source),
        "--tail",
        str(tail),
        "--provider",
        str(provider),
        "--out",
        str(RADIO_DIR),
    ]
    if audio:
        cmd.append("--audio")

    RADIO_DIR.mkdir(parents=True, exist_ok=True)
    r = subprocess.run(cmd, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True)
    latest = _list_radio(limit=1)
    entry = latest[0] if latest else {}
    audio_url = None
    mp3_name = ((entry.get("files") or {}).get("mp3") if entry else None)
    if mp3_name:
        audio_url = f"/api/radio_asset/{mp3_name}"

    return JSONResponse(
        {
            "ok": r.returncode == 0,
            "code": r.returncode,
            "output": r.stdout[-4000:],
            "provider_used": entry.get("provider_used"),
            "audio_url": audio_url,
            "entry": entry,
        }
    )
