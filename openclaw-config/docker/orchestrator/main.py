#!/usr/bin/env python3
"""
OpenClaw Orchestrator — BMAD v6 / Dragun.app
FastAPI service: health, HITL queue, cost tracking, panic mode, agent heartbeats
Port: 8080 (proxied by Caddy)
"""

import hashlib
import hmac
import json
import os
import secrets
import time
from datetime import date, datetime, timezone
from pathlib import Path
from typing import Optional

from fastapi import Depends, FastAPI, HTTPException, Request, Security
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import HTMLResponse, JSONResponse
from fastapi.security import HTTPAuthorizationCredentials, HTTPBearer
from passlib.hash import bcrypt
from pydantic import BaseModel

# ── Paths ─────────────────────────────────────────────────────────────────────
QUEUE_BASE  = Path(os.getenv("OPENCLAW_HITL_QUEUE",     "/data/openclaw/hitl-queue"))
ARTIFACTS   = Path(os.getenv("OPENCLAW_ARTIFACTS_PATH", "/data/openclaw/artifacts"))
LOGS        = Path(os.getenv("OPENCLAW_LOGS_PATH",      "/data/openclaw/logs"))
PANIC_FLAG  = Path("/data/openclaw/PANIC")
COSTS_FILE  = ARTIFACTS / "costs.jsonl"
AGENT_STATE = ARTIFACTS / "agent_state.json"
TASK_QUEUE  = Path("/data/openclaw/task-queue")
AUTH_DIR    = Path(os.getenv("OPENCLAW_AUTH_DIR", "/data/openclaw/auth"))
USERS_FILE  = AUTH_DIR / "users.json"
TOKENS_FILE = AUTH_DIR / "tokens.json"

for d in [
    QUEUE_BASE / "pending",
    QUEUE_BASE / "approved",
    QUEUE_BASE / "rejected",
    ARTIFACTS,
    LOGS,
    TASK_QUEUE,
    AUTH_DIR,
]:
    d.mkdir(parents=True, exist_ok=True)

START_TIME = time.time()

# ── Auth System ───────────────────────────────────────────────────────────────

def _load_users() -> dict:
    if USERS_FILE.exists():
        try:
            return json.loads(USERS_FILE.read_text())
        except Exception:
            pass
    return {}

def _save_users(users: dict):
    USERS_FILE.write_text(json.dumps(users, indent=2))

def _load_tokens() -> dict:
    if TOKENS_FILE.exists():
        try:
            return json.loads(TOKENS_FILE.read_text())
        except Exception:
            pass
    return {}

def _save_tokens(tokens: dict):
    TOKENS_FILE.write_text(json.dumps(tokens, indent=2))

def _init_default_user():
    """Create default admin user if no users exist."""
    users = _load_users()
    if not users:
        default_pw = os.getenv("OPENCLAW_ADMIN_PASSWORD", "openclaw2026")
        users["yani"] = {
            "password_hash": bcrypt.hash(default_pw),
            "role": "admin",
            "created_at": datetime.now(timezone.utc).isoformat(),
        }
        _save_users(users)

_init_default_user()

bearer_scheme = HTTPBearer(auto_error=False)

def _hash_token(raw: str) -> str:
    return hashlib.sha256(raw.encode()).hexdigest()

async def require_auth(
    request: Request,
    credentials: Optional[HTTPAuthorizationCredentials] = Security(bearer_scheme),
) -> dict:
    """Validate Bearer token. Internal network (agent containers) bypass auth."""
    client = request.client.host if request.client else ""
    if client in ("127.0.0.1", "::1") or client.startswith("172.") or client.startswith("10."):
        return {"user": "_internal", "role": "agent"}

    if not credentials:
        raise HTTPException(401, "Missing Authorization header", headers={"WWW-Authenticate": "Bearer"})

    token_hash = _hash_token(credentials.credentials)
    tokens = _load_tokens()
    entry = tokens.get(token_hash)
    if not entry:
        raise HTTPException(401, "Invalid API token", headers={"WWW-Authenticate": "Bearer"})

    if entry.get("revoked"):
        raise HTTPException(401, "Token revoked")

    return {"user": entry["user"], "role": entry.get("role", "user")}

# ── Cost caps (from env or defaults) ──────────────────────────────────────────
DAILY_CAPS = {
    "global":    float(os.getenv("DAILY_SPEND_CAP_USD", "5.00")),
    "devsecops": 3.00,
    "growth":    2.00,
}
PANIC_THRESHOLD = 4.50

app = FastAPI(title="OpenClaw Orchestrator", version="1.0.0")

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)


# ── Auth Endpoints ────────────────────────────────────────────────────────────

class LoginRequest(BaseModel):
    username: str
    password: str

class TokenResponse(BaseModel):
    token: str
    user: str
    role: str
    expires_at: Optional[str] = None

@app.post("/auth/login", response_model=TokenResponse)
def login(req: LoginRequest):
    users = _load_users()
    user = users.get(req.username)
    if not user or not bcrypt.verify(req.password, user["password_hash"]):
        raise HTTPException(401, "Invalid username or password")

    raw_token = f"oc_{secrets.token_urlsafe(48)}"
    token_hash = _hash_token(raw_token)
    tokens = _load_tokens()
    tokens[token_hash] = {
        "user": req.username,
        "role": user["role"],
        "created_at": datetime.now(timezone.utc).isoformat(),
        "device": "pegasus",
        "revoked": False,
    }
    _save_tokens(tokens)
    return TokenResponse(token=raw_token, user=req.username, role=user["role"])


@app.post("/auth/logout", dependencies=[Depends(require_auth)])
def logout(request: Request, credentials: HTTPAuthorizationCredentials = Security(bearer_scheme)):
    if credentials:
        token_hash = _hash_token(credentials.credentials)
        tokens = _load_tokens()
        if token_hash in tokens:
            tokens[token_hash]["revoked"] = True
            _save_tokens(tokens)
    return {"status": "logged_out"}


@app.post("/auth/change-password", dependencies=[Depends(require_auth)])
def change_password(
    old_password: str,
    new_password: str,
    auth: dict = Depends(require_auth),
):
    users = _load_users()
    user = users.get(auth["user"])
    if not user or not bcrypt.verify(old_password, user["password_hash"]):
        raise HTTPException(401, "Wrong current password")
    user["password_hash"] = bcrypt.hash(new_password)
    _save_users(users)
    return {"status": "password_changed"}


# ── Health (public — no auth required) ────────────────────────────────────────

@app.get("/health")
def health():
    return {
        "status":   "ok",
        "panic":    PANIC_FLAG.exists(),
        "uptime_s": round(time.time() - START_TIME, 1),
    }


# ── HITL Queue ────────────────────────────────────────────────────────────────

class HITLRequest(BaseModel):
    task_id:        str
    agent_id:       str
    action:         str
    blast_radius:   str
    reversible:     bool
    diff_preview:   Optional[str] = None
    risk_note:      Optional[str] = None
    risk_label:     Optional[str] = None
    external_impact:Optional[str] = None
    experiment_id:  Optional[str] = None
    metadata:       Optional[dict] = None


@app.post("/hitl/submit", status_code=201, dependencies=[Depends(require_auth)])
def submit_hitl(req: HITLRequest):
    path = QUEUE_BASE / "pending" / f"{req.task_id}.json"
    payload = req.model_dump()
    payload["submitted_at"] = datetime.now(timezone.utc).isoformat()
    payload["status"] = "pending"
    path.write_text(json.dumps(payload, indent=2))
    return {"item_id": req.task_id, "status": "pending"}


@app.get("/hitl/queue", dependencies=[Depends(require_auth)])
def list_queue(status: str = "pending"):
    allowed = {"pending", "approved", "rejected"}
    if status not in allowed:
        raise HTTPException(400, f"status must be one of {allowed}")
    items = []
    for f in sorted((QUEUE_BASE / status).glob("*.json")):
        try:
            items.append(json.loads(f.read_text()))
        except Exception:
            pass
    return {"status": status, "count": len(items), "items": items}


@app.get("/hitl/{item_id}", dependencies=[Depends(require_auth)])
def get_hitl_item(item_id: str):
    for s in ("pending", "approved", "rejected"):
        p = QUEUE_BASE / s / f"{item_id}.json"
        if p.exists():
            return json.loads(p.read_text())
    raise HTTPException(404, f"HITL item {item_id!r} not found")


@app.post("/hitl/approve/{item_id}", dependencies=[Depends(require_auth)])
def approve_hitl(item_id: str, note: Optional[str] = None):
    return _move_hitl(item_id, "pending", "approved", note)


@app.post("/hitl/reject/{item_id}", dependencies=[Depends(require_auth)])
def reject_hitl(item_id: str, note: Optional[str] = None):
    return _move_hitl(item_id, "pending", "rejected", note)


def _move_hitl(item_id: str, from_s: str, to_s: str, note: Optional[str]):
    src = QUEUE_BASE / from_s / f"{item_id}.json"
    if not src.exists():
        raise HTTPException(404, f"HITL item {item_id!r} not in {from_s}")
    data = json.loads(src.read_text())
    data["status"] = to_s
    data[f"{to_s}_at"] = datetime.now(timezone.utc).isoformat()
    if note:
        data["reviewer_note"] = note
    dst = QUEUE_BASE / to_s / f"{item_id}.json"
    dst.write_text(json.dumps(data, indent=2))
    src.unlink()
    return {"item_id": item_id, "status": to_s}


# ── Cost Tracking ─────────────────────────────────────────────────────────────

class CostRecord(BaseModel):
    agent_id:     str
    task_id:      str
    model:        str
    input_tokens: int
    output_tokens:int
    cost_usd:     float


@app.post("/costs/record", dependencies=[Depends(require_auth)])
def record_cost(rec: CostRecord):
    entry = rec.model_dump()
    entry["ts"] = datetime.now(timezone.utc).isoformat()
    with COSTS_FILE.open("a") as f:
        f.write(json.dumps(entry) + "\n")
    totals = _compute_today_totals()
    panic_triggered = False
    if totals.get("global", 0.0) >= PANIC_THRESHOLD and not PANIC_FLAG.exists():
        PANIC_FLAG.write_text(
            f"auto-triggered at ${totals['global']:.4f} on "
            f"{datetime.now(timezone.utc).isoformat()}"
        )
        panic_triggered = True
    return {"recorded": True, "panic_triggered": panic_triggered, "totals_usd": totals}


@app.get("/costs/today", dependencies=[Depends(require_auth)])
def costs_today():
    return {
        "date":       date.today().isoformat(),
        "totals_usd": _compute_today_totals(),
        "caps_usd":   DAILY_CAPS,
    }


@app.get("/costs/status", dependencies=[Depends(require_auth)])
def costs_status():
    totals = _compute_today_totals()
    agents = {}
    for key, cap in DAILY_CAPS.items():
        spent = totals.get(key, 0.0)
        pct   = (spent / cap * 100) if cap > 0 else 0.0
        agents[key] = {
            "spent_usd": round(spent, 4),
            "cap_usd":   cap,
            "pct":       round(pct, 1),
            "status":    "exceeded" if pct >= 100 else ("warning" if pct >= 80 else "ok"),
        }
    return {
        "date":         date.today().isoformat(),
        "panic_active": PANIC_FLAG.exists(),
        "agents":       agents,
    }


def _compute_today_totals() -> dict:
    today = date.today().isoformat()
    totals: dict[str, float] = {"global": 0.0}
    if not COSTS_FILE.exists():
        return totals
    for line in COSTS_FILE.read_text().splitlines():
        try:
            rec = json.loads(line)
            if rec.get("ts", "").startswith(today):
                agent = rec.get("agent_id", "unknown")
                cost  = float(rec.get("cost_usd", 0))
                totals["global"]         = totals.get("global", 0.0) + cost
                totals[agent]            = totals.get(agent,  0.0) + cost
        except Exception:
            pass
    return {k: round(v, 4) for k, v in totals.items()}


# ── Panic Mode ────────────────────────────────────────────────────────────────

@app.get("/panic")
def panic_status():
    if PANIC_FLAG.exists():
        return {"panic": True, "reason": PANIC_FLAG.read_text()}
    return {"panic": False}


@app.post("/panic", dependencies=[Depends(require_auth)])
def trigger_panic(reason: Optional[str] = "manual"):
    PANIC_FLAG.write_text(
        f"triggered: {reason} at {datetime.now(timezone.utc).isoformat()}"
    )
    return {"panic": True, "reason": reason}


@app.delete("/panic", dependencies=[Depends(require_auth)])
def clear_panic():
    if PANIC_FLAG.exists():
        PANIC_FLAG.unlink()
    return {"panic": False}


# ── Task Queue ────────────────────────────────────────────────────────────────

class TaskSubmit(BaseModel):
    agent_id:    str
    description: str
    priority:    Optional[str] = "normal"
    metadata:    Optional[dict] = None


@app.post("/tasks/submit", status_code=201, dependencies=[Depends(require_auth)])
def submit_task(task: TaskSubmit):
    import uuid
    task_id  = str(uuid.uuid4())[:8]
    qfile    = TASK_QUEUE / f"{task.agent_id}.jsonl"
    entry    = task.model_dump()
    entry["id"]          = task_id
    entry["submitted_at"] = datetime.now(timezone.utc).isoformat()
    with qfile.open("a") as f:
        f.write(json.dumps(entry) + "\n")
    return {"task_id": task_id, "agent_id": task.agent_id, "status": "queued"}


@app.get("/tasks/queue/{agent_id}", dependencies=[Depends(require_auth)])
def get_task_queue(agent_id: str):
    qfile = TASK_QUEUE / f"{agent_id}.jsonl"
    if not qfile.exists():
        return {"agent_id": agent_id, "count": 0, "tasks": []}
    tasks = []
    for line in qfile.read_text().splitlines():
        try:
            tasks.append(json.loads(line))
        except Exception:
            pass
    return {"agent_id": agent_id, "count": len(tasks), "tasks": tasks}


# ── Agent Heartbeats ──────────────────────────────────────────────────────────

@app.post("/agents/{agent_id}/heartbeat", dependencies=[Depends(require_auth)])
def heartbeat(agent_id: str, task_id: Optional[str] = None, status: Optional[str] = "idle"):
    state = _load_agent_state()
    state[agent_id] = {
        "last_seen":    datetime.now(timezone.utc).isoformat(),
        "current_task": task_id,
        "status":       status,
    }
    AGENT_STATE.write_text(json.dumps(state, indent=2))
    return {"agent_id": agent_id, "ack": True}


@app.get("/agents", dependencies=[Depends(require_auth)])
def list_agents():
    return _load_agent_state()


def _load_agent_state() -> dict:
    if AGENT_STATE.exists():
        try:
            return json.loads(AGENT_STATE.read_text())
        except Exception:
            pass
    return {}


# ── Dashboard UI ──────────────────────────────────────────────────────────────

@app.get("/ui", response_class=HTMLResponse)
@app.get("/", response_class=HTMLResponse)
def dashboard():
    return HTMLResponse(content=_DASHBOARD_HTML)


_DASHBOARD_HTML = """<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width,initial-scale=1">
<title>OpenClaw — ops.meziani.org</title>
<style>
  :root{--bg:#0d1117;--surface:#161b22;--border:#30363d;--text:#e6edf3;--muted:#8b949e;
    --green:#3fb950;--yellow:#d29922;--red:#f85149;--blue:#58a6ff;--purple:#bc8cff}
  *{box-sizing:border-box;margin:0;padding:0}
  body{background:var(--bg);color:var(--text);font-family:'SF Mono',Consolas,monospace;font-size:13px}
  header{background:var(--surface);border-bottom:1px solid var(--border);padding:12px 24px;
    display:flex;align-items:center;justify-content:space-between}
  header h1{font-size:16px;font-weight:600;color:var(--blue)}
  header span{color:var(--muted);font-size:11px}
  #panic-btn{background:var(--red);color:#fff;border:none;padding:6px 16px;border-radius:6px;
    cursor:pointer;font-family:inherit;font-size:12px;font-weight:600}
  #panic-btn.clear{background:var(--green)}
  .grid{display:grid;grid-template-columns:1fr 1fr;gap:16px;padding:20px 24px}
  @media(max-width:760px){.grid{grid-template-columns:1fr}}
  .card{background:var(--surface);border:1px solid var(--border);border-radius:8px;padding:16px}
  .card h2{font-size:12px;text-transform:uppercase;letter-spacing:.08em;color:var(--muted);margin-bottom:12px}
  .card.full{grid-column:1/-1}
  .badge{display:inline-block;padding:2px 8px;border-radius:4px;font-size:11px;font-weight:600}
  .ok{background:#238636;color:#fff} .warn{background:#9e6a03;color:#fff}
  .error{background:#b62324;color:#fff} .idle{background:#21262d;color:var(--muted)}
  table{width:100%;border-collapse:collapse}
  th{text-align:left;color:var(--muted);font-size:11px;padding:4px 8px;border-bottom:1px solid var(--border)}
  td{padding:6px 8px;border-bottom:1px solid #21262d;vertical-align:middle}
  .approve-btn{background:#238636;color:#fff;border:none;padding:3px 10px;border-radius:4px;
    cursor:pointer;font-size:11px;font-family:inherit;margin-right:4px}
  .reject-btn{background:var(--red);color:#fff;border:none;padding:3px 10px;border-radius:4px;
    cursor:pointer;font-size:11px;font-family:inherit}
  .bar-wrap{background:#21262d;border-radius:4px;height:8px;margin-top:4px}
  .bar{height:8px;border-radius:4px;transition:width .4s}
  .stat-row{display:flex;justify-content:space-between;margin-bottom:8px;align-items:center}
  .stat-label{color:var(--muted)}
  .stat-val{font-weight:600}
  pre{background:#0d1117;border:1px solid var(--border);border-radius:4px;padding:10px;
    overflow-x:auto;font-size:11px;max-height:200px;overflow-y:auto;white-space:pre-wrap}
  #refresh-ts{color:var(--muted);font-size:10px}
  .panic-banner{background:#b62324;color:#fff;padding:8px 24px;font-weight:600;text-align:center}
</style>
</head>
<body>
<div id="panic-banner" style="display:none" class="panic-banner">⚠ PANIC MODE ACTIVE — agents halted</div>
<header>
  <h1>⚡ OpenClaw Dashboard</h1>
  <div style="display:flex;align-items:center;gap:16px">
    <span id="refresh-ts">loading...</span>
    <button id="panic-btn" onclick="togglePanic()">Trigger Panic</button>
  </div>
</header>

<div class="grid">
  <!-- Agents -->
  <div class="card">
    <h2>Agents</h2>
    <table><thead><tr><th>Agent</th><th>Status</th><th>Task</th><th>Last seen</th></tr></thead>
    <tbody id="agents-body"><tr><td colspan="4" style="color:var(--muted)">loading...</td></tr></tbody>
    </table>
  </div>

  <!-- Costs -->
  <div class="card">
    <h2>Today's Costs</h2>
    <div id="costs-body"><span style="color:var(--muted)">loading...</span></div>
  </div>

  <!-- HITL Queue -->
  <div class="card full">
    <h2>HITL Queue <span id="hitl-count" class="badge idle">0</span></h2>
    <table><thead><tr><th>ID</th><th>Agent</th><th>Action</th><th>Blast radius</th><th>Risk</th><th>Submitted</th><th></th></tr></thead>
    <tbody id="hitl-body"><tr><td colspan="7" style="color:var(--muted)">No pending items</td></tr></tbody>
    </table>
  </div>

  <!-- Health -->
  <div class="card">
    <h2>System Health</h2>
    <div id="health-body"><span style="color:var(--muted)">loading...</span></div>
  </div>

  <!-- Submit Task -->
  <div class="card">
    <h2>Submit Task</h2>
    <div style="display:flex;flex-direction:column;gap:8px">
      <select id="task-agent" style="background:#21262d;color:var(--text);border:1px solid var(--border);border-radius:4px;padding:6px;font-family:inherit">
        <option value="devsecops">devsecops</option>
        <option value="growth">growth</option>
      </select>
      <textarea id="task-desc" rows="3" placeholder="Describe the task..."
        style="background:#21262d;color:var(--text);border:1px solid var(--border);border-radius:4px;
               padding:6px;font-family:inherit;resize:vertical"></textarea>
      <button onclick="submitTask()" style="background:var(--blue);color:#000;border:none;padding:8px;
        border-radius:4px;cursor:pointer;font-family:inherit;font-weight:600">Submit Task</button>
      <div id="task-result" style="color:var(--green);font-size:11px"></div>
    </div>
  </div>
</div>

<script>
const BASE = '';
let panicActive = false;

async function api(method, path, body) {
  const opts = {method, headers:{'Content-Type':'application/json'}};
  if(body) opts.body = JSON.stringify(body);
  const r = await fetch(BASE+path, opts);
  return r.json();
}

function badge(status) {
  const map = {ok:'ok',idle:'idle',running:'ok',warning:'warn',exceeded:'error',
                error:'error',waiting_hitl:'warn'};
  const cls = map[status]||'idle';
  return `<span class="badge ${cls}">${status}</span>`;
}

function timeAgo(iso) {
  if(!iso) return '—';
  const s = Math.floor((Date.now()-new Date(iso))/1000);
  if(s<60) return s+'s ago';
  if(s<3600) return Math.floor(s/60)+'m ago';
  return Math.floor(s/3600)+'h ago';
}

async function refreshAgents() {
  const data = await api('GET','/agents');
  const tbody = document.getElementById('agents-body');
  if(!Object.keys(data).length){
    tbody.innerHTML='<tr><td colspan="4" style="color:var(--muted)">No agents connected yet</td></tr>';return;
  }
  tbody.innerHTML = Object.entries(data).map(([id,a])=>
    `<tr><td><b>${id}</b></td><td>${badge(a.status||'unknown')}</td>
     <td style="color:var(--muted);font-size:11px">${a.current_task||'—'}</td>
     <td style="color:var(--muted)">${timeAgo(a.last_seen)}</td></tr>`
  ).join('');
}

async function refreshCosts() {
  const data = await api('GET','/costs/status');
  const el = document.getElementById('costs-body');
  let html = '';
  for(const [key,v] of Object.entries(data.agents||{})) {
    const pct = Math.min(v.pct,100);
    const color = v.status==='exceeded'?'var(--red)':v.status==='warning'?'var(--yellow)':'var(--green)';
    html += `<div class="stat-row"><span class="stat-label">${key}</span>
      <span class="stat-val" style="color:${color}">$${v.spent_usd.toFixed(4)} / $${v.cap_usd}</span></div>
      <div class="bar-wrap"><div class="bar" style="width:${pct}%;background:${color}"></div></div>
      <div style="height:10px"></div>`;
  }
  el.innerHTML = html || '<span style="color:var(--muted)">No spend today</span>';
}

async function refreshHITL() {
  const data = await api('GET','/hitl/queue?status=pending');
  const tbody = document.getElementById('hitl-body');
  const count = data.count||0;
  const badge_el = document.getElementById('hitl-count');
  badge_el.textContent = count;
  badge_el.className = 'badge '+(count>0?'warn':'idle');
  if(!count){
    tbody.innerHTML='<tr><td colspan="7" style="color:var(--muted)">No pending items</td></tr>';return;
  }
  tbody.innerHTML = (data.items||[]).map(item=>
    `<tr>
      <td style="font-size:11px;color:var(--muted)">${item.task_id}</td>
      <td>${item.agent_id||'—'}</td>
      <td title="${item.diff_preview||''}">${item.action}</td>
      <td>${badge(item.blast_radius||'?')}</td>
      <td>${item.risk_label?`<span class="badge ${item.risk_label==='SAFE'?'ok':item.risk_label==='BLOCKED'?'error':'warn'}">${item.risk_label}</span>`:'—'}</td>
      <td style="color:var(--muted)">${timeAgo(item.submitted_at)}</td>
      <td>
        <button class="approve-btn" onclick="hitlAction('${item.task_id}','approve')">Approve</button>
        <button class="reject-btn"  onclick="hitlAction('${item.task_id}','reject')">Reject</button>
      </td>
    </tr>`
  ).join('');
}

async function refreshHealth() {
  const data = await api('GET','/health');
  panicActive = data.panic;
  document.getElementById('panic-banner').style.display = data.panic?'block':'none';
  const btn = document.getElementById('panic-btn');
  btn.textContent = data.panic?'Clear Panic':'Trigger Panic';
  btn.className = data.panic?'clear':'';
  document.getElementById('health-body').innerHTML =
    `<div class="stat-row"><span class="stat-label">Status</span>${badge('ok')}</div>
     <div class="stat-row"><span class="stat-label">Panic</span>${badge(data.panic?'error':'ok')}</div>
     <div class="stat-row"><span class="stat-label">Uptime</span><span class="stat-val">${Math.floor((data.uptime_s||0)/60)}m</span></div>`;
}

async function hitlAction(id, action) {
  await api('POST',`/hitl/${action}/${id}`);
  refreshHITL();
}

async function togglePanic() {
  if(panicActive) await api('DELETE','/panic');
  else await api('POST','/panic?reason=manual+dashboard');
  refreshAll();
}

async function submitTask() {
  const agent = document.getElementById('task-agent').value;
  const desc  = document.getElementById('task-desc').value.trim();
  const res_el= document.getElementById('task-result');
  if(!desc){res_el.innerHTML='<span style="color:var(--red)">Description required</span>';return;}
  const r = await api('POST','/tasks/submit',{agent_id:agent,description:desc});
  res_el.innerHTML = `<span style="color:var(--green)">Queued: ${r.task_id}</span>`;
  document.getElementById('task-desc').value='';
}

async function refreshAll() {
  await Promise.all([refreshAgents(),refreshCosts(),refreshHITL(),refreshHealth()]);
  document.getElementById('refresh-ts').textContent='Updated '+new Date().toLocaleTimeString();
}

refreshAll();
setInterval(refreshAll, 15000);
</script>
</body>
</html>"""
