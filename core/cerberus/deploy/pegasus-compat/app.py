#!/usr/bin/env python3
"""Pegasus API for Cerberus.

REST/WebSocket control plane for the Pegasus mobile app and Cerberus runtime.
"""

from __future__ import annotations

import asyncio
import hashlib
import hmac
import json
import os
import secrets
import threading
import time
from datetime import date, datetime, timedelta, timezone
from pathlib import Path
from typing import Any, Optional

from fastapi import Depends, FastAPI, HTTPException, Request, Security, WebSocket, WebSocketDisconnect
from fastapi.middleware.cors import CORSMiddleware
from fastapi.security import HTTPAuthorizationCredentials, HTTPBearer
from fastapi.responses import StreamingResponse
from sse_starlette.sse import EventSourceResponse
from pydantic import BaseModel

try:
    import bcrypt as pybcrypt
except Exception:  # pragma: no cover - optional dependency for legacy hashes
    pybcrypt = None

try:
    from webauthn import (
        generate_authentication_options,
        generate_registration_options,
        options_to_json,
        verify_authentication_response,
        verify_registration_response,
    )
    from webauthn.helpers import base64url_to_bytes, bytes_to_base64url
    from webauthn.helpers.structs import (
        AuthenticatorSelectionCriteria,
        PublicKeyCredentialDescriptor,
        UserVerificationRequirement,
    )

    _HAS_WEBAUTHN = True
except Exception:  # pragma: no cover - optional until passkeys deployed
    _HAS_WEBAUTHN = False


CERBERUS_BASE_DIR = Path(os.getenv("CERBERUS_BASE_DIR", "/data/cerberus"))
CERBERUS_CONFIG_FILE = Path(
    os.getenv("CERBERUS_CONFIG_FILE", str(CERBERUS_BASE_DIR / ".cerberus" / "config.json"))
)
AUTH_DIR = CERBERUS_BASE_DIR / "auth"
USERS_FILE = AUTH_DIR / "users.json"
TOKENS_FILE = AUTH_DIR / "tokens.json"
QUEUE_BASE = CERBERUS_BASE_DIR / "hitl-queue"
TASK_QUEUE = CERBERUS_BASE_DIR / "task-queue"
ARTIFACTS = CERBERUS_BASE_DIR / "artifacts"
LOGS = CERBERUS_BASE_DIR / "logs"
TRAILS_DIR = ARTIFACTS / "trails"
PANIC_FLAG = CERBERUS_BASE_DIR / "PANIC"
COSTS_FILE = ARTIFACTS / "costs.jsonl"
AGENT_STATE = ARTIFACTS / "agent_state.json"
START_TIME = time.time()

DEFAULT_ADMIN_USER = os.getenv("PEGASUS_ADMIN_USERNAME", "yani")
_raw_admin_password = os.getenv("PEGASUS_ADMIN_PASSWORD")
if not _raw_admin_password:
    raise RuntimeError("PEGASUS_ADMIN_PASSWORD environment variable is required but not set")
DEFAULT_ADMIN_PASSWORD = _raw_admin_password
DEFAULT_ROLE = os.getenv("PEGASUS_ADMIN_ROLE", "admin")
# Primary/main agent for hierarchy: shown first in Pegasus, default for "message agent".
PRIMARY_AGENT_ID = os.getenv("PEGASUS_PRIMARY_AGENT_ID", "meziani-main")

DAILY_CAP_GLOBAL = float(os.getenv("DAILY_SPEND_CAP_USD", "8.00"))
DAILY_CAPS = {
    "global": DAILY_CAP_GLOBAL,
    "dragun-devsecops": float(os.getenv("DAILY_CAP_DEVSECOPS_USD", "3.00")),
    "dragun-growth": float(os.getenv("DAILY_CAP_GROWTH_USD", "2.00")),
    "meziani-main": float(os.getenv("DAILY_CAP_MEZIANI_MAIN_USD", "3.00")),
}
PANIC_THRESHOLD = float(os.getenv("PANIC_THRESHOLD_USD", "7.50"))
EVENTS_BUFFER_LIMIT = max(100, int(os.getenv("PEGASUS_EVENTS_BUFFER_LIMIT", "4000")))
EVENTS_REPLAY_LIMIT_DEFAULT = max(1, int(os.getenv("PEGASUS_EVENTS_REPLAY_DEFAULT_LIMIT", "200")))
EVENTS_REPLAY_LIMIT_MAX = max(100, int(os.getenv("PEGASUS_EVENTS_REPLAY_MAX_LIMIT", "1000")))
EVENTS_WS_POLL_SECS = max(0.1, float(os.getenv("PEGASUS_EVENTS_WS_POLL_SECS", "0.5")))
TRAIL_RETENTION_DAYS = max(1, int(os.getenv("PEGASUS_TRAIL_RETENTION_DAYS", "30")))

# ── WebAuthn / Passkey configuration ────────────────────────────────────
WEBAUTHN_RP_ID = os.getenv("WEBAUTHN_RP_ID", "pegasus.meziani.org")
WEBAUTHN_RP_NAME = os.getenv("WEBAUTHN_RP_NAME", "Pegasus")
WEBAUTHN_ORIGIN = os.getenv("WEBAUTHN_ORIGIN", "https://pegasus.meziani.org")
WEBAUTHN_CREDS_FILE = AUTH_DIR / "webauthn_credentials.json"
# In-memory challenge store {challenge_id: {challenge_b64, user, ts}}
_webauthn_challenges: dict[str, dict[str, Any]] = {}
WEBAUTHN_CHALLENGE_TTL = 300  # seconds


for d in [
    AUTH_DIR,
    QUEUE_BASE / "pending",
    QUEUE_BASE / "approved",
    QUEUE_BASE / "rejected",
    TASK_QUEUE,
    ARTIFACTS,
    LOGS,
    TRAILS_DIR,
]:
    d.mkdir(parents=True, exist_ok=True)


class EventHub:
    """In-process event multiplexer with JSONL persistence + cursor replay."""

    def __init__(self, trails_dir: Path, *, buffer_limit: int, retention_days: int) -> None:
        self.trails_dir = trails_dir
        self.buffer_limit = max(100, buffer_limit)
        self.retention_days = max(1, retention_days)
        self._events: list[dict[str, Any]] = []
        self._seq = 0
        self._lock = threading.Lock()
        self._load_recent()
        self._prune_old_files()

    def _trail_file(self, for_day: Optional[date] = None) -> Path:
        day = for_day or date.today()
        return self.trails_dir / f"events-{day.isoformat()}.jsonl"

    def _load_recent(self) -> None:
        loaded: list[dict[str, Any]] = []
        files = sorted(self.trails_dir.glob("events-*.jsonl"))
        for path in files[-5:]:
            try:
                for line in path.read_text().splitlines():
                    if not line.strip():
                        continue
                    item = json.loads(line)
                    if isinstance(item, dict):
                        loaded.append(item)
            except Exception:
                continue
        loaded.sort(key=lambda e: int(e.get("cursor", 0)))
        if len(loaded) > self.buffer_limit:
            loaded = loaded[-self.buffer_limit :]
        self._events = loaded
        self._seq = max((int(e.get("cursor", 0)) for e in loaded), default=0)

    def _prune_old_files(self) -> None:
        cutoff = date.today() - timedelta(days=self.retention_days)
        for path in self.trails_dir.glob("events-*.jsonl"):
            stem = path.stem  # events-YYYY-MM-DD
            if not stem.startswith("events-"):
                continue
            try:
                stamp = date.fromisoformat(stem.replace("events-", "", 1))
            except Exception:
                continue
            if stamp < cutoff:
                try:
                    path.unlink()
                except Exception:
                    continue

    @staticmethod
    def _parse_cursor(raw: Optional[str]) -> int:
        if raw is None:
            return 0
        val = str(raw).strip()
        if not val:
            return 0
        if val.startswith("evt_"):
            val = val[4:]
        try:
            return max(0, int(val))
        except Exception:
            return 0

    def latest_cursor(self) -> int:
        with self._lock:
            return self._seq

    def emit(
        self,
        *,
        kind: str,
        summary: str,
        severity: str = "info",
        agent_id: Optional[str] = None,
        session_id: Optional[str] = None,
        task_id: Optional[str] = None,
        request_id: Optional[str] = None,
        trace_id: Optional[str] = None,
        data: Optional[dict[str, Any]] = None,
        redaction_level: str = "safe",
    ) -> dict[str, Any]:
        now = datetime.now(timezone.utc).isoformat()
        with self._lock:
            self._seq += 1
            cursor = self._seq
            event = {
                "id": f"evt_{cursor:010d}",
                "cursor": cursor,
                "ts": now,
                "kind": kind,
                "severity": severity,
                "agent_id": agent_id,
                "session_id": session_id,
                "task_id": task_id,
                "request_id": request_id,
                "trace_id": trace_id,
                "summary": summary,
                "data": data or {},
                "redaction_level": redaction_level,
            }
            self._events.append(event)
            if len(self._events) > self.buffer_limit:
                self._events = self._events[-self.buffer_limit :]

        try:
            with self._trail_file().open("a") as f:
                f.write(json.dumps(event, separators=(",", ":"), default=str) + "\n")
        except Exception:
            # Never block API behavior on telemetry persistence failures.
            pass
        return event

    def replay(self, *, cursor: Optional[str] = None, limit: int = 200) -> list[dict[str, Any]]:
        since = self._parse_cursor(cursor)
        bounded = max(1, min(limit, EVENTS_REPLAY_LIMIT_MAX))
        with self._lock:
            filtered = [e for e in self._events if int(e.get("cursor", 0)) > since]
        return filtered[:bounded]


EVENT_HUB = EventHub(TRAILS_DIR, buffer_limit=EVENTS_BUFFER_LIMIT, retention_days=TRAIL_RETENTION_DAYS)


def _load_json(path: Path, default: dict) -> dict:
    if path.exists():
        try:
            return json.loads(path.read_text())
        except Exception:
            pass
    return default


def _save_json(path: Path, payload: dict) -> None:
    path.write_text(json.dumps(payload, indent=2))


def _load_users() -> dict:
    return _load_json(USERS_FILE, {})


def _save_users(users: dict) -> None:
    _save_json(USERS_FILE, users)


def _load_tokens() -> dict:
    return _load_json(TOKENS_FILE, {})


def _save_tokens(tokens: dict) -> None:
    _save_json(TOKENS_FILE, tokens)


def _hash_token(raw: str) -> str:
    return hashlib.sha256(raw.encode()).hexdigest()


def _hash_password(password: str) -> str:
    iterations = 390_000
    salt = os.urandom(16)
    digest = hashlib.pbkdf2_hmac("sha256", password.encode("utf-8"), salt, iterations)
    return (
        "pbkdf2_sha256$"
        f"{iterations}$"
        f"{salt.hex()}$"
        f"{digest.hex()}"
    )


def _verify_password(password: str, stored_hash: str) -> bool:
    if stored_hash.startswith("pbkdf2_sha256$"):
        try:
            _prefix, iter_s, salt_hex, digest_hex = stored_hash.split("$", 3)
            iterations = int(iter_s)
            salt = bytes.fromhex(salt_hex)
            expected = bytes.fromhex(digest_hex)
            computed = hashlib.pbkdf2_hmac("sha256", password.encode("utf-8"), salt, iterations)
            return hmac.compare_digest(computed, expected)
        except Exception:
            return False

    # Compatibility with legacy bcrypt hashes ($2a/$2b/$2y).
    if stored_hash.startswith("$2") and pybcrypt is not None:
        try:
            return pybcrypt.checkpw(password.encode("utf-8"), stored_hash.encode("utf-8"))
        except Exception:
            return False

    # Last-resort fallback for plain-text legacy entries.
    return hmac.compare_digest(password, stored_hash)


def _configured_agents() -> list[str]:
    if not CERBERUS_CONFIG_FILE.exists():
        return ["meziani-main", "dragun-devsecops", "dragun-growth"]
    try:
        cfg = json.loads(CERBERUS_CONFIG_FILE.read_text())
        entries = cfg.get("agents", {}).get("list", [])
        ids: list[str] = []
        for e in entries:
            if not isinstance(e, dict):
                continue
            aid = e.get("id") or e.get("name")
            if isinstance(aid, str) and aid:
                ids.append(aid)
        return ids or ["meziani-main", "dragun-devsecops", "dragun-growth"]
    except Exception:
        return ["meziani-main", "dragun-devsecops", "dragun-growth"]


def _init_default_user() -> None:
    users = _load_users()
    if users:
        return
    users[DEFAULT_ADMIN_USER] = {
        "password_hash": _hash_password(DEFAULT_ADMIN_PASSWORD),
        "role": DEFAULT_ROLE,
        "created_at": datetime.now(timezone.utc).isoformat(),
    }
    _save_users(users)


def _load_agent_state() -> dict:
    return _load_json(AGENT_STATE, {})


def _save_agent_state(state: dict) -> None:
    _save_json(AGENT_STATE, state)


def _compute_today_totals() -> dict[str, float]:
    today = date.today().isoformat()
    totals: dict[str, float] = {"global": 0.0}
    if not COSTS_FILE.exists():
        return totals
    for line in COSTS_FILE.read_text().splitlines():
        try:
            rec = json.loads(line)
            if not str(rec.get("ts", "")).startswith(today):
                continue
            agent = str(rec.get("agent_id", "unknown"))
            cost = float(rec.get("cost_usd", 0.0))
            totals["global"] = totals.get("global", 0.0) + cost
            totals[agent] = totals.get(agent, 0.0) + cost
        except Exception:
            continue
    return {k: round(v, 4) for k, v in totals.items()}


_init_default_user()

app = FastAPI(title="Pegasus API", version="2.0.0")
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)
bearer_scheme = HTTPBearer(auto_error=False)


def _authenticate_token(raw_token: str) -> Optional[dict[str, str]]:
    token_hash = _hash_token(raw_token)
    tokens = _load_tokens()
    entry = tokens.get(token_hash)
    if not entry or entry.get("revoked"):
        return None
    return {"user": entry.get("user", "unknown"), "role": entry.get("role", "user")}


def _extract_ws_token(websocket: WebSocket) -> Optional[str]:
    qp = websocket.query_params.get("token")
    if qp:
        return qp
    auth_header = websocket.headers.get("authorization", "")
    if auth_header.lower().startswith("bearer "):
        return auth_header.split(" ", 1)[1].strip()
    return None


def _emit_event(
    *,
    kind: str,
    summary: str,
    severity: str = "info",
    agent_id: Optional[str] = None,
    session_id: Optional[str] = None,
    task_id: Optional[str] = None,
    request_id: Optional[str] = None,
    trace_id: Optional[str] = None,
    data: Optional[dict[str, Any]] = None,
    redaction_level: str = "safe",
) -> Optional[dict[str, Any]]:
    try:
        return EVENT_HUB.emit(
            kind=kind,
            summary=summary,
            severity=severity,
            agent_id=agent_id,
            session_id=session_id,
            task_id=task_id,
            request_id=request_id,
            trace_id=trace_id,
            data=data,
            redaction_level=redaction_level,
        )
    except Exception:
        return None


async def require_auth(
    request: Request,
    credentials: Optional[HTTPAuthorizationCredentials] = Security(bearer_scheme),
) -> dict:
    if not credentials:
        raise HTTPException(401, "Missing Authorization header", headers={"WWW-Authenticate": "Bearer"})
    auth = _authenticate_token(credentials.credentials)
    if not auth:
        raise HTTPException(401, "Invalid API token", headers={"WWW-Authenticate": "Bearer"})
    return auth


class LoginRequest(BaseModel):
    username: str
    password: str


class TokenResponse(BaseModel):
    token: str
    user: str
    role: str
    expires_at: Optional[str] = None


class HITLRequest(BaseModel):
    task_id: str
    agent_id: str
    action: str
    blast_radius: str
    reversible: bool
    diff_preview: Optional[str] = None
    risk_note: Optional[str] = None
    risk_label: Optional[str] = None
    external_impact: Optional[str] = None
    experiment_id: Optional[str] = None
    metadata: Optional[dict] = None


class CostRecord(BaseModel):
    agent_id: str
    task_id: str
    model: str
    input_tokens: int = 0
    output_tokens: int = 0
    cost_usd: float


class TaskSubmit(BaseModel):
    agent_id: str
    description: str
    priority: Optional[str] = "normal"
    metadata: Optional[dict] = None


class EventIngest(BaseModel):
    kind: str
    summary: str
    severity: str = "info"
    agent_id: Optional[str] = None
    session_id: Optional[str] = None
    task_id: Optional[str] = None
    request_id: Optional[str] = None
    trace_id: Optional[str] = None
    data: Optional[dict] = None
    redaction_level: str = "safe"


_emit_event(
    kind="system.ready",
    summary="Pegasus API initialized",
        data={"service": "pegasus-api"},
)


@app.post("/auth/login", response_model=TokenResponse)
def login(req: LoginRequest):
    users = _load_users()
    user = users.get(req.username)
    if not user or not _verify_password(req.password, user["password_hash"]):
        _emit_event(
            kind="auth.login_failed",
            severity="warning",
            summary=f"Login failed for {req.username}",
            data={"username": req.username},
        )
        raise HTTPException(401, "Invalid username or password")
    raw_token = f"crb_{secrets.token_urlsafe(48)}"
    token_hash = _hash_token(raw_token)
    tokens = _load_tokens()
    tokens[token_hash] = {
        "user": req.username,
        "role": user.get("role", DEFAULT_ROLE),
        "created_at": datetime.now(timezone.utc).isoformat(),
        "device": "pegasus",
        "revoked": False,
    }
    _save_tokens(tokens)
    _emit_event(
        kind="auth.login",
        summary=f"{req.username} logged in",
        data={"user": req.username, "role": user.get("role", DEFAULT_ROLE)},
    )
    return TokenResponse(token=raw_token, user=req.username, role=user.get("role", DEFAULT_ROLE))


@app.post("/auth/logout")
def logout(
    credentials: HTTPAuthorizationCredentials = Security(bearer_scheme),
    auth: dict = Depends(require_auth),
):
    if credentials:
        token_hash = _hash_token(credentials.credentials)
        tokens = _load_tokens()
        if token_hash in tokens:
            tokens[token_hash]["revoked"] = True
            _save_tokens(tokens)
    _emit_event(kind="auth.logout", summary=f"{auth['user']} logged out", data={"user": auth["user"]})
    return {"status": "logged_out"}


@app.post("/auth/change-password", dependencies=[Depends(require_auth)])
def change_password(old_password: str, new_password: str, auth: dict = Depends(require_auth)):
    users = _load_users()
    user = users.get(auth["user"])
    if not user or not _verify_password(old_password, user["password_hash"]):
        raise HTTPException(401, "Wrong current password")
    user["password_hash"] = _hash_password(new_password)
    _save_users(users)
    _emit_event(
        kind="auth.password_changed",
        summary=f"Password changed for {auth['user']}",
        data={"user": auth["user"]},
    )
    return {"status": "password_changed"}


@app.get("/health")
def health():
    return {"status": "ok", "panic": PANIC_FLAG.exists(), "uptime_s": round(time.time() - START_TIME, 1)}


@app.post("/hitl/submit", status_code=201)
def submit_hitl(req: HITLRequest, auth: dict = Depends(require_auth)):
    path = QUEUE_BASE / "pending" / f"{req.task_id}.json"
    payload = req.model_dump()
    payload["submitted_at"] = datetime.now(timezone.utc).isoformat()
    payload["status"] = "pending"
    path.write_text(json.dumps(payload, indent=2))
    _emit_event(
        kind="approval.requested",
        severity="warning",
        summary=f"HITL requested for {req.task_id}",
        agent_id=req.agent_id,
        task_id=req.task_id,
        data={
            "action": req.action,
            "risk_label": req.risk_label,
            "blast_radius": req.blast_radius,
            "submitted_by": auth["user"],
        },
    )
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
            continue
    return {"status": status, "count": len(items), "items": items}


@app.get("/hitl/{item_id}", dependencies=[Depends(require_auth)])
def get_hitl_item(item_id: str):
    for s in ("pending", "approved", "rejected"):
        p = QUEUE_BASE / s / f"{item_id}.json"
        if p.exists():
            return json.loads(p.read_text())
    raise HTTPException(404, f"HITL item {item_id!r} not found")


def _move_hitl(item_id: str, from_s: str, to_s: str, note: Optional[str], actor: Optional[str] = None):
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
    _emit_event(
        kind="approval.resolved",
        severity="info" if to_s == "approved" else "warning",
        summary=f"HITL {item_id} moved to {to_s}",
        agent_id=data.get("agent_id"),
        task_id=item_id,
        data={"from": from_s, "to": to_s, "reviewer": actor, "note": note},
    )
    return {"item_id": item_id, "status": to_s}


@app.post("/hitl/approve/{item_id}")
def approve_hitl(item_id: str, note: Optional[str] = None, auth: dict = Depends(require_auth)):
    return _move_hitl(item_id, "pending", "approved", note, actor=auth["user"])


@app.post("/hitl/reject/{item_id}")
def reject_hitl(item_id: str, note: Optional[str] = None, auth: dict = Depends(require_auth)):
    return _move_hitl(item_id, "pending", "rejected", note, actor=auth["user"])


@app.post("/costs/record")
def record_cost(rec: CostRecord, auth: dict = Depends(require_auth)):
    entry = rec.model_dump()
    entry["ts"] = datetime.now(timezone.utc).isoformat()
    with COSTS_FILE.open("a") as f:
        f.write(json.dumps(entry) + "\n")
    totals = _compute_today_totals()
    _emit_event(
        kind="cost.recorded",
        summary=f"Cost recorded for {rec.agent_id}",
        agent_id=rec.agent_id,
        task_id=rec.task_id,
        data={
            "model": rec.model,
            "cost_usd": rec.cost_usd,
            "totals_usd": totals,
            "recorded_by": auth["user"],
        },
    )
    panic_triggered = False
    if totals.get("global", 0.0) >= PANIC_THRESHOLD and not PANIC_FLAG.exists():
        PANIC_FLAG.write_text(
            f"auto-triggered at ${totals['global']:.4f} on {datetime.now(timezone.utc).isoformat()}"
        )
        panic_triggered = True
        _emit_event(
            kind="panic.triggered",
            severity="critical",
            summary=f"Panic auto-triggered at ${totals.get('global', 0.0):.4f}",
            data={"reason": "cost_threshold", "totals_usd": totals},
        )
    return {"recorded": True, "panic_triggered": panic_triggered, "totals_usd": totals}


@app.get("/costs/today", dependencies=[Depends(require_auth)])
def costs_today():
    return {"date": date.today().isoformat(), "totals_usd": _compute_today_totals(), "caps_usd": DAILY_CAPS}


@app.get("/costs/status", dependencies=[Depends(require_auth)])
def costs_status():
    totals = _compute_today_totals()
    agents = {}
    for key, cap in DAILY_CAPS.items():
        spent = totals.get(key, 0.0)
        pct = (spent / cap * 100) if cap > 0 else 0.0
        agents[key] = {
            "spent_usd": round(spent, 4),
            "cap_usd": cap,
            "pct": round(pct, 1),
            "status": "exceeded" if pct >= 100 else ("warning" if pct >= 80 else "ok"),
        }
    return {"date": date.today().isoformat(), "panic_active": PANIC_FLAG.exists(), "agents": agents}


@app.get("/panic")
def panic_status():
    if PANIC_FLAG.exists():
        return {"panic": True, "reason": PANIC_FLAG.read_text()}
    return {"panic": False}


@app.post("/panic")
def trigger_panic(reason: Optional[str] = "manual", auth: dict = Depends(require_auth)):
    PANIC_FLAG.write_text(f"triggered: {reason} at {datetime.now(timezone.utc).isoformat()}")
    _emit_event(
        kind="panic.triggered",
        severity="critical",
        summary=f"Panic triggered by {auth['user']}",
        data={"reason": reason, "actor": auth["user"]},
    )
    return {"panic": True, "reason": reason}


@app.delete("/panic")
def clear_panic(auth: dict = Depends(require_auth)):
    if PANIC_FLAG.exists():
        PANIC_FLAG.unlink()
    _emit_event(
        kind="panic.cleared",
        severity="warning",
        summary=f"Panic cleared by {auth['user']}",
        data={"actor": auth["user"]},
    )
    return {"panic": False}


@app.post("/tasks/submit", status_code=201)
def submit_task(task: TaskSubmit, auth: dict = Depends(require_auth)):
    task_id = str(secrets.token_hex(8))[:8]
    qfile = TASK_QUEUE / f"{task.agent_id}.jsonl"
    entry = task.model_dump()
    entry["id"] = task_id
    entry["submitted_at"] = datetime.now(timezone.utc).isoformat()
    with qfile.open("a") as f:
        f.write(json.dumps(entry) + "\n")
    _emit_event(
        kind="task.submitted",
        summary=f"Task queued for {task.agent_id}",
        agent_id=task.agent_id,
        task_id=task_id,
        data={"priority": task.priority, "submitted_by": auth["user"]},
    )
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
            continue
    return {"agent_id": agent_id, "count": len(tasks), "tasks": tasks}


@app.post("/agents/{agent_id}/heartbeat")
def heartbeat(
    agent_id: str,
    task_id: Optional[str] = None,
    status: Optional[str] = "idle",
    auth: dict = Depends(require_auth),
):
    state = _load_agent_state()
    state[agent_id] = {
        "last_seen": datetime.now(timezone.utc).isoformat(),
        "current_task": task_id,
        "status": status,
    }
    _save_agent_state(state)
    _emit_event(
        kind="agent.heartbeat",
        summary=f"Heartbeat from {agent_id}",
        agent_id=agent_id,
        task_id=task_id,
        data={"status": status, "reported_by": auth["user"]},
    )
    return {"agent_id": agent_id, "ack": True}


@app.get("/agents", dependencies=[Depends(require_auth)])
def list_agents():
    state = _load_agent_state()
    configured = _configured_agents()
    for aid in configured:
        state.setdefault(aid, {"last_seen": None, "current_task": None, "status": "idle"})
    # Return only configured agents, primary first, so Pegasus has a stable order.
    ordered = {aid: state[aid] for aid in configured}
    return ordered


@app.get("/agents/primary", dependencies=[Depends(require_auth)])
def get_primary_agent():
    """Return the primary/main agent id for hierarchy (e.g. main orchestrator vs specialists)."""
    primary = PRIMARY_AGENT_ID if PRIMARY_AGENT_ID in _configured_agents() else None
    first = _configured_agents()[0] if _configured_agents() else None
    return {"primary_agent_id": primary or first}


@app.get("/agents/{agent_id}", dependencies=[Depends(require_auth)])
def get_agent(agent_id: str):
    state = _load_agent_state()
    if agent_id not in _configured_agents():
        raise HTTPException(404, f"Agent {agent_id} not found")
    return state.get(agent_id, {"last_seen": None, "current_task": None, "status": "idle"})


@app.post("/agents/{agent_id}/start")
def start_agent(agent_id: str, auth: dict = Depends(require_auth)):
    if agent_id not in _configured_agents():
        raise HTTPException(404, f"Agent {agent_id} not found")
    
    task_id = f"start-{agent_id}-{int(time.time())}"
    task_entry = {
        "id": task_id,
        "agent_id": agent_id,
        "action": "start",
        "submitted_at": datetime.now(timezone.utc).isoformat(),
        "submitted_by": auth["user"],
    }
    
    qfile = TASK_QUEUE / f"{agent_id}.jsonl"
    with qfile.open("a") as f:
        f.write(json.dumps(task_entry) + "\n")

    # Optimistic state update so Pegasus UI reflects immediate start.
    state = _load_agent_state()
    state[agent_id] = {
        "last_seen": datetime.now(timezone.utc).isoformat(),
        "current_task": task_id,
        "status": "running",
    }
    _save_agent_state(state)
    
    _emit_event(
        kind="agent.start_requested",
        summary=f"Agent {agent_id} start requested",
        agent_id=agent_id,
        task_id=task_id,
        data={"submitted_by": auth["user"]},
    )
    
    return {"success": True, "agent_id": agent_id, "task_id": task_id, "status": "running"}


@app.post("/agents/{agent_id}/stop")
def stop_agent(agent_id: str, auth: dict = Depends(require_auth)):
    if agent_id not in _configured_agents():
        raise HTTPException(404, f"Agent {agent_id} not found")
    
    state = _load_agent_state()
    if agent_id in state:
        state[agent_id]["status"] = "stopped"
        state[agent_id]["current_task"] = None
        state[agent_id]["last_seen"] = datetime.now(timezone.utc).isoformat()
    else:
        state[agent_id] = {
            "last_seen": datetime.now(timezone.utc).isoformat(),
            "current_task": None,
            "status": "stopped",
        }
    _save_agent_state(state)
    
    _emit_event(
        kind="agent.stop_requested",
        summary=f"Agent {agent_id} stop requested",
        agent_id=agent_id,
        data={"submitted_by": auth["user"]},
    )
    
    return {"success": True, "agent_id": agent_id, "status": "stopped"}


# Send a heartbeat this often on the stream when there are no events, so the client
# gets data and doesn't think the connection is dead (Cerberus may not push events yet).
STREAM_HEARTBEAT_INTERVAL_SEC = float(os.getenv("PEGASUS_STREAM_HEARTBEAT_SEC", "2.0"))


@app.get("/agents/{agent_id}/stream")
async def stream_agent(agent_id: str, request: Request, auth: dict = Depends(require_auth)):
    if agent_id not in _configured_agents():
        raise HTTPException(404, f"Agent {agent_id} not found")
    
    async def event_generator():
        cursor = None
        last_heartbeat = 0.0
        while True:
            if await request.is_disconnected():
                break
            
            now = time.monotonic()
            events = EVENT_HUB.replay(cursor=cursor, limit=10)
            for event in events:
                if event.get("agent_id") == agent_id or event.get("agent_id") is None:
                    yield json.dumps(event)
                cursor = event.get("cursor")
            
            # Always send a periodic heartbeat so the client receives data and shows "Connected".
            # When Cerberus does not push to this API, the stream would otherwise send nothing.
            if events or (now - last_heartbeat) >= STREAM_HEARTBEAT_INTERVAL_SEC:
                last_heartbeat = now
                yield json.dumps(
                    {
                        "kind": "heartbeat",
                        "agent_id": agent_id,
                        "ts": datetime.now(timezone.utc).isoformat(),
                    }
                )
            
            await asyncio.sleep(1)
    
    return EventSourceResponse(event_generator())


@app.get("/events/replay")
def events_replay(
    cursor: Optional[str] = None,
    limit: int = EVENTS_REPLAY_LIMIT_DEFAULT,
    auth: dict = Depends(require_auth),
):
    bounded_limit = max(1, min(limit, EVENTS_REPLAY_LIMIT_MAX))
    items = EVENT_HUB.replay(cursor=cursor, limit=bounded_limit)
    latest = EVENT_HUB.latest_cursor()
    next_cursor = items[-1]["cursor"] if items else EventHub._parse_cursor(cursor)
    return {
        "cursor": next_cursor,
        "latest_cursor": latest,
        "count": len(items),
        "items": items,
        "viewer": auth["user"],
    }


@app.post("/events/ingest", status_code=201)
def events_ingest(payload: EventIngest, auth: dict = Depends(require_auth)):
    merged = dict(payload.data or {})
    merged.setdefault("ingested_by", auth["user"])
    event = _emit_event(
        kind=payload.kind,
        summary=payload.summary,
        severity=payload.severity,
        agent_id=payload.agent_id,
        session_id=payload.session_id,
        task_id=payload.task_id,
        request_id=payload.request_id,
        trace_id=payload.trace_id,
        data=merged,
        redaction_level=payload.redaction_level,
    )
    if not event:
        raise HTTPException(500, "Failed to persist event")
    return {"accepted": True, "event": event}


@app.websocket("/events/ws")
async def events_ws(websocket: WebSocket):
    token = _extract_ws_token(websocket)
    auth = _authenticate_token(token) if token else None
    if not auth:
        await websocket.close(code=1008, reason="Unauthorized")
        return

    await websocket.accept()
    cursor = websocket.query_params.get("cursor")
    if not cursor:
        cursor = str(EVENT_HUB.latest_cursor())

    batch_raw = websocket.query_params.get("batch")
    try:
        batch = int(batch_raw) if batch_raw else EVENTS_REPLAY_LIMIT_DEFAULT
    except Exception:
        batch = EVENTS_REPLAY_LIMIT_DEFAULT
    batch = max(1, min(batch, EVENTS_REPLAY_LIMIT_MAX))

    keepalive_every = 15.0
    last_keepalive = time.monotonic()
    _emit_event(
        kind="events.stream_connected",
        summary=f"Events stream connected by {auth['user']}",
        data={"user": auth["user"]},
    )
    await websocket.send_json(
        {
            "type": "hello",
            "cursor": EVENT_HUB.latest_cursor(),
            "poll_seconds": EVENTS_WS_POLL_SECS,
            "user": auth["user"],
        }
    )

    try:
        while True:
            pending = EVENT_HUB.replay(cursor=cursor, limit=batch)
            for item in pending:
                await websocket.send_json(item)
                cursor = str(item.get("cursor", cursor))

            now = time.monotonic()
            if now - last_keepalive >= keepalive_every:
                await websocket.send_json(
                    {
                        "type": "keepalive",
                        "cursor": EVENT_HUB.latest_cursor(),
                        "ts": datetime.now(timezone.utc).isoformat(),
                    }
                )
                last_keepalive = now

            try:
                msg = await asyncio.wait_for(websocket.receive_text(), timeout=EVENTS_WS_POLL_SECS)
            except asyncio.TimeoutError:
                continue

            message = msg.strip()
            if not message:
                continue
            if message.lower() == "ping":
                await websocket.send_json({"type": "pong", "cursor": EVENT_HUB.latest_cursor()})
                continue
            if message.lower() == "latest":
                cursor = str(EVENT_HUB.latest_cursor())
                continue
            if message.startswith("cursor:"):
                requested = message.split(":", 1)[1].strip()
                if requested:
                    cursor = requested
                continue
    except WebSocketDisconnect:
        _emit_event(
            kind="events.stream_disconnected",
            summary=f"Events stream disconnected for {auth['user']}",
            data={"user": auth["user"]},
        )
    except Exception as exc:
        _emit_event(
            kind="events.stream_error",
            severity="warning",
            summary=f"Events stream error for {auth['user']}",
            data={"user": auth["user"], "error": str(exc)},
        )
        try:
            await websocket.close(code=1011, reason="Stream error")
        except Exception:
            pass


@app.get("/")
@app.get("/ui")
def root_info():
    return {
        "service": "pegasus-api",
        "status": "ok",
        "note": "Cerberus control plane API for Pegasus clients",
        "events": {
            "replay": "/events/replay",
            "ingest": "/events/ingest",
            "ws": "/events/ws?token=<bearer>",
        },
        "webauthn": _HAS_WEBAUTHN,
    }


# ═══════════════════════════════════════════════════════════════════════
# WebAuthn / Passkey endpoints
# ═══════════════════════════════════════════════════════════════════════

def _load_webauthn_creds() -> dict[str, list[dict]]:
    if not WEBAUTHN_CREDS_FILE.exists():
        return {}
    try:
        return json.loads(WEBAUTHN_CREDS_FILE.read_text())
    except Exception:
        return {}


def _save_webauthn_creds(creds: dict[str, list[dict]]) -> None:
    WEBAUTHN_CREDS_FILE.write_text(json.dumps(creds, indent=2))


def _prune_challenges() -> None:
    """Remove expired challenges."""
    now = time.time()
    expired = [k for k, v in _webauthn_challenges.items() if now - v["ts"] > WEBAUTHN_CHALLENGE_TTL]
    for k in expired:
        _webauthn_challenges.pop(k, None)


def _require_webauthn():
    if not _HAS_WEBAUTHN:
        raise HTTPException(501, "WebAuthn not available — install py_webauthn")


class WebAuthnUsernameRequest(BaseModel):
    username: str


@app.post("/auth/webauthn/register/begin")
def webauthn_register_begin(auth: dict = Depends(require_auth)):
    """Start passkey registration. Must be logged in (password-authenticated)."""
    _require_webauthn()
    _prune_challenges()
    user = auth["user"]
    user_id = user.encode("utf-8")

    existing = _load_webauthn_creds().get(user, [])
    exclude = [
        PublicKeyCredentialDescriptor(id=base64url_to_bytes(c["credential_id"]))
        for c in existing
    ]

    options = generate_registration_options(
        rp_id=WEBAUTHN_RP_ID,
        rp_name=WEBAUTHN_RP_NAME,
        user_id=user_id,
        user_name=user,
        user_display_name=user,
        exclude_credentials=exclude,
        authenticator_selection=AuthenticatorSelectionCriteria(
            user_verification=UserVerificationRequirement.REQUIRED,
        ),
    )

    challenge_id = secrets.token_urlsafe(16)
    _webauthn_challenges[challenge_id] = {
        "challenge": bytes_to_base64url(options.challenge),
        "user": user,
        "ts": time.time(),
    }

    _emit_event(
        kind="auth.webauthn_register_begin",
        summary=f"WebAuthn registration started for {user}",
        data={"user": user},
    )

    return {"challenge_id": challenge_id, "options": json.loads(options_to_json(options))}


@app.post("/auth/webauthn/register/complete")
def webauthn_register_complete(body: dict, auth: dict = Depends(require_auth)):
    """Complete passkey registration with the authenticator response."""
    _require_webauthn()

    challenge_id = body.get("challenge_id", "")
    challenge_data = _webauthn_challenges.pop(challenge_id, None)
    if not challenge_data or time.time() - challenge_data["ts"] > WEBAUTHN_CHALLENGE_TTL:
        raise HTTPException(400, "Invalid or expired challenge")

    if challenge_data["user"] != auth["user"]:
        raise HTTPException(403, "Challenge user mismatch")

    credential = body.get("credential", {})
    expected_challenge = base64url_to_bytes(challenge_data["challenge"])

    try:
        verification = verify_registration_response(
            credential=credential,
            expected_challenge=expected_challenge,
            expected_rp_id=WEBAUTHN_RP_ID,
            expected_origin=WEBAUTHN_ORIGIN,
        )
    except Exception as e:
        raise HTTPException(400, f"Registration verification failed: {e}")

    creds = _load_webauthn_creds()
    user = auth["user"]
    if user not in creds:
        creds[user] = []

    cred_id_b64 = bytes_to_base64url(verification.credential_id)
    creds[user].append({
        "credential_id": cred_id_b64,
        "public_key": bytes_to_base64url(verification.credential_public_key),
        "sign_count": verification.sign_count,
        "created_at": datetime.now(timezone.utc).isoformat(),
    })
    _save_webauthn_creds(creds)

    _emit_event(
        kind="auth.webauthn_registered",
        summary=f"Passkey registered for {user}",
        data={"user": user, "credential_id": cred_id_b64},
    )

    return {"status": "ok", "credential_id": cred_id_b64}


@app.post("/auth/webauthn/authenticate/begin")
def webauthn_authenticate_begin(req: WebAuthnUsernameRequest):
    """Start passkey authentication (no bearer token required)."""
    _require_webauthn()
    _prune_challenges()

    creds = _load_webauthn_creds()
    user_creds = creds.get(req.username, [])
    if not user_creds:
        raise HTTPException(404, "No passkeys registered for this user")

    allow_credentials = [
        PublicKeyCredentialDescriptor(id=base64url_to_bytes(c["credential_id"]))
        for c in user_creds
    ]

    options = generate_authentication_options(
        rp_id=WEBAUTHN_RP_ID,
        allow_credentials=allow_credentials,
        user_verification=UserVerificationRequirement.REQUIRED,
    )

    challenge_id = secrets.token_urlsafe(16)
    _webauthn_challenges[challenge_id] = {
        "challenge": bytes_to_base64url(options.challenge),
        "user": req.username,
        "ts": time.time(),
    }

    return {"challenge_id": challenge_id, "options": json.loads(options_to_json(options))}


@app.post("/auth/webauthn/authenticate/complete", response_model=TokenResponse)
def webauthn_authenticate_complete(body: dict):
    """Complete passkey authentication. Returns a bearer token on success."""
    _require_webauthn()

    challenge_id = body.get("challenge_id", "")
    challenge_data = _webauthn_challenges.pop(challenge_id, None)
    if not challenge_data or time.time() - challenge_data["ts"] > WEBAUTHN_CHALLENGE_TTL:
        raise HTTPException(400, "Invalid or expired challenge")

    username = challenge_data["user"]
    creds = _load_webauthn_creds()
    user_creds = creds.get(username, [])

    credential = body.get("credential", {})
    cred_id = credential.get("id", "")
    expected_challenge = base64url_to_bytes(challenge_data["challenge"])

    # Find the matching stored credential
    matched = None
    for c in user_creds:
        if c["credential_id"] == cred_id:
            matched = c
            break

    if not matched:
        raise HTTPException(401, "Unknown credential")

    try:
        verification = verify_authentication_response(
            credential=credential,
            expected_challenge=expected_challenge,
            expected_rp_id=WEBAUTHN_RP_ID,
            expected_origin=WEBAUTHN_ORIGIN,
            credential_public_key=base64url_to_bytes(matched["public_key"]),
            credential_current_sign_count=matched.get("sign_count", 0),
        )
    except Exception as e:
        _emit_event(
            kind="auth.webauthn_failed",
            severity="warning",
            summary=f"WebAuthn authentication failed for {username}",
            data={"username": username, "error": str(e)},
        )
        raise HTTPException(401, f"Authentication failed: {e}")

    # Update sign count
    matched["sign_count"] = verification.new_sign_count
    _save_webauthn_creds(creds)

    # Look up user role
    users = _load_users()
    user_entry = users.get(username, {})
    role = user_entry.get("role", DEFAULT_ROLE)

    # Issue bearer token (same as password login)
    raw_token = f"crb_{secrets.token_urlsafe(48)}"
    token_hash = _hash_token(raw_token)
    tokens = _load_tokens()
    tokens[token_hash] = {
        "user": username,
        "role": role,
        "created_at": datetime.now(timezone.utc).isoformat(),
        "device": "webauthn",
        "revoked": False,
    }
    _save_tokens(tokens)

    _emit_event(
        kind="auth.webauthn_login",
        summary=f"{username} authenticated via passkey",
        data={"user": username, "role": role, "credential_id": cred_id},
    )

    return TokenResponse(token=raw_token, user=username, role=role)


@app.get("/auth/webauthn/credentials", dependencies=[Depends(require_auth)])
def webauthn_list_credentials(auth: dict = Depends(require_auth)):
    """List registered passkeys for the authenticated user."""
    creds = _load_webauthn_creds()
    user_creds = creds.get(auth["user"], [])
    return {
        "user": auth["user"],
        "count": len(user_creds),
        "credentials": [
            {"credential_id": c["credential_id"], "created_at": c.get("created_at")}
            for c in user_creds
        ],
    }


@app.delete("/auth/webauthn/credentials/{credential_id}")
def webauthn_delete_credential(
    credential_id: str,
    auth: dict = Depends(require_auth),
):
    """Remove a registered passkey."""
    creds = _load_webauthn_creds()
    user = auth["user"]
    user_creds = creds.get(user, [])
    before = len(user_creds)
    creds[user] = [c for c in user_creds if c["credential_id"] != credential_id]
    if len(creds[user]) == before:
        raise HTTPException(404, "Credential not found")
    _save_webauthn_creds(creds)

    _emit_event(
        kind="auth.webauthn_credential_deleted",
        summary=f"Passkey removed for {user}",
        data={"user": user, "credential_id": credential_id},
    )
    return {"status": "deleted", "credential_id": credential_id}
