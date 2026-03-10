# Aura Syncing Gateway

**Onboarding (one place):** **[docs/ONBOARDING.md](../docs/ONBOARDING.md)** — gateway, chat, and all Aura setup.

Single entry point for **IDEs, TUIs, and LLM clients** (Cursor, Gemini CLI, Groq, etc.) so everything runs through Aura with vault-backed keys and optional session sync.

## Run

```bash
aura gateway
# Or: AURA_GATEWAY_PORT=8766 aura gateway
```

Listens on `http://0.0.0.0:8765` by default.

## Endpoints

| Endpoint | Description |
|----------|-------------|
| `GET /health` | Liveness |
| `GET /providers` | Configured providers (groq, gemini) |
| `POST /v1/chat/completions` | OpenAI-compatible; proxies to Groq using vault `GROQ_API_KEY` |
| `GET /sync/session/{workspace_id}` | Read synced context for workspace |
| `POST /sync/session` | Write synced context (body: `{"workspace_id": "...", "payload": {...}}`) |
| `DELETE /sync/session/{workspace_id}` | Clear session |
| `POST /v1/gemini/complete` | Proxy to Gemini (needs `GEMINI_API_KEY` in vault) |

## Point clients at the gateway

### Cursor (and other OpenAI-compatible IDEs)

In Cursor settings or env:

- **OpenAI API Base:** `http://localhost:8765/v1` (or `http://<host>:8765/v1` if remote)
- **OpenAI API Key:** any non-empty value (e.g. `aura-gateway`); the gateway ignores it and uses vault keys.

Cursor will send chat requests to the gateway; the gateway proxies to Groq.

### CLI (curl / custom scripts)

```bash
curl -X POST http://localhost:8765/v1/chat/completions \
  -H "Content-Type: application/json" \
  -d '{"model":"llama3-70b-8192","messages":[{"role":"user","content":"Hello"}]}'
```

### Minimal TUI chat (agent0)

Start gateway (e.g. `aura gateway` in background or via systemd), then:

```bash
aura chat
```

Uses `AURA_GATEWAY_URL` (default `http://127.0.0.1:8765`). **RAG-style context:** the TUI loads key Aura docs (`docs/AGENTS.md`, `ONBOARDING.md`, `AURA_PRO_GUIDE.md`, `README.md`) and optional session sync from the gateway, so the agent has full project context. Commands: `/quit`, `/clear`, `/reload` (reload context from docs + session). Env: `AURA_ROOT` (repo root), `AURA_CHAT_WORKSPACE` (sync key, default `aura`). In build mode the agent starts gateway and chat as needed; no manual steps.

### Session sync (IDE + TUI + CLI)

Use the same `workspace_id` (e.g. repo path or project name) in all clients:

- **Store:** `POST /sync/session` with `{"workspace_id": "aura", "payload": {"last_topic": "...", "summary": "..."}}`
- **Read:** `GET /sync/session/aura`

Then Cursor, a TUI, or a CLI can read/write the same context so they stay in sync.

## Vault

Gateway reads **Aura vault** (default `vault/aura-vault.json`) for:

- `GROQ_API_KEY` — used for `/v1/chat/completions`
- `OPENAI_API_BASE` — Groq base URL (default `https://api.groq.com/openai/v1`)
- `OPENAI_MODEL_NAME` — default model (e.g. `llama3-70b-8192`)
- `GEMINI_API_KEY` — optional; for `/v1/gemini/complete`

Run `aura vault` to set keys; no need to put keys in each IDE or CLI.

## Dependencies

From repo root:

```bash
pip install -r gateway/requirements.txt
# Or use ai_agency_wealth venv and add gateway to path
```
