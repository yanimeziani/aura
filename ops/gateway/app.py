"""
Aura Syncing Gateway — single entry for IDEs, TUIs, and LLM clients (Cursor, Gemini CLI, Groq, etc.).
- Vault-backed API keys; no keys in clients.
- OpenAI-compatible /v1/chat/completions for Cursor and other tools.
- Session sync: shared context across IDE / TUI / CLI (GET/POST /sync/session).
Run: uvicorn gateway.app:app --host 0.0.0.0 --port 8765
"""
import os
import json
from pathlib import Path
from typing import Any, Optional

import httpx
from fastapi import FastAPI, HTTPException, Request, Header
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse
from pydantic import BaseModel

try:
    from gateway.session_store import get_session, set_session, delete_session
except ImportError:
    from session_store import get_session, set_session, delete_session

app = FastAPI(title="Aura Syncing Gateway", version="0.2.0")

app.add_middleware(
    CORSMiddleware,
    allow_origins=["http://localhost:3003", "http://127.0.0.1:3003"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

VAULT_FILE = Path(os.environ.get("AURA_VAULT_FILE", "/home/yani/Aura/vault/aura-vault.json"))
OLLAMA_BASE = os.environ.get("OLLAMA_BASE_URL", "http://127.0.0.1:11434")

_LOCAL_MODEL_PREFIXES = ("llama", "qwen", "mistral", "phi", "deepseek", "nomic", "gemma")


def load_vault() -> dict[str, str]:
    if not VAULT_FILE.exists():
        return {}
    try:
        with open(VAULT_FILE, "r") as f:
            return json.load(f)
    except (json.JSONDecodeError, OSError):
        return {}


def _groq_base() -> str:
    return os.environ.get("OPENAI_API_BASE", "https://api.groq.com/openai/v1")


def _groq_key(vault: dict[str, str]) -> Optional[str]:
    return vault.get("GROQ_API_KEY") or os.environ.get("GROQ_API_KEY")


def _gemini_key(vault: dict[str, str]) -> Optional[str]:
    return vault.get("GEMINI_API_KEY") or os.environ.get("GEMINI_API_KEY")

def _clean_str(v: Any) -> Optional[str]:
    if v is None:
        return None
    if isinstance(v, str):
        s = v.strip()
        return s if s else None
    return None


def _clean_model(v: Any) -> Optional[str]:
    s = _clean_str(v)
    if not s:
        return None
    if s.lower() in {"none", "null", "undefined"}:
        return None
    return s


# --- Health & discovery ---

@app.get("/health")
def health():
    return {"status": "ok", "service": "aura-gateway"}


@app.get("/health/services")
async def health_services():
    """Probe service availability via raw TCP socket connect."""
    import asyncio, socket

    async def _tcp_probe(host: str, port: int, timeout: float = 1.0) -> str:
        try:
            _, writer = await asyncio.wait_for(
                asyncio.open_connection(host, port), timeout=timeout
            )
            writer.close()
            await writer.wait_closed()
            return "online"
        except Exception:
            return "offline"

    _SERVICES = [
        ("Gateway",       "127.0.0.1", 8765),
        ("Cerberus",      "127.0.0.1", 3000),
        ("Aura API",      "127.0.0.1", 3001),
        ("Aura Flow",     "127.0.0.1", 3002),
        ("Ollama",        "127.0.0.1", 11434),
        ("Pegasus API",   "127.0.0.1", 8080),
        ("Dashboard",     "127.0.0.1", 3003),
    ]

    results = await asyncio.gather(
        *[_tcp_probe(h, p) for _, h, p in _SERVICES]
    )
    return {
        "services": [
            {"name": name, "port": port, "status": status}
            for (name, _, port), status in zip(_SERVICES, results)
        ]
    }


@app.get("/providers")
def providers():
    v = load_vault()
    return {
        "providers": [
            {"id": "ollama", "enabled": True, "openai_compatible": True, "mesh": True},
            {"id": "groq", "enabled": bool(_groq_key(v)), "openai_compatible": True, "mesh": False},
            {"id": "gemini", "enabled": bool(_gemini_key(v)), "openai_compatible": False, "mesh": False},
        ]
    }


# --- Vault token auth ---

class TokenRequest(BaseModel):
    token: str


def _check_vault_token(token: str) -> bool:
    vault = load_vault()
    expected = vault.get("AURA_VAULT_TOKEN")
    return bool(expected and token == expected)


@app.post("/api/validate-token")
def validate_token(req: TokenRequest):
    """Validate an operator vault token for dashboard access."""
    vault = load_vault()
    expected = vault.get("AURA_VAULT_TOKEN")
    if not expected or req.token != expected:
        raise HTTPException(status_code=401, detail="Invalid vault token")
    return {"valid": True, "owner": vault.get("OWNER_EMAIL", "operator")}


# --- Model discovery (mesh-first) ---

@app.get("/v1/models")
async def list_models():
    """Unified model list: Ollama (mesh) first, then cloud providers."""
    models: list[dict] = []
    # Try Ollama
    try:
        async with httpx.AsyncClient(timeout=5.0) as client:
            r = await client.get(f"{OLLAMA_BASE}/api/tags")
            if r.status_code == 200:
                for m in r.json().get("models", []):
                    models.append({
                        "id": m.get("name", "unknown"),
                        "source": "ollama",
                        "mesh": True,
                        "size": m.get("size"),
                    })
    except Exception:
        pass
    # Add Groq models if key exists
    vault = load_vault()
    if _groq_key(vault):
        for mid in ["llama-3.3-70b-versatile", "llama-3.1-8b-instant", "mixtral-8x7b-32768"]:
            models.append({"id": mid, "source": "groq", "mesh": False})
    return {"object": "list", "data": models}


# --- Embeddings proxy (Ollama) ---

@app.post("/v1/embeddings")
async def embeddings(request: Request):
    """Proxy embeddings to local Ollama (nomic-embed-text or similar)."""
    body = await request.json()
    model = body.get("model", "nomic-embed-text")
    payload = {"model": model, "input": body.get("input", "")}
    async with httpx.AsyncClient(timeout=60.0) as client:
        try:
            r = await client.post(f"{OLLAMA_BASE}/v1/embeddings", json=payload)
            r.raise_for_status()
            return JSONResponse(content=r.json(), status_code=r.status_code)
        except Exception as e:
            raise HTTPException(status_code=502, detail=f"Embedding error: {type(e).__name__}")


# --- OpenAI-compatible chat (mesh-first: Ollama → Groq fallback) ---

class ChatMessage(BaseModel):
    role: str
    content: Optional[str] = None


class ChatCompletionRequest(BaseModel):
    model: Optional[str] = None
    messages: list[ChatMessage]
    stream: bool = False
    max_tokens: Optional[int] = None
    temperature: Optional[float] = None


def _is_local_model(model: str) -> bool:
    """Check if a model name implies it should run on local Ollama mesh."""
    lower = model.lower()
    return any(lower.startswith(p) for p in _LOCAL_MODEL_PREFIXES)


@app.post("/v1/chat/completions")
async def chat_completions(request: Request):
    """Mesh-first proxy: Ollama first, Groq fallback. Cursor/CLI set base URL here."""
    body = await request.json()
    vault = load_vault()

    model = (
        _clean_model(body.get("model"))
        or _clean_model(vault.get("OPENAI_MODEL_NAME"))
        or _clean_model(os.environ.get("OPENAI_MODEL_NAME"))
        or "llama3.2"
    )

    payload = {
        "model": model,
        "messages": body.get("messages", []),
        "stream": body.get("stream", False),
        "max_tokens": body.get("max_tokens"),
        "temperature": body.get("temperature"),
    }
    payload = {k: v for k, v in payload.items() if v is not None}

    # Mesh-first: always try Ollama first for local models, or as primary path
    use_ollama = _is_local_model(model)
    api_key = _groq_key(vault)

    if use_ollama or not api_key:
        # Try Ollama first
        try:
            async with httpx.AsyncClient(timeout=300.0) as client:
                r = await client.post(
                    f"{OLLAMA_BASE}/v1/chat/completions",
                    json=payload,
                    headers={"Content-Type": "application/json"},
                )
                r.raise_for_status()
                return JSONResponse(content=r.json(), status_code=r.status_code)
        except Exception:
            # If explicitly local model and Ollama fails, error out
            if use_ollama and not api_key:
                raise HTTPException(status_code=502, detail="Ollama unreachable and no cloud fallback configured")
            # Otherwise fall through to Groq

    # Groq fallback (or primary if not a local model and Groq key exists)
    if api_key:
        url = f"{_groq_base().rstrip('/')}/chat/completions"
        headers = {
            "Authorization": f"Bearer {api_key}",
            "Content-Type": "application/json",
        }
        async with httpx.AsyncClient(timeout=300.0) as client:
            try:
                r = await client.post(url, json=payload, headers=headers)
                r.raise_for_status()
                return JSONResponse(content=r.json(), status_code=r.status_code)
            except httpx.HTTPStatusError as e:
                raise HTTPException(
                    status_code=e.response.status_code,
                    detail=f"Upstream provider error (HTTP {e.response.status_code})",
                )
            except Exception as e:
                raise HTTPException(status_code=502, detail=f"Gateway error: {type(e).__name__}")

    raise HTTPException(status_code=503, detail="No AI provider available")


# --- Session sync (IDE / TUI / CLI shared context) ---

class SessionPayload(BaseModel):
    workspace_id: str
    payload: dict[str, Any] = {}


@app.get("/sync/session/{workspace_id}")
def sync_get(workspace_id: str):
    """Retrieve synced session for this workspace (IDE/TUI/CLI)."""
    out = get_session(workspace_id)
    if out is None:
        return {"workspace_id": workspace_id, "payload": None}
    return {"workspace_id": workspace_id, "payload": out}


@app.post("/sync/session")
def sync_post(session: SessionPayload):
    """Store synced session for this workspace. All clients can read it."""
    set_session(session.workspace_id, session.payload)
    return {"workspace_id": session.workspace_id, "status": "saved"}


@app.delete("/sync/session/{workspace_id}")
def sync_delete(workspace_id: str):
    """Remove synced session."""
    ok = delete_session(workspace_id)
    return {"workspace_id": workspace_id, "deleted": ok}


# --- Optional: Gemini proxy (if you add GEMINI_API_KEY to vault) ---

def _openai_to_gemini(messages: list[dict]) -> dict:
    """Convert OpenAI chat messages format to Gemini generateContent format."""
    contents = []
    system_parts: list[dict] = []
    for msg in messages:
        role = msg.get("role", "user")
        content = msg.get("content") or ""
        if role == "system":
            # Gemini uses systemInstruction for system prompts
            system_parts.append({"text": content})
        else:
            gemini_role = "model" if role == "assistant" else "user"
            contents.append({"role": gemini_role, "parts": [{"text": content}]})
    result: dict = {"contents": contents}
    if system_parts:
        result["systemInstruction"] = {"parts": system_parts}
    return result


def _gemini_to_openai(gemini_resp: dict, model: str) -> dict:
    """Convert Gemini generateContent response to OpenAI chat completion format."""
    candidates = gemini_resp.get("candidates", [])
    choices = []
    for i, candidate in enumerate(candidates):
        parts = candidate.get("content", {}).get("parts", [])
        text = "".join(p.get("text", "") for p in parts)
        choices.append({
            "index": i,
            "message": {"role": "assistant", "content": text},
            "finish_reason": candidate.get("finishReason", "stop").lower(),
        })
    usage = gemini_resp.get("usageMetadata", {})
    return {
        "object": "chat.completion",
        "model": model,
        "choices": choices,
        "usage": {
            "prompt_tokens": usage.get("promptTokenCount", 0),
            "completion_tokens": usage.get("candidatesTokenCount", 0),
            "total_tokens": usage.get("totalTokenCount", 0),
        },
    }


@app.post("/v1/gemini/complete")
async def gemini_complete(request: Request):
    """
    Proxy to Gemini generateContent API.
    Accepts either OpenAI chat format (messages[]) or raw Gemini format (contents[]).
    Always returns OpenAI-compatible response format.
    """
    vault = load_vault()
    key = _gemini_key(vault)
    if not key:
        raise HTTPException(status_code=503, detail="GEMINI_API_KEY not set in vault")
    body = await request.json()
    model = body.get("model", "gemini-1.5-flash")
    url = f"https://generativelanguage.googleapis.com/v1beta/models/{model}:generateContent?key={key}"

    # Support both OpenAI format (messages[]) and native Gemini format (contents[])
    if "messages" in body and "contents" not in body:
        gemini_body = _openai_to_gemini(body["messages"])
        if body.get("max_tokens"):
            gemini_body["generationConfig"] = {"maxOutputTokens": body["max_tokens"]}
    else:
        gemini_body = {k: v for k, v in body.items() if k != "model"}

    async with httpx.AsyncClient(timeout=120.0) as client:
        try:
            r = await client.post(url, json=gemini_body, headers={"Content-Type": "application/json"})
            r.raise_for_status()
            gemini_resp = r.json()
            # Always return OpenAI-compatible format for consistency
            return JSONResponse(content=_gemini_to_openai(gemini_resp, model))
        except httpx.HTTPStatusError as e:
            raise HTTPException(
                status_code=e.response.status_code,
                detail=f"Gemini API error (HTTP {e.response.status_code})",
            )
        except Exception as e:
            raise HTTPException(status_code=502, detail=f"Gateway error: {type(e).__name__}")


# --- Lead capture & access validation (frontend API) ---

import time as _time


class AccessRequest(BaseModel):
    email: str


class LeadRequest(BaseModel):
    email: str
    company_name: Optional[str] = None


LEADS_FILE = Path(os.environ.get("AURA_LEADS_FILE", "/home/yani/Aura/ai_agency_wealth/leads.json"))


@app.post("/api/validate-access")
def validate_access(req: AccessRequest):
    """Check if an email is on the allowed-access list (vault ALLOWED_EMAILS, comma-separated)."""
    vault = load_vault()
    raw = vault.get("ALLOWED_EMAILS", "") or os.environ.get("ALLOWED_EMAILS", "")
    allowed = {e.strip().lower() for e in raw.split(",") if e.strip()}
    if req.email.strip().lower() in allowed:
        return {"access": True, "redirect": "/dashboard"}
    return {"access": False}


@app.post("/api/lead")
def capture_lead(req: LeadRequest):
    """Capture a lead (email + company) and append to leads.json."""
    lead = {
        "email": req.email,
        "company_name": req.company_name,
        "ts": int(_time.time()),
    }
    existing: list = []
    if LEADS_FILE.exists():
        try:
            with open(LEADS_FILE, "r") as f:
                existing = json.load(f)
            if not isinstance(existing, list):
                existing = []
        except (json.JSONDecodeError, OSError):
            existing = []
    existing.append(lead)
    try:
        LEADS_FILE.parent.mkdir(parents=True, exist_ok=True)
        with open(LEADS_FILE, "w") as f:
            json.dump(existing, f, indent=2)
    except OSError:
        pass  # non-fatal; lead is still returned as captured
    return {"status": "captured"}


@app.get("/api/leads")
def list_leads(authorization: Optional[str] = Header(None)):
    """List captured leads. Protected by vault token."""
    if authorization:
        token = authorization.replace("Bearer ", "")
        if not _check_vault_token(token):
            raise HTTPException(status_code=401, detail="Invalid vault token")
    else:
        raise HTTPException(status_code=401, detail="Authorization required")
    if not LEADS_FILE.exists():
        return []
    try:
        with open(LEADS_FILE, "r") as f:
            data = json.load(f)
        return data if isinstance(data, list) else []
    except (json.JSONDecodeError, OSError):
        return []


# --- Log streaming (tail -f over SSE, tail -n over JSON) ---

import asyncio
from fastapi.responses import StreamingResponse, FileResponse

_LOG_DIR = os.environ.get("AURA_LOG_DIR", "/opt/aura/logs")
_KNOWN_LOGS: dict[str, str] = {
    "agency":   os.path.join(_LOG_DIR, "agency.log"),
    "server":   os.path.join(_LOG_DIR, "server.log"),
    "fulfiller":os.path.join(_LOG_DIR, "fulfiller.log"),
    "watchdog": os.path.join(_LOG_DIR, "watchdog.log"),
    "flow":     os.path.join(_LOG_DIR, "flow.log"),
    "maid":     os.path.join(_LOG_DIR, "maid.log"),
    "n8n":      os.path.join(_LOG_DIR, "n8n.log"),
}

_LOG_TOKEN = os.environ.get("AURA_LOG_TOKEN", "")  # optional; if set, required as ?token=
_EXPORT_FILE = "/tmp/Aura_Full_Documentation_Export.txt"
_EXPORT_TOKEN = os.environ.get("AURA_EXPORT_TOKEN", "")

@app.get("/download/notebook-lm")
def download_notebook_lm(token: Optional[str] = None):
    """Securely download the NotebookLM documentation export."""
    if not _EXPORT_TOKEN or token != _EXPORT_TOKEN:
        raise HTTPException(status_code=403, detail="Forbidden: Invalid or missing token")
    if not os.path.exists(_EXPORT_FILE):
        raise HTTPException(status_code=404, detail="Export file not found")
    return FileResponse(
        path=_EXPORT_FILE, 
        filename="Aura_Full_Documentation_Export.txt",
        media_type="text/plain"
    )


def _check_log_token(token: Optional[str]) -> bool:
    if not _LOG_TOKEN:
        return True  # no token configured → open (personal network)
    return token == _LOG_TOKEN


def _tail_lines(path: str, n: int = 80) -> list[str]:
    """Return last n lines of a file without loading it all into memory."""
    try:
        with open(path, "rb") as f:
            f.seek(0, 2)
            size = f.tell()
            buf_size = min(size, max(n * 120, 8192))
            f.seek(-buf_size, 2)
            raw = f.read().decode("utf-8", errors="replace")
        lines = raw.splitlines()
        return lines[-n:]
    except (OSError, ValueError):
        return []


@app.get("/logs/tail")
def logs_tail(n: int = 80, token: Optional[str] = None):
    """Return last n lines from every known log file as JSON."""
    if not _check_log_token(token):
        raise HTTPException(status_code=401, detail="Invalid log token")
    out = {}
    for name, path in _KNOWN_LOGS.items():
        out[name] = _tail_lines(path, n)
    return out


@app.get("/logs/tail/{name}")
def logs_tail_named(name: str, n: int = 80, token: Optional[str] = None):
    """Return last n lines from a specific named log."""
    if not _check_log_token(token):
        raise HTTPException(status_code=401, detail="Invalid log token")
    if name not in _KNOWN_LOGS:
        raise HTTPException(status_code=404, detail=f"Unknown log '{name}'. Known: {list(_KNOWN_LOGS)}")
    return {"name": name, "path": _KNOWN_LOGS[name], "lines": _tail_lines(_KNOWN_LOGS[name], n)}


@app.get("/logs/stream/{name}")
async def logs_stream(name: str, token: Optional[str] = None):
    """
    Server-Sent Events stream for a single log file (like tail -f).
    Usage from laptop:  curl -N 'http://machine-ip:8765/logs/stream/agency'
    """
    if not _check_log_token(token):
        raise HTTPException(status_code=401, detail="Invalid log token")
    if name not in _KNOWN_LOGS:
        raise HTTPException(status_code=404, detail=f"Unknown log '{name}'. Known: {list(_KNOWN_LOGS)}")

    path = _KNOWN_LOGS[name]

    async def event_generator():
        # Send last 20 lines as catch-up, then follow.
        for line in _tail_lines(path, 20):
            yield f"data: {line}\n\n"
        # Ensure the file exists
        os.makedirs(os.path.dirname(path), exist_ok=True)
        if not os.path.exists(path):
            open(path, "a").close()
        try:
            with open(path, "r", encoding="utf-8", errors="replace") as f:
                f.seek(0, 2)  # jump to end
                heartbeat = 0
                while True:
                    line = f.readline()
                    if line:
                        yield f"data: {line.rstrip()}\n\n"
                        heartbeat = 0
                    else:
                        heartbeat += 1
                        # Send SSE comment as keepalive every ~15s
                        if heartbeat >= 37:
                            yield ": heartbeat\n\n"
                            heartbeat = 0
                        await asyncio.sleep(0.4)
        except (OSError, asyncio.CancelledError):
            return

    return StreamingResponse(
        event_generator(),
        media_type="text/event-stream",
        headers={
            "Cache-Control": "no-cache",
            "X-Accel-Buffering": "no",  # disable nginx buffering if behind proxy
        },
    )


# --- Organisation validation & registry ---

import re as _re
import hashlib as _hashlib
import secrets as _secrets

ORG_REGISTRY_FILE = Path(os.environ.get(
    "AURA_ORG_REGISTRY", "/home/yani/Aura/vault/org-registry.json"
))

_TRUST_TIERS = ["unverified", "domain_verified", "registry_verified", "fully_verified", "sovereign"]
_ORG_TYPES = ["company", "nonprofit", "government", "sole_trader", "cooperative"]
_ISO_COUNTRY_RE = _re.compile(r"^[A-Z]{2}$")


def _load_org_registry() -> dict:
    if not ORG_REGISTRY_FILE.exists():
        return {"version": "1.0", "sovereign_org": None, "organisations": []}
    try:
        with open(ORG_REGISTRY_FILE, "r") as f:
            return json.load(f)
    except (json.JSONDecodeError, OSError):
        return {"version": "1.0", "sovereign_org": None, "organisations": []}


def _save_org_registry(registry: dict):
    ORG_REGISTRY_FILE.parent.mkdir(parents=True, exist_ok=True)
    with open(ORG_REGISTRY_FILE, "w") as f:
        json.dump(registry, f, indent=2)


def _require_vault_auth(authorization: Optional[str]) -> str:
    """Extract and validate vault token from Authorization header."""
    if not authorization:
        raise HTTPException(status_code=401, detail="Authorization required")
    token = authorization.replace("Bearer ", "")
    if not _check_vault_token(token):
        raise HTTPException(status_code=401, detail="Invalid vault token")
    return token


def _make_org_id(legal_name: str, country_code: str) -> str:
    """Generate deterministic org_id from name + country."""
    slug = _re.sub(r"[^a-z0-9]+", "-", legal_name.lower()).strip("-")
    return f"{slug}-{country_code.lower()}"


class OrgSubmission(BaseModel):
    legal_name: str
    country_code: str
    org_type: str
    domain: Optional[str] = None
    registration_number: Optional[str] = None
    lei: Optional[str] = None
    vat_id: Optional[str] = None
    tax_id: Optional[str] = None
    contact_email: Optional[str] = None
    website: Optional[str] = None


@app.post("/api/org/register")
def org_register(req: OrgSubmission, authorization: Optional[str] = Header(None)):
    """Register a new organisation for mesh validation. Requires vault token."""
    _require_vault_auth(authorization)

    # Validate required fields
    if len(req.legal_name.strip()) < 2:
        raise HTTPException(status_code=400, detail="legal_name too short")
    if not _ISO_COUNTRY_RE.match(req.country_code.upper()):
        raise HTTPException(status_code=400, detail="Invalid country_code (ISO 3166-1 alpha-2)")
    if req.org_type not in _ORG_TYPES:
        raise HTTPException(status_code=400, detail=f"org_type must be one of: {_ORG_TYPES}")

    registry = _load_org_registry()
    org_id = _make_org_id(req.legal_name, req.country_code)

    # Check for duplicates
    for org in registry["organisations"]:
        if org["org_id"] == org_id:
            raise HTTPException(status_code=409, detail=f"Organisation '{org_id}' already registered")

    # Generate domain verification challenge
    challenge = _secrets.token_urlsafe(24)

    org_entry = {
        "org_id": org_id,
        "legal_name": req.legal_name.strip(),
        "country_code": req.country_code.upper(),
        "org_type": req.org_type,
        "domain": req.domain,
        "registration_number": req.registration_number,
        "lei": req.lei,
        "vat_id": req.vat_id,
        "tax_id": req.tax_id,
        "contact_email": req.contact_email,
        "website": req.website,
        "trust_tier": "unverified",
        "verification_challenge": challenge,
        "verifications": [],
        "agents": [],
        "registered_at": int(_time.time()),
        "last_checked": None,
    }

    registry["organisations"].append(org_entry)
    _save_org_registry(registry)

    return {
        "org_id": org_id,
        "trust_tier": "unverified",
        "verification_challenge": challenge,
        "instructions": {
            "dns_txt": f"Add TXT record to {req.domain}: _cerberus-verify={challenge}" if req.domain else None,
            "well_known": f"Serve GET https://{req.domain}/.well-known/cerberus-verify.json with {{\"challenge\": \"{challenge}\"}}" if req.domain else None,
        },
    }


@app.get("/api/org/registry")
def org_list_registry(authorization: Optional[str] = Header(None)):
    """List all registered organisations. Requires vault token."""
    _require_vault_auth(authorization)
    registry = _load_org_registry()
    # Return summary (strip verification challenges from response)
    orgs = []
    for org in registry["organisations"]:
        orgs.append({
            "org_id": org["org_id"],
            "legal_name": org["legal_name"],
            "country_code": org["country_code"],
            "org_type": org["org_type"],
            "trust_tier": org["trust_tier"],
            "domain": org.get("domain"),
            "agents": org.get("agents", []),
            "registered_at": org.get("registered_at"),
        })
    sovereign = registry.get("sovereign_org")
    return {"sovereign": sovereign, "organisations": orgs}


@app.get("/api/org/{org_id}")
def org_get(org_id: str, authorization: Optional[str] = Header(None)):
    """Get full details for a specific organisation."""
    _require_vault_auth(authorization)
    registry = _load_org_registry()
    if registry.get("sovereign_org", {}).get("org_id") == org_id:
        return registry["sovereign_org"]
    for org in registry["organisations"]:
        if org["org_id"] == org_id:
            # Don't expose verification_challenge in GET
            result = {k: v for k, v in org.items() if k != "verification_challenge"}
            return result
    raise HTTPException(status_code=404, detail=f"Organisation '{org_id}' not found")


@app.post("/api/org/{org_id}/verify/domain")
async def org_verify_domain(org_id: str, authorization: Optional[str] = Header(None)):
    """
    Verify domain ownership via DNS TXT record lookup.
    Checks for _cerberus-verify=<challenge> TXT record.
    """
    _require_vault_auth(authorization)
    registry = _load_org_registry()

    org = None
    for o in registry["organisations"]:
        if o["org_id"] == org_id:
            org = o
            break
    if not org:
        raise HTTPException(status_code=404, detail=f"Organisation '{org_id}' not found")
    if not org.get("domain"):
        raise HTTPException(status_code=400, detail="No domain set for this organisation")

    domain = org["domain"]
    challenge = org.get("verification_challenge", "")
    expected_txt = f"_cerberus-verify={challenge}"

    # Try DNS TXT lookup via system dig command
    verified = False
    method = "dns_txt"
    try:
        import subprocess
        result = subprocess.run(
            ["dig", "+short", "TXT", f"_cerberus-verify.{domain}"],
            capture_output=True, text=True, timeout=10,
        )
        txt_records = result.stdout.strip().replace('"', '')
        if challenge in txt_records:
            verified = True
    except Exception:
        pass

    # Fallback: try well-known URL
    if not verified:
        method = "well_known"
        try:
            async with httpx.AsyncClient(timeout=10.0, follow_redirects=True) as client:
                r = await client.get(f"https://{domain}/.well-known/cerberus-verify.json")
                if r.status_code == 200:
                    data = r.json()
                    if data.get("challenge") == challenge:
                        verified = True
        except Exception:
            pass

    if verified:
        org["verifications"].append({
            "method": f"domain_ownership:{method}",
            "verified_at": int(_time.time()),
            "domain": domain,
        })
        # Promote tier
        if org["trust_tier"] == "unverified":
            org["trust_tier"] = "domain_verified"
        org["last_checked"] = int(_time.time())
        _save_org_registry(registry)
        return {"org_id": org_id, "domain": domain, "verified": True, "method": method, "trust_tier": org["trust_tier"]}
    else:
        return {
            "org_id": org_id,
            "domain": domain,
            "verified": False,
            "instructions": {
                "dns_txt": f"Add TXT record at _cerberus-verify.{domain}: {challenge}",
                "well_known": f"Serve https://{domain}/.well-known/cerberus-verify.json with {{\"challenge\": \"{challenge}\"}}",
            },
        }


@app.post("/api/org/{org_id}/verify/registry")
async def org_verify_registry(org_id: str, authorization: Optional[str] = Header(None)):
    """
    Verify org exists in public company registries.
    Checks OpenCorporates and GLEIF (LEI database).
    """
    _require_vault_auth(authorization)
    registry = _load_org_registry()

    org = None
    for o in registry["organisations"]:
        if o["org_id"] == org_id:
            org = o
            break
    if not org:
        raise HTTPException(status_code=404, detail=f"Organisation '{org_id}' not found")

    legal_name = org["legal_name"]
    country = org["country_code"].lower()
    results = {"opencorporates": None, "gleif": None, "eu_vat": None}

    async with httpx.AsyncClient(timeout=15.0) as client:
        # 1. OpenCorporates search
        try:
            r = await client.get(
                "https://api.opencorporates.com/v0.4/companies/search",
                params={"q": legal_name, "jurisdiction_code": country},
            )
            if r.status_code == 200:
                data = r.json()
                companies = data.get("results", {}).get("companies", [])
                if companies:
                    top = companies[0].get("company", {})
                    results["opencorporates"] = {
                        "name": top.get("name"),
                        "company_number": top.get("company_number"),
                        "jurisdiction": top.get("jurisdiction_code"),
                        "status": top.get("current_status"),
                        "incorporation_date": top.get("incorporation_date"),
                        "source": top.get("source", {}).get("url"),
                    }
        except Exception:
            pass

        # 2. GLEIF (LEI) search
        try:
            params = {"filter[entity.legalName]": legal_name}
            if org.get("lei"):
                params = {"filter[lei]": org["lei"]}
            r = await client.get("https://api.gleif.org/api/v1/lei-records", params=params)
            if r.status_code == 200:
                data = r.json()
                records = data.get("data", [])
                if records:
                    attrs = records[0].get("attributes", {})
                    entity = attrs.get("entity", {})
                    results["gleif"] = {
                        "lei": attrs.get("lei"),
                        "legal_name": entity.get("legalName", {}).get("name"),
                        "status": entity.get("status"),
                        "jurisdiction": entity.get("jurisdiction"),
                        "category": entity.get("category"),
                    }
        except Exception:
            pass

        # 3. EU VAT validation (if EU country + vat_id provided)
        eu_countries = {"AT","BE","BG","HR","CY","CZ","DK","EE","FI","FR","DE","GR","HU","IE","IT","LV","LT","LU","MT","NL","PL","PT","RO","SK","SI","ES","SE"}
        if org.get("vat_id") and org["country_code"].upper() in eu_countries:
            try:
                vat = org["vat_id"].replace(" ", "")
                cc = vat[:2] if vat[:2].isalpha() else org["country_code"].upper()
                number = vat[2:] if vat[:2].isalpha() else vat
                r = await client.post(
                    "https://ec.europa.eu/taxation_customs/vies/rest-api/check-vat-number",
                    json={"countryCode": cc, "vatNumber": number},
                )
                if r.status_code == 200:
                    data = r.json()
                    results["eu_vat"] = {
                        "valid": data.get("valid"),
                        "name": data.get("name"),
                        "address": data.get("address"),
                        "country_code": data.get("countryCode"),
                    }
            except Exception:
                pass

    # Determine if any source confirmed the org
    confirmed_sources = []
    if results["opencorporates"] and results["opencorporates"].get("status") in ("Active", "active", "Live", "live"):
        confirmed_sources.append("opencorporates")
    if results["gleif"] and results["gleif"].get("status") in ("ACTIVE", "Active"):
        confirmed_sources.append("gleif")
    if results["eu_vat"] and results["eu_vat"].get("valid"):
        confirmed_sources.append("eu_vat")

    if confirmed_sources:
        org["verifications"].append({
            "method": "company_registry",
            "sources": confirmed_sources,
            "verified_at": int(_time.time()),
            "results": results,
        })
        # Promote tier
        if org["trust_tier"] in ("unverified", "domain_verified"):
            org["trust_tier"] = "registry_verified"
        # If both domain + registry verified → fully_verified
        has_domain = any(v.get("method", "").startswith("domain_ownership") for v in org["verifications"])
        has_registry = any(v.get("method") == "company_registry" for v in org["verifications"])
        if has_domain and has_registry:
            org["trust_tier"] = "fully_verified"
        org["last_checked"] = int(_time.time())
        _save_org_registry(registry)

    return {
        "org_id": org_id,
        "confirmed_sources": confirmed_sources,
        "trust_tier": org["trust_tier"],
        "results": results,
    }


@app.post("/api/org/{org_id}/attest")
def org_attest(org_id: str, authorization: Optional[str] = Header(None)):
    """Operator attestation: manually vouch for an organisation (sovereign override)."""
    _require_vault_auth(authorization)
    registry = _load_org_registry()

    org = None
    for o in registry["organisations"]:
        if o["org_id"] == org_id:
            org = o
            break
    if not org:
        raise HTTPException(status_code=404, detail=f"Organisation '{org_id}' not found")

    org["verifications"].append({
        "method": "operator_attestation",
        "verified_at": int(_time.time()),
    })
    org["trust_tier"] = "fully_verified"
    org["last_checked"] = int(_time.time())
    _save_org_registry(registry)

    return {"org_id": org_id, "trust_tier": "fully_verified", "method": "operator_attestation"}


@app.post("/api/org/{org_id}/revoke")
def org_revoke(org_id: str, authorization: Optional[str] = Header(None)):
    """Revoke an organisation's verification and demote to unverified."""
    _require_vault_auth(authorization)
    registry = _load_org_registry()

    for o in registry["organisations"]:
        if o["org_id"] == org_id:
            o["trust_tier"] = "unverified"
            o["verifications"].append({
                "method": "revocation",
                "revoked_at": int(_time.time()),
            })
            _save_org_registry(registry)
            return {"org_id": org_id, "trust_tier": "unverified", "revoked": True}

    raise HTTPException(status_code=404, detail=f"Organisation '{org_id}' not found")


# --- Agent-facing org lookup (no auth — agents use this as a tool) ---

@app.get("/api/org/lookup")
async def org_lookup(name: str, country: Optional[str] = None):
    """
    Public lookup: check if an organisation is real by querying
    OpenCorporates and GLEIF. Used by Cerberus agents during outreach
    to verify prospects are legitimate entities.

    No vault token required — this is a read-only public data query.
    """
    results = {"query": name, "country": country, "sources": {}}

    async with httpx.AsyncClient(timeout=15.0) as client:
        # OpenCorporates
        try:
            params = {"q": name}
            if country:
                params["jurisdiction_code"] = country.lower()
            r = await client.get(
                "https://api.opencorporates.com/v0.4/companies/search",
                params=params,
            )
            if r.status_code == 200:
                data = r.json()
                companies = data.get("results", {}).get("companies", [])[:5]
                results["sources"]["opencorporates"] = [
                    {
                        "name": c.get("company", {}).get("name"),
                        "number": c.get("company", {}).get("company_number"),
                        "jurisdiction": c.get("company", {}).get("jurisdiction_code"),
                        "status": c.get("company", {}).get("current_status"),
                        "incorporated": c.get("company", {}).get("incorporation_date"),
                    }
                    for c in companies
                ]
        except Exception:
            results["sources"]["opencorporates"] = None

        # GLEIF
        try:
            r = await client.get(
                "https://api.gleif.org/api/v1/lei-records",
                params={"filter[entity.legalName]": name, "page[size]": "5"},
            )
            if r.status_code == 200:
                data = r.json()
                records = data.get("data", [])
                results["sources"]["gleif"] = [
                    {
                        "lei": rec.get("attributes", {}).get("lei"),
                        "name": rec.get("attributes", {}).get("entity", {}).get("legalName", {}).get("name"),
                        "status": rec.get("attributes", {}).get("entity", {}).get("status"),
                        "jurisdiction": rec.get("attributes", {}).get("entity", {}).get("jurisdiction"),
                    }
                    for rec in records
                ]
        except Exception:
            results["sources"]["gleif"] = None

    # Simple confidence assessment
    total_matches = 0
    if results["sources"].get("opencorporates"):
        total_matches += len(results["sources"]["opencorporates"])
    if results["sources"].get("gleif"):
        total_matches += len(results["sources"]["gleif"])

    results["exists"] = total_matches > 0
    results["confidence"] = "high" if total_matches >= 2 else "medium" if total_matches == 1 else "none"

    return results


# --- Outreach / globe data (aggregation for planetary viz) ---

@app.get("/api/outreach/globe")
def outreach_globe(authorization: Optional[str] = Header(None)):
    """
    Aggregated data for the planetary outreach visualization.
    Returns: sovereign node, org nodes, lead nodes, and connections.
    """
    _require_vault_auth(authorization)
    registry = _load_org_registry()

    nodes: list[dict] = []
    connections: list[dict] = []

    # Sovereign node (always present)
    sovereign = registry.get("sovereign_org")
    if sovereign:
        nodes.append({
            "id": sovereign["org_id"],
            "type": "sovereign",
            "label": sovereign["legal_name"],
            "country": sovereign["country_code"],
            "tier": "sovereign",
            "agents": len(sovereign.get("agents", [])),
        })

    # Org nodes
    for org in registry.get("organisations", []):
        nodes.append({
            "id": org["org_id"],
            "type": "org",
            "label": org["legal_name"],
            "country": org["country_code"],
            "tier": org["trust_tier"],
            "agents": len(org.get("agents", [])),
        })
        # Connection from sovereign → org
        if sovereign:
            connections.append({
                "from": sovereign["org_id"],
                "to": org["org_id"],
                "type": "mesh",
                "strength": _TRUST_TIERS.index(org["trust_tier"]) / 4.0 if org["trust_tier"] in _TRUST_TIERS else 0,
            })

    # Lead nodes (from leads.json)
    leads: list[dict] = []
    if LEADS_FILE.exists():
        try:
            with open(LEADS_FILE, "r") as f:
                raw = json.load(f)
            if isinstance(raw, list):
                leads = raw
        except (json.JSONDecodeError, OSError):
            pass

    # Deduplicate leads by email domain → approximate country
    seen_domains: set = set()
    for lead in leads[-50:]:  # last 50 leads max
        email = lead.get("email", "")
        domain = email.split("@")[-1] if "@" in email else ""
        if domain and domain not in seen_domains:
            seen_domains.add(domain)
            tld = domain.split(".")[-1].upper()
            # Map common TLDs to countries
            tld_country = {
                "AU": "AU", "UK": "GB", "DE": "DE", "FR": "FR", "CA": "CA",
                "JP": "JP", "BR": "BR", "IN": "IN", "IT": "IT", "ES": "ES",
                "NL": "NL", "SE": "SE", "NO": "NO", "DK": "DK", "FI": "FI",
                "NZ": "NZ", "ZA": "ZA", "MX": "MX", "AR": "AR", "KR": "KR",
                "SG": "SG", "HK": "HK", "TW": "TW", "PH": "PH", "MY": "MY",
                "IO": "GB", "AI": "US", "CO": "US",
            }.get(tld, "US")  # default to US for .com/.net/.org
            nodes.append({
                "id": f"lead-{domain}",
                "type": "lead",
                "label": lead.get("company_name") or domain,
                "country": tld_country,
                "tier": "prospect",
            })
            if sovereign:
                connections.append({
                    "from": sovereign["org_id"],
                    "to": f"lead-{domain}",
                    "type": "outreach",
                    "strength": 0.2,
                })

    return {
        "nodes": nodes,
        "connections": connections,
        "meta": {
            "total_orgs": len(registry.get("organisations", [])),
            "total_leads": len(leads),
            "sovereign": sovereign["org_id"] if sovereign else None,
        },
    }


if __name__ == "__main__":
    import uvicorn
    port = int(os.environ.get("AURA_GATEWAY_PORT", "8765"))
    uvicorn.run(app, host="0.0.0.0", port=port)
