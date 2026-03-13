# G04 — Gateway Audit & Migration Plan

**File:** `gateway/app.py` + `gateway/session_store.py`
**Date:** 2026-03-09
**Author:** Scout

---

## What the gateway does

FastAPI server (`uvicorn`, port 8765). Two distinct concerns:

### 1. LLM proxy
| Route | Purpose |
|-------|---------|
| `POST /v1/chat/completions` | OpenAI-compatible proxy → Groq. Cursor, CLI, any OpenAI client points here. Reads `GROQ_API_KEY` from vault. |
| `POST /v1/gemini/complete` | Proxy → Gemini REST API. Reads `GEMINI_API_KEY` from vault. |
| `GET /providers` | Lists configured providers (groq, gemini) with `enabled` flag. |

Key: `load_vault()` reads `vault/aura-vault.json` for API keys — no keys stored in clients.

### 2. Session sync
| Route | Purpose |
|-------|---------|
| `GET /sync/session/{workspace_id}` | Read shared context (IDE/TUI/CLI). |
| `POST /sync/session` | Write shared context. |
| `DELETE /sync/session/{workspace_id}` | Remove session. |

Backed by `session_store.py`: file at `AURA_ROOT/.aura/gateway_sessions.json`, mode 0600.

### 3. Health / discovery (overlap with aura-api)
| Route | Status |
|-------|--------|
| `GET /health` | **Overlap** — aura-api already serves this on port 9000. |

---

## Overlap with aura-api (post G03)

| Gateway route | aura-api equivalent | Action |
|---------------|---------------------|--------|
| `GET /health` | `GET /health` ✓ | Redundant; gateway's is on different port (8765 vs 9000). Keep both; aura-api is the canonical external health. |
| `GET /providers` | `GET /providers` ✓ (G03 added) | Both read vault — aura-api's is Zig, no runtime deps. Gateway's is authoritative during transition. |
| `GET /mesh` | `GET /mesh` ✓ (G03) | Gateway doesn't have this — new in aura-api only. |

---

## Migration decision: what to keep, what to replace

### Keep in Python (gateway) — do not migrate yet

| Reason | Detail |
|--------|--------|
| **LLM proxying** | `httpx` async streaming, Groq/Gemini APIs. Zig port is high effort, low value. Gateway is the right abstraction here — LLM clients expect HTTP on localhost. |
| **Session sync** | Simple but functional. File-backed, works. Not on the hot path. Zig port adds no value now. |

### Replace / absorb into aura-api — medium term

| Route | Plan |
|-------|------|
| `GET /providers` | aura-api `/providers` is already live (reads vault). Once aura-api is stable on VPS, point tooling there. Retire gateway's. |
| `GET /health` | aura-api is canonical. |
| `GET /mesh` | aura-api only. |

### Retire gateway entirely — long term

Once aura-api has:
1. A Zig-native vault reader (for provider key checks)
2. Session store (file-backed, Zig, similar to session_store.py)
3. A streaming HTTP reverse proxy for Groq/Gemini (or direct integration)

…the gateway Python process can be removed. Not a priority until LLM proxy is replicated.

---

## session_store.py — notes

- File: `AURA_ROOT/.aura/gateway_sessions.json`, chmod 0600
- In-process (no locking) — race condition if multiple uvicorn workers. Current single-process deployment is safe.
- Direct Zig replacement: `var/gateway/sessions.json` with atomic write (write to `.tmp`, rename). ~50 lines of Zig.

---

## Immediate actions (none blocking today)

- [x] aura-api `/mesh` and `/providers` live (G03 done)
- [ ] Update `docs/MISSION_CONTROL.md` with gateway port (8765) alongside aura-api (9000)
- [ ] Add gateway to sovereign-stack `docker-compose.yml` if not already present (check)
- [ ] Long-term: Zig session store as `aura-api/src/sessions.zig`

---

## Ports reference

| Service | Port | Process |
|---------|------|---------|
| aura-api | 9000 | Zig binary |
| aura-flow | 9100 | Zig binary |
| gateway | 8765 | uvicorn (Python) |
| aura-edge | configurable | Zig binary |
