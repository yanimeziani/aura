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
from fastapi.responses import JSONResponse
from pydantic import BaseModel

try:
    from gateway.session_store import get_session, set_session, delete_session
except ImportError:
    from session_store import get_session, set_session, delete_session

app = FastAPI(title="Aura Syncing Gateway", version="0.1.0")

VAULT_FILE = Path(os.environ.get("AURA_VAULT_FILE", "/home/yani/Aura/vault/aura-vault.json"))


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


@app.get("/providers")
def providers():
    v = load_vault()
    return {
        "providers": [
            {"id": "groq", "enabled": bool(_groq_key(v)), "openai_compatible": True},
            {"id": "gemini", "enabled": bool(_gemini_key(v)), "openai_compatible": False},
        ]
    }


# --- OpenAI-compatible chat (proxy to Groq) ---

class ChatMessage(BaseModel):
    role: str
    content: Optional[str] = None


class ChatCompletionRequest(BaseModel):
    model: Optional[str] = None
    messages: list[ChatMessage]
    stream: bool = False
    max_tokens: Optional[int] = None
    temperature: Optional[float] = None


@app.post("/v1/chat/completions")
async def chat_completions(request: Request):
    """Proxy to Groq (and later Gemini) using vault keys. Cursor/CLI set base URL here."""
    body = await request.json()
    vault = load_vault()
    api_key = _groq_key(vault)
    if not api_key:
        raise HTTPException(status_code=503, detail="Groq not configured; run aura vault and set GROQ_API_KEY")

    model = (
        _clean_model(body.get("model"))
        or _clean_model(vault.get("OPENAI_MODEL_NAME"))
        or _clean_model(os.environ.get("OPENAI_MODEL_NAME"))
        or "llama3-70b-8192"
    )
    url = f"{_groq_base().rstrip('/')}/chat/completions"
    headers = {
        "Authorization": f"Bearer {api_key}",
        "Content-Type": "application/json",
    }
    payload = {
        "model": model,
        "messages": body.get("messages", []),
        "stream": body.get("stream", False),
        "max_tokens": body.get("max_tokens"),
        "temperature": body.get("temperature"),
    }
    payload = {k: v for k, v in payload.items() if v is not None}

    async with httpx.AsyncClient(timeout=120.0) as client:
        try:
            r = await client.post(url, json=payload, headers=headers)
            r.raise_for_status()
            return JSONResponse(content=r.json(), status_code=r.status_code)
        except httpx.HTTPStatusError as e:
            # Do not forward upstream error body; it may contain auth details
            raise HTTPException(
                status_code=e.response.status_code,
                detail=f"Upstream provider error (HTTP {e.response.status_code})",
            )
        except Exception as e:
            raise HTTPException(status_code=502, detail=f"Gateway error: {type(e).__name__}")


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


# --- Log streaming (tail -f over SSE, tail -n over JSON) ---

import asyncio
from fastapi.responses import StreamingResponse

_KNOWN_LOGS: dict[str, str] = {
    "agency":   "/home/yani/Aura/ai_agency_wealth/agency_metrics.log",
    "server":   "/home/yani/Aura/ai_agency_wealth/server.log",
    "fulfiller":"/home/yani/Aura/ai_agency_wealth/fulfiller.log",
    "watchdog": "/home/yani/Aura/ai_agency_wealth/watchdog_status.log",
    "flow":     "/home/yani/Aura/var/aura-flow/spool/worker_runs.log",
    "maid":     "/home/yani/Aura/vault/maid.log",
    "n8n":      "/home/yani/Aura/ai_agency_wealth/n8n.log",
}

_LOG_TOKEN = os.environ.get("AURA_LOG_TOKEN", "")  # optional; if set, required as ?token=


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
        try:
            with open(path, "r", encoding="utf-8", errors="replace") as f:
                f.seek(0, 2)  # jump to end
                while True:
                    line = f.readline()
                    if line:
                        yield f"data: {line.rstrip()}\n\n"
                    else:
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


if __name__ == "__main__":
    import uvicorn
    port = int(os.environ.get("AURA_GATEWAY_PORT", "8765"))
    uvicorn.run(app, host="0.0.0.0", port=port)
