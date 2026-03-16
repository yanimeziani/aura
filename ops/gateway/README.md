# Nexa Syncing Gateway

**Onboarding (one place):** **[docs/ONBOARDING.md](../docs/ONBOARDING.md)** — gateway, chat, and all Nexa setup.

Single entry point for **IDEs, TUIs, and LLM clients** (Cursor, Gemini CLI, Groq, etc.) so everything runs through Nexa with vault-backed keys and optional session sync.

## Run

```bash
nexa gateway
# Or: NEXA_GATEWAY_PORT=8766 nexa gateway
```

Listens on `http://0.0.0.0:8765` by default.

## Endpoints

| Endpoint | Description |
|----------|-------------|
| `GET /health` | Liveness |
| `GET /docs/nexa` | **Single URL** for NotebookLM / public: realtime bundle of core docs + `docs/updates/*.md` (no logs, PII, vault). Agents must document in `docs/updates/`. |
| `GET /providers` | Configured providers (groq, gemini) |
| `GET /api/specs` | Active machine-readable Nexa specs for agents and tooling |
| `GET /api/specs/{name}` | One spec by name: `protocol`, `trust`, or `recovery` |
| `GET /transport/status` | Tor/IPFS transport health and routing status |
| `POST /transport/tor/newnym` | Rotate Tor circuit (vault token required) |
| `POST /transport/ipfs/add` | Add text content to IPFS and return CID (vault token required) |
| `GET /transport/ipfs/cat/{cid}` | Resolve text content from IPFS |
| `POST /v1/chat/completions` | OpenAI-compatible; proxies to Groq using vault `GROQ_API_KEY` |
| `GET /sync/session/{workspace_id}` | Read synced context for workspace |
| `POST /sync/session` | Write synced context (body: `{"workspace_id": "...", "payload": {...}}`) |
| `DELETE /sync/session/{workspace_id}` | Clear session **(HITL:** `X-HITL-Confirm: delete_session`) |
| `GET /api/hitl/actions` | List HITL-gated actions (vault token). Operator must send `X-HITL-Confirm: <action_id>` to run them. |
| `POST /v1/gemini/complete` | Proxy to Gemini (needs `GEMINI_API_KEY` in vault) |

## Point clients at the gateway

### Cursor (and other OpenAI-compatible IDEs)

In Cursor settings or env:

- **OpenAI API Base:** `http://localhost:8765/v1` (or `http://<host>:8765/v1` if remote)
- **OpenAI API Key:** any non-empty value (e.g. `nexa-gateway`); the gateway ignores it and uses vault keys.

Cursor will send chat requests to the gateway; the gateway proxies to Groq.

### CLI (curl / custom scripts)

```bash
curl -X POST http://localhost:8765/v1/chat/completions \
  -H "Content-Type: application/json" \
  -d '{"model":"llama3-70b-8192","messages":[{"role":"user","content":"Hello"}]}'
```

### Minimal TUI chat (agent0)

Start gateway (e.g. `nexa gateway` in background or via systemd), then:

```bash
nexa chat
```

Uses `NEXA_GATEWAY_URL` (default `http://127.0.0.1:8765`). **RAG-style context:** the TUI loads key Nexa docs (`docs/AGENTS.md`, `ONBOARDING.md`, `NEXA_PRO_GUIDE.md`, `README.md`) and optional session sync from the gateway, so the agent has full project context. Commands: `/quit`, `/clear`, `/reload` (reload context from docs + session). Env: `NEXA_ROOT` (repo root), `NEXA_CHAT_WORKSPACE` (sync key, default `nexa`). In build mode the agent starts gateway and chat as needed; no manual steps.

### Session sync (IDE + TUI + CLI)

Use the same `workspace_id` (e.g. repo path or project name) in all clients:

- **Store:** `POST /sync/session` with `{"workspace_id": "nexa", "payload": {"last_topic": "...", "summary": "..."}}`
- **Read:** `GET /sync/session/nexa`

Then Cursor, a TUI, or a CLI can read/write the same context so they stay in sync.

### Phone ↔ VPS continuity

Run the **process on the VPS** (gateway + agents there). On the phone, open Mission Control with `NEXT_PUBLIC_GATEWAY_URL` (or `__NEXA_GATEWAY__`) pointing at the VPS. When the phone sleeps or the tab backgrounds, the process keeps running on the VPS. When the phone returns or the tab is focused again, the dashboard calls `GET /sync/catch-up` (session + recent log lines), repaints the terminal with that state, then reconnects to the live log streams — so the phone shows the same as the VPS without losing output.

| Endpoint | Description |
|---------|-------------|
| `GET /sync/catch-up?workspace_id=nexa&n=100` | One-shot state for reconnecting clients (Bearer token). Returns `session` + `logs_tail`. |

## Vault

Gateway reads the **Nexa vault** (default `vault/nexa-vault.json`) for:

- `GROQ_API_KEY` — used for `/v1/chat/completions`
- `OPENAI_API_BASE` — Groq base URL (default `https://api.groq.com/openai/v1`)
- `OPENAI_MODEL_NAME` — default model (e.g. `llama3-70b-8192`)
- `GEMINI_API_KEY` — optional; for `/v1/gemini/complete`

Run `nexa vault` to set keys; no need to put keys in each IDE or CLI.

## Sovereign transports

- **Tor egress:** set `NEXA_ROUTE_CLOUD_THROUGH_TOR=1` and configure `NEXA_TOR_SOCKS_URL`. Optional control-plane rotation uses `NEXA_TOR_CONTROL_HOST`, `NEXA_TOR_CONTROL_PORT`, and `NEXA_TOR_CONTROL_PASSWORD`.
- **IPFS:** set `NEXA_IPFS_API_URL` and `NEXA_IPFS_GATEWAY_URL` to your local or remote daemon/gateway. Use `/transport/ipfs/add` to publish operator-approved content and `/transport/ipfs/cat/{cid}` to retrieve it.
- **Provisioning:** on Debian/Ubuntu hosts, run `sudo bash ops/scripts/provision-sovereign-transports.sh` to install Tor and Kubo/IPFS services with systemd.

## NotebookLM source quality

- Treat `GET /docs/nexa` as a source corpus first, not marketing collateral.
- Keep included docs technical, well-scoped, and neutral so downstream synthesis stays balanced.
- Follow [docs/NOTEBOOKLM_SOURCE_GUIDE.md](/root/docs/NOTEBOOKLM_SOURCE_GUIDE.md) when writing files intended for the bundle.

## Dependencies

From repo root:

```bash
pip install -r gateway/requirements.txt
# Or use ai_agency_wealth venv and add gateway to path
```
