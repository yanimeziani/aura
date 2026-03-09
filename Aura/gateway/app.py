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
    with open(VAULT_FILE, "r") as f:
        return json.load(f)


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
            raise HTTPException(status_code=e.response.status_code, detail=e.response.text)
        except Exception as e:
            raise HTTPException(status_code=502, detail=str(e))


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

@app.post("/v1/gemini/complete")
async def gemini_complete(request: Request):
    """Proxy to Gemini API. Use from Gemini CLI or custom clients."""
    vault = load_vault()
    key = _gemini_key(vault)
    if not key:
        raise HTTPException(status_code=503, detail="GEMINI_API_KEY not set in vault")
    body = await request.json()
    model = body.get("model", "gemini-1.5-flash")
    # Gemini REST: https://ai.google.dev/api/rest/v1/models/...:generateContent
    url = f"https://generativelanguage.googleapis.com/v1beta/models/{model}:generateContent?key={key}"
    async with httpx.AsyncClient(timeout=120.0) as client:
        try:
            r = await client.post(url, json=body, headers={"Content-Type": "application/json"})
            r.raise_for_status()
            return JSONResponse(content=r.json(), status_code=r.status_code)
        except httpx.HTTPStatusError as e:
            raise HTTPException(status_code=e.response.status_code, detail=e.response.text)


if __name__ == "__main__":
    import uvicorn
    port = int(os.environ.get("AURA_GATEWAY_PORT", "8765"))
    uvicorn.run(app, host="0.0.0.0", port=port)
