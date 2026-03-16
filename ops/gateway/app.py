"""
Nexa Syncing Gateway — single entry for IDEs, TUIs, and LLM clients (Cursor, Gemini CLI, Groq, etc.).
- Vault-backed API keys; no keys in clients.
- OpenAI-compatible /v1/chat/completions for Cursor and other tools.
- Session sync: shared context across IDE / TUI / CLI (GET/POST /sync/session).
Run: uvicorn gateway.app:app --host 0.0.0.0 --port 8765
"""
from __future__ import annotations

import os
import json
import subprocess
import socket
import sys
import re
from pathlib import Path
from typing import Any, Optional

GATEWAY_DIR = Path(__file__).resolve().parent
OPS_DIR = GATEWAY_DIR.parent
REPO_ROOT = OPS_DIR.parent
for candidate in (OPS_DIR, REPO_ROOT):
    candidate_str = str(candidate)
    if candidate_str not in sys.path:
        sys.path.insert(0, candidate_str)

import httpx
from fastapi import FastAPI, HTTPException, Request, Header
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse, Response
from pydantic import BaseModel

try:
    from gateway.session_store import get_session, set_session, delete_session
except ImportError:
    from session_store import get_session, set_session, delete_session
try:
    from gateway.spec_models import (
        SessionRecord,
        default_workspace_id,
        ensure_trust_transition,
        hitl_actions,
        named_spec,
        spec_bundle,
        trust_tiers,
        validate_org_id,
        validate_workspace_id,
    )
except ImportError:
    from spec_models import (
        SessionRecord,
        default_workspace_id,
        ensure_trust_transition,
        hitl_actions,
        named_spec,
        spec_bundle,
        trust_tiers,
        validate_org_id,
        validate_workspace_id,
    )

from aura_runtime import (
    aura_root,
    export_file,
    leads_file,
    log_dir,
    org_registry_file,
    telemetry_file,
    vault_file,
)

app = FastAPI(
    title="Nexa Syncing Gateway",
    version="0.2.0",
    description="Use subject to project DISCLAIMER: no warranty; prohibited use for illegal, harmful, or dangerous purposes. See repository DISCLAIMER.md.",
)

AURA_ROOT = aura_root()
VAULT_FILE = vault_file(AURA_ROOT)
TELEMETRY_FILE = telemetry_file(AURA_ROOT)
LEADS_FILE = leads_file(AURA_ROOT)
ORG_REGISTRY_FILE = org_registry_file(AURA_ROOT)
_LOG_DIR = str(log_dir(AURA_ROOT))
_EXPORT_FILE = str(export_file(AURA_ROOT))
_EXPORT_TOKEN = os.environ.get("AURA_EXPORT_TOKEN", "")
OLLAMA_BASE = os.environ.get("OLLAMA_BASE_URL", "http://127.0.0.1:11434").rstrip("/")
TOR_SOCKS_URL = os.environ.get("AURA_TOR_SOCKS_URL", "socks5://127.0.0.1:9050").rstrip("/")
TOR_CONTROL_HOST = os.environ.get("AURA_TOR_CONTROL_HOST", "127.0.0.1")
TOR_CONTROL_PORT = int(os.environ.get("AURA_TOR_CONTROL_PORT", "9051"))
TOR_CONTROL_PASSWORD = os.environ.get("AURA_TOR_CONTROL_PASSWORD", "")
IPFS_API_URL = os.environ.get("AURA_IPFS_API_URL", "http://127.0.0.1:5001").rstrip("/")
IPFS_GATEWAY_URL = os.environ.get("AURA_IPFS_GATEWAY_URL", "http://127.0.0.1:8080").rstrip("/")
ROUTE_CLOUD_THROUGH_TOR = os.environ.get("AURA_ROUTE_CLOUD_THROUGH_TOR", "0").lower() in {"1", "true", "yes", "on"}
IPFS_MAX_CONTENT_BYTES = int(os.environ.get("AURA_IPFS_MAX_CONTENT_BYTES", str(512 * 1024)))
_CID_RE = re.compile(r"^[A-Za-z0-9]+$")
_AURA_ROOT = AURA_ROOT


def _cors_origins() -> list[str]:
    configured = [origin.strip() for origin in os.environ.get("AURA_CORS_ORIGINS", "").split(",") if origin.strip()]
    defaults = [
        "http://localhost:3003",
        "http://127.0.0.1:3003",
        "http://localhost:3000",
        "http://127.0.0.1:3000",
    ]
    public_base = os.environ.get("AURA_PUBLIC_BASE_URL", "").strip().rstrip("/")
    if public_base:
        configured.append(public_base)
    seen: set[str] = set()
    origins: list[str] = []
    for origin in [*defaults, *configured]:
        if origin and origin not in seen:
            seen.add(origin)
            origins.append(origin)
    return origins


app.add_middleware(
    CORSMiddleware,
    allow_origins=_cors_origins(),
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

_LOCAL_MODEL_PREFIXES = ("llama", "qwen", "mistral", "phi", "deepseek", "nomic", "gemma")


def _httpx_kwargs(url: str, timeout: float, *, follow_redirects: bool = False) -> dict[str, Any]:
    kwargs: dict[str, Any] = {"timeout": timeout, "follow_redirects": follow_redirects}
    if ROUTE_CLOUD_THROUGH_TOR and not url.startswith("http://127.0.0.1") and not url.startswith("http://localhost"):
        kwargs["proxy"] = TOR_SOCKS_URL
    return kwargs


def _async_client(url: str, timeout: float, *, follow_redirects: bool = False) -> httpx.AsyncClient:
    return httpx.AsyncClient(**_httpx_kwargs(url, timeout, follow_redirects=follow_redirects))


def _probe_tcp(host: str, port: int, timeout: float = 1.0) -> bool:
    try:
        with socket.create_connection((host, port), timeout=timeout):
            return True
    except OSError:
        return False


def _tor_status() -> dict[str, Any]:
    host = TOR_SOCKS_URL.removeprefix("socks5://").split(":", 1)[0] or "127.0.0.1"
    port_str = TOR_SOCKS_URL.rsplit(":", 1)[-1]
    try:
        port = int(port_str)
    except ValueError:
        port = 9050
    return {
        "enabled": ROUTE_CLOUD_THROUGH_TOR,
        "socks_url": TOR_SOCKS_URL,
        "socks_reachable": _probe_tcp(host, port),
        "control_reachable": _probe_tcp(TOR_CONTROL_HOST, TOR_CONTROL_PORT),
    }


async def _ipfs_status() -> dict[str, Any]:
    status = {
        "api_url": IPFS_API_URL,
        "gateway_url": IPFS_GATEWAY_URL,
        "api_reachable": False,
        "gateway_reachable": False,
    }
    try:
        async with _async_client(IPFS_API_URL, 5.0) as client:
            response = await client.post(f"{IPFS_API_URL}/api/v0/version")
            status["api_reachable"] = response.status_code == 200
    except Exception:
        pass
    try:
        async with _async_client(IPFS_GATEWAY_URL, 5.0, follow_redirects=True) as client:
            response = await client.get(IPFS_GATEWAY_URL)
            status["gateway_reachable"] = response.status_code < 500
    except Exception:
        pass
    return status


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


def _default_collab_model(vault: dict[str, str]) -> str:
    return (
        _clean_model(vault.get("NEXA_DEFAULT_COLLAB_MODEL"))
        or _clean_model(os.environ.get("NEXA_DEFAULT_COLLAB_MODEL"))
        or _clean_model(vault.get("OPENAI_MODEL_NAME"))
        or _clean_model(os.environ.get("OPENAI_MODEL_NAME"))
        or "Qwen/Qwen3-Coder-480B-A35B-Instruct"
    )


def _default_edge_model(vault: dict[str, str]) -> str:
    return (
        _clean_model(vault.get("NEXA_DEFAULT_EDGE_MODEL"))
        or _clean_model(os.environ.get("NEXA_DEFAULT_EDGE_MODEL"))
        or "qwen2.5-coder:7b-instruct"
    )


# --- Health & discovery ---

@app.get("/health")
def health():
    return {"status": "ok", "service": "nexa-gateway"}


@app.get("/transport/status")
async def transport_status():
    return {
        "tor": _tor_status(),
        "ipfs": await _ipfs_status(),
        "route_cloud_through_tor": ROUTE_CLOUD_THROUGH_TOR,
    }


@app.post("/transport/tor/newnym")
def tor_newnym(authorization: Optional[str] = Header(None)):
    _require_vault_auth(authorization)
    if not TOR_CONTROL_PASSWORD:
        raise HTTPException(status_code=400, detail="Set AURA_TOR_CONTROL_PASSWORD to rotate Tor circuits.")
    try:
        with socket.create_connection((TOR_CONTROL_HOST, TOR_CONTROL_PORT), timeout=5) as conn:
            conn.sendall(f'AUTHENTICATE "{TOR_CONTROL_PASSWORD}"\r\n'.encode("utf-8"))
            auth = conn.recv(1024).decode("utf-8", errors="replace")
            if "250" not in auth:
                raise HTTPException(status_code=502, detail="Tor control authentication failed")
            conn.sendall(b"SIGNAL NEWNYM\r\n")
            signal = conn.recv(1024).decode("utf-8", errors="replace")
            if "250" not in signal:
                raise HTTPException(status_code=502, detail="Tor NEWNYM failed")
    except HTTPException:
        raise
    except OSError as exc:
        raise HTTPException(status_code=502, detail=f"Tor control unavailable: {exc}")
    return {"status": "ok", "signal": "NEWNYM"}


class IpfsAddRequest(BaseModel):
    content: str
    filename: str = "nexa.txt"
    pin: bool = True


@app.post("/transport/ipfs/add")
async def ipfs_add(req: IpfsAddRequest, authorization: Optional[str] = Header(None)):
    _require_vault_auth(authorization)
    if "/" in req.filename or req.filename in {".", ".."}:
        raise HTTPException(status_code=400, detail="filename must be a plain file name")
    content_bytes = req.content.encode("utf-8")
    if len(content_bytes) > IPFS_MAX_CONTENT_BYTES:
        raise HTTPException(status_code=413, detail=f"content exceeds {IPFS_MAX_CONTENT_BYTES} bytes")
    files = {"file": (req.filename, content_bytes, "text/plain")}
    params = {"pin": "true" if req.pin else "false"}
    try:
        async with _async_client(IPFS_API_URL, 60.0) as client:
            response = await client.post(f"{IPFS_API_URL}/api/v0/add", params=params, files=files)
            response.raise_for_status()
    except Exception as exc:
        raise HTTPException(status_code=502, detail=f"IPFS add failed: {type(exc).__name__}")
    payload = response.json()
    cid = payload.get("Hash")
    return {
        "cid": cid,
        "name": payload.get("Name", req.filename),
        "size": payload.get("Size"),
        "gateway_url": f"{IPFS_GATEWAY_URL}/ipfs/{cid}" if cid else None,
    }


@app.get("/transport/ipfs/cat/{cid}")
async def ipfs_cat(cid: str):
    if not _CID_RE.fullmatch(cid):
        raise HTTPException(status_code=400, detail="invalid CID")
    url = f"{IPFS_API_URL}/api/v0/cat"
    try:
        async with _async_client(url, 60.0) as client:
            response = await client.post(url, params={"arg": cid})
            response.raise_for_status()
    except Exception as exc:
        raise HTTPException(status_code=502, detail=f"IPFS cat failed: {type(exc).__name__}")
    return Response(content=response.text, media_type="text/plain; charset=utf-8")


@app.get("/health/services")
async def health_services():
    """Probe service availability via raw TCP socket connect."""
    import asyncio, socket

    gateway_port = int(os.environ.get("AURA_GATEWAY_PORT", "8765"))
    dashboard_port = int(os.environ.get("AURA_DASHBOARD_PORT", "3003"))
    aura_api_port = int(os.environ.get("AURA_API_PORT", "3001"))
    aura_flow_port = int(os.environ.get("AURA_FLOW_PORT", "3002"))
    cerberus_port = int(os.environ.get("CERBERUS_API_PORT", "3000"))
    ollama_port = int(os.environ.get("OLLAMA_PORT", "11434"))
    pegasus_port = int(os.environ.get("PEGASUS_API_PORT", "8080"))

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
        ("Gateway", "127.0.0.1", gateway_port),
        ("Cerberus", "127.0.0.1", cerberus_port),
        ("Nexa API", "127.0.0.1", aura_api_port),
        ("Nexa Flow", "127.0.0.1", aura_flow_port),
        ("Ollama", "127.0.0.1", ollama_port),
        ("Pegasus API", "127.0.0.1", pegasus_port),
        ("Dashboard", "127.0.0.1", dashboard_port),
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


# --- Region telemetry (landing visits by locale/country) ---

def _default_country_from_locale(locale: str) -> str:
    if not locale:
        return "XX"
    locale = locale.strip().upper()
    if locale.startswith("EN-CA") or locale.startswith("FR-CA"):
        return "CA"
    if locale.startswith("EN-US"):
        return "US"
    if locale.startswith("EN-AU"):
        return "AU"
    if locale.startswith("AR-DZ") or locale.startswith("AR"):
        return "DZ"
    if locale.startswith("FR"):
        return "CA"
    return "XX"


def _load_telemetry() -> dict:
    if not TELEMETRY_FILE.exists():
        return {}
    try:
        with open(TELEMETRY_FILE, "r") as f:
            return json.load(f)
    except (json.JSONDecodeError, OSError):
        return {}


def _save_telemetry(data: dict) -> None:
    TELEMETRY_FILE.parent.mkdir(parents=True, exist_ok=True)
    with open(TELEMETRY_FILE, "w") as f:
        json.dump(data, f, indent=0)


class VisitPayload(BaseModel):
    locale: str
    country: Optional[str] = None


@app.post("/telemetry/visit")
def telemetry_visit(payload: VisitPayload):
    """Record a landing page visit by locale/country for region cluster view."""
    locale = (payload.locale or "").strip() or "en-CA"
    country = (payload.country or "").strip().upper() or _default_country_from_locale(locale)
    if len(country) != 2:
        country = _default_country_from_locale(locale)
    key = f"{country}:{locale}"
    data = _load_telemetry()
    counts = data.get("visits", {})
    counts[key] = counts.get(key, 0) + 1
    data["visits"] = counts
    data["_updated"] = __import__("time").time()
    _save_telemetry(data)
    return {"ok": True, "country": country, "locale": locale}


@app.get("/telemetry/regions")
def telemetry_regions():
    """Aggregated visit counts by country/locale for operator UI cluster view."""
    data = _load_telemetry()
    counts = data.get("visits", {})
    clusters = []
    for key, n in counts.items():
        if ":" in key:
            country, locale = key.split(":", 1)
            clusters.append({"country": country, "locale": locale, "visits": n})
        else:
            clusters.append({"country": "XX", "locale": key or "en-CA", "visits": n})
    clusters.sort(key=lambda x: -x["visits"])
    return {"clusters": clusters}


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


@app.get("/api/specs")
def get_specs():
    """Expose the active machine-readable Nexa specs for agents and tooling."""
    return spec_bundle()


@app.get("/api/specs/{name}")
def get_named_spec(name: str):
    """Expose one active machine-readable spec by name."""
    try:
        return named_spec(name)
    except ValueError as exc:
        raise HTTPException(status_code=404, detail=str(exc))


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
        async with _async_client(OLLAMA_BASE, 5.0) as client:
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
    async with _async_client(f"{OLLAMA_BASE}/api/chat", 60.0) as client:
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
        or _default_collab_model(vault)
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

    if model == "edge-default":
        model = _default_edge_model(vault)
        payload["model"] = model
        use_ollama = True

    if use_ollama or not api_key:
        # Try Ollama first
        try:
            async with _async_client(url, 300.0) as client:
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
        async with _async_client(url, 300.0) as client:
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
    workspace_id = validate_workspace_id(workspace_id)
    out = get_session(workspace_id)
    if out is None:
        return {"workspace_id": workspace_id, "payload": None}
    return {"workspace_id": workspace_id, "payload": out}


@app.post("/sync/session")
def sync_post(session: SessionPayload):
    """Store synced session for this workspace. All clients can read it."""
    record = SessionRecord.from_values(session.workspace_id, session.payload)
    set_session(record.workspace_id, record.payload)
    return {"workspace_id": record.workspace_id, "status": "saved"}


@app.delete("/sync/session/{workspace_id}")
def sync_delete(
    workspace_id: str,
    authorization: Optional[str] = Header(None),
    x_hitl_confirm: Optional[str] = Header(None, alias="X-HITL-Confirm"),
):
    """Remove synced session. HITL: destructive — requires vault token + X-HITL-Confirm: delete_session."""
    workspace_id = validate_workspace_id(workspace_id)
    _require_vault_auth(authorization)
    _require_hitl_confirm("delete_session", x_hitl_confirm)
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

    async with _async_client(url, 120.0) as client:
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
# Curated docs bundle for NotebookLM / public: core Nexa docs only, no logs/PII/vault.
# Realtime: built on each request from AURA_ROOT so agents' docs under docs/updates/ are always included.
_DOCS_ALLOWLIST = [
    "README.md",
    "DISCLAIMER.md",
    "docs/NOTEBOOKLM_SOURCE_GUIDE.md",
    "docs/NOTEBOOKLM_MEDIA_GUIDE.md",
    "docs/ARCHITECTURE.md",
    "docs/PROTOCOL.md",
    "docs/TRUST_MODEL.md",
    "docs/THREAT_MODEL.md",
    "docs/AURAMANIFESTO.md",
    "docs/PRD.md",
    "docs/AGENTS.md",
    "docs/README_AGENTS.md",
    "docs/Notebook.lm.md",
    "docs/Notebook_Audit_Briefing.md",
    "docs/SYSTEM_CAPABILITIES.md",
    "docs/DEPLOYMENT_GUIDE.md",
    "docs/DEPLOY.md",
    "docs/VPS_DEPLOYMENT.md",
    "docs/VPS_READY.md",
    "docs/TESTING_GUIDE.md",
    "docs/OUTREACH_STRATEGY.md",
    "docs/COMMERCIAL.md",
    "docs/SCAFFOLDING.md",
    "docs/AUTOMATION_AUDIT.md",
    "docs/QUICKSTART.md",
    "docs/HITL.md",
    "docs/DISTRIBUTED_INFERENCE_VISION.md",
    "docs/updates/README.md",
    "ops/gateway/README.md",
]
_DOCS_FORBIDDEN = ("vault", ".env", "aura-vault", "org-registry", "backup-nodes", "notebooklm_packets", "leads.json", "telemetry_visits", "gateway_sessions")


def _build_docs_bundle() -> str:
    """Build bundle from AURA_ROOT: allowlist + all docs/updates/*.md (agent-written). Never includes logs/PII/vault."""
    buf = [
        "# Nexa — Core documentation bundle",
        "",
        "Single source for NotebookLM ingestion, technical review, and downstream asset generation.",
        "Primary use: neutral technical summarisation, audio narration, video script generation, and architecture retrieval.",
        "Operators and public: this URL is realtime-updated; agents document under docs/updates/.",
        "Reading order: source guides first, then architecture and protocol docs, then deployment and capability docs, then dated updates.",
        "The source corpus is intended to stay technically precise, operationally useful, and tone-neutral.",
        "This bundle never contains: system logs, PII, vault secrets, or deployment-specific data.",
        "",
        "## Bundle Orientation",
        "",
        "Nexa is a sovereign collaboration protocol stack for humans and AI systems.",
        "When generating media, prefer architecture, trust boundaries, transport design, recovery flows, and implementation status over slogans or personality framing.",
        "",
        "---",
        "",
    ]
    root = _AURA_ROOT
    for rel in _DOCS_ALLOWLIST:
        if any(f in rel.lower() for f in _DOCS_FORBIDDEN):
            continue
        full = root / rel
        if full.exists() and full.is_file():
            try:
                text = full.read_text(encoding="utf-8", errors="replace")
                buf.append(f"## File: {rel}")
                buf.append("")
                buf.append(text.strip())
                buf.append("")
                buf.append("---")
                buf.append("")
            except OSError:
                pass
    updates_dir = root / "docs" / "updates"
    if updates_dir.is_dir():
        for f in sorted(updates_dir.glob("*.md")):
            if f.name.startswith("."):
                continue
            try:
                text = f.read_text(encoding="utf-8", errors="replace")
                buf.append(f"## File: docs/updates/{f.name}")
                buf.append("")
                buf.append(text.strip())
                buf.append("")
                buf.append("---")
                buf.append("")
            except OSError:
                pass
    return "\n".join(buf)


@app.get("/docs/nexa")
def docs_nexa_bundle():
    """
    Single URL for NotebookLM and public/operator consumption. Realtime: built on each request.
    Includes curated core docs + all docs/updates/*.md (agents must document there).
    No system logs, PII, vault, or deployment-specific data. No auth required.
    """
    try:
        content = _build_docs_bundle()
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Docs bundle build failed: {e}")
    return Response(
        content=content,
        media_type="text/plain; charset=utf-8",
        headers={"Content-Disposition": "inline; filename=nexa-docs-notebooklm.txt"},
    )


@app.get("/download/notebook-lm")
def download_notebook_lm(token: Optional[str] = None):
    """Securely download the NotebookLM documentation export (legacy; may include more content)."""
    if not _EXPORT_TOKEN or token != _EXPORT_TOKEN:
        raise HTTPException(status_code=403, detail="Forbidden: Invalid or missing token")
    if not os.path.exists(_EXPORT_FILE):
        raise HTTPException(status_code=404, detail="Export file not found")
    return FileResponse(
        path=_EXPORT_FILE, 
        filename="Nexa_Full_Documentation_Export.txt",
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


@app.get("/sync/catch-up")
def sync_catch_up(
    workspace_id: str = default_workspace_id(),
    n: int = 100,
    authorization: Optional[str] = Header(None),
):
    """
    One-shot state for reconnecting clients (e.g. phone back from sleep).
    Returns current session + recent log lines so the client can repaint
    and then attach to live streams. Process keeps running on VPS; when
    phone returns, call this then resume SSE. Requires vault token.
    """
    _require_vault_auth(authorization)
    workspace_id = validate_workspace_id(workspace_id)
    session_payload = get_session(workspace_id)
    logs_tail: dict[str, list[str]] = {}
    for name, path in _KNOWN_LOGS.items():
        logs_tail[name] = _tail_lines(path, n)
    return {
        "session": {"workspace_id": workspace_id, "payload": session_payload},
        "logs_tail": logs_tail,
    }


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

_TRUST_TIERS = trust_tiers()
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


# --- HITL: operator must confirm medium-to-critical destructive or outside-mesh actions ---
HITL_ACTIONS = hitl_actions()


def _require_hitl_confirm(action_id: str, hitl_confirm: Optional[str] = Header(None, alias="X-HITL-Confirm")) -> None:
    """
    Require explicit operator confirmation for destructive or high-impact actions.
    Caller must send header: X-HITL-Confirm: <action_id>.
    """
    if hitl_confirm != action_id:
        raise HTTPException(
            status_code=403,
            detail={
                "hitl_required": True,
                "action": action_id,
                "message": f"Operator confirmation required. Send header X-HITL-Confirm: {action_id!r} to execute.",
            },
        )


@app.get("/api/hitl/actions")
def hitl_actions_list(authorization: Optional[str] = Header(None)):
    """List all HITL-gated actions (operator must send X-HITL-Confirm: <action_id>). Requires vault token."""
    _require_vault_auth(authorization)
    return {"actions": HITL_ACTIONS}


def _make_org_id(legal_name: str, country_code: str) -> str:
    """Generate deterministic org_id from name + country."""
    slug = _re.sub(r"[^a-z0-9]+", "-", legal_name.lower()).strip("-")
    return validate_org_id(f"{slug}-{country_code.lower()}")


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
def org_register(
    req: OrgSubmission,
    authorization: Optional[str] = Header(None),
    x_hitl_confirm: Optional[str] = Header(None, alias="X-HITL-Confirm"),
):
    """Register a new organisation (outside-mesh: writes registry). HITL: requires X-HITL-Confirm: register_org."""
    _require_vault_auth(authorization)
    _require_hitl_confirm("register_org", x_hitl_confirm)

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


BACKUP_NODES_FILE = Path(os.environ.get(
    "AURA_BACKUP_NODES_FILE",
    str(ORG_REGISTRY_FILE.parent / "backup-nodes.json"),
))


def _load_backup_nodes() -> list[dict]:
    """Load backup-nodes.json (org nodes that can receive log backups)."""
    if not BACKUP_NODES_FILE.exists():
        return []
    try:
        with open(BACKUP_NODES_FILE, "r") as f:
            data = json.load(f)
        return data if isinstance(data, list) else []
    except (json.JSONDecodeError, OSError):
        return []


def _node_avail_kb(host: str, storage_path: str) -> Optional[int]:
    """Get available KB on node via ssh df -k. Returns None if unreachable."""
    try:
        r = subprocess.run(
            ["ssh", "-o", "ConnectTimeout=5", "-o", "BatchMode=yes", host, "df", "-k", storage_path],
            capture_output=True,
            text=True,
            timeout=10,
        )
        if r.returncode != 0 or not r.stdout.strip():
            return None
        lines = r.stdout.strip().splitlines()
        if len(lines) < 2:
            return None
        parts = lines[-1].split()
        if len(parts) >= 4:
            return int(parts[3])
    except (subprocess.TimeoutExpired, ValueError, OSError):
        pass
    return None


@app.get("/api/backup/nodes")
def backup_nodes(authorization: Optional[str] = Header(None)):
    """
    List org nodes that receive log backups, with available storage (KB).
    Largest-first so operator UI can show where backups are routed.
    Requires vault token.
    """
    _require_vault_auth(authorization)
    nodes = _load_backup_nodes()
    out = []
    for n in nodes:
        host = n.get("host", "")
        storage_path = n.get("storage_path", "/")
        if not host:
            continue
        avail = _node_avail_kb(host, storage_path)
        out.append({
            "host": host,
            "storage_path": storage_path,
            "label": n.get("label"),
            "avail_kb": avail,
        })
    out.sort(key=lambda x: (x.get("avail_kb") or 0), reverse=True)
    return {"nodes": out}


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
            async with _async_client(url, 10.0, follow_redirects=True) as client:
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
            org["trust_tier"] = ensure_trust_transition(org["trust_tier"], "domain_verified")
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

    async with _async_client(url, 15.0) as client:
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
            org["trust_tier"] = ensure_trust_transition(org["trust_tier"], "registry_verified")
        # If both domain + registry verified → fully_verified
        has_domain = any(v.get("method", "").startswith("domain_ownership") for v in org["verifications"])
        has_registry = any(v.get("method") == "company_registry" for v in org["verifications"])
        if has_domain and has_registry:
            org["trust_tier"] = ensure_trust_transition(org["trust_tier"], "fully_verified")
        org["last_checked"] = int(_time.time())
        _save_org_registry(registry)

    return {
        "org_id": org_id,
        "confirmed_sources": confirmed_sources,
        "trust_tier": org["trust_tier"],
        "results": results,
    }


@app.post("/api/org/{org_id}/attest")
def org_attest(
    org_id: str,
    authorization: Optional[str] = Header(None),
    x_hitl_confirm: Optional[str] = Header(None, alias="X-HITL-Confirm"),
):
    """Operator attestation: manually vouch for an org (trust change). HITL: requires X-HITL-Confirm: attest_org."""
    _require_vault_auth(authorization)
    _require_hitl_confirm("attest_org", x_hitl_confirm)
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
    org["trust_tier"] = ensure_trust_transition(org["trust_tier"], "fully_verified")
    org["last_checked"] = int(_time.time())
    _save_org_registry(registry)

    return {"org_id": org_id, "trust_tier": "fully_verified", "method": "operator_attestation"}


@app.post("/api/org/{org_id}/revoke")
def org_revoke(
    org_id: str,
    authorization: Optional[str] = Header(None),
    x_hitl_confirm: Optional[str] = Header(None, alias="X-HITL-Confirm"),
):
    """Revoke an organisation (destructive, trust change). HITL: requires X-HITL-Confirm: revoke_org."""
    _require_vault_auth(authorization)
    _require_hitl_confirm("revoke_org", x_hitl_confirm)
    registry = _load_org_registry()

    for o in registry["organisations"]:
        if o["org_id"] == org_id:
            o["trust_tier"] = ensure_trust_transition(o["trust_tier"], "unverified")
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

    async with _async_client(url, 15.0) as client:
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
