# Aura: One-place onboarding

**The Aura project onboards here.** This is the single entry for setup, modes, and daily use. Everything else (AGENTS.md, AURA_PRO_GUIDE, component READMEs) branches from this.

---

## 1. What this is

- **Aura** = autonomous multi-agent command center + sovereign stack (Zig edge/mesh/MCP, Python gateway/agents, React frontend, Docker infra).
- **One place:** All onboarding, run flows, and “where is X?” live in this doc. Build and operate via the **`aura`** CLI; no manual command handoff in build mode.

---

## 2. Modes (agent and operator)

- **Build mode.** When building, testing, or running, the agent executes all commands (e.g. via terminal). No “run X manually” or “in a separate terminal”—the agent starts services, runs scripts, and performs steps itself. See **docs/AGENTS.md** (Principles).
- **Dirty hands mode.** Full overseeing root/internal mode with **manual human override**. The agent has full oversight; the operator can step in and take control at any time. Operator authority is always available. See **docs/AGENTS.md** (Modes).

---

## 3. Prerequisites

| Need | Where |
|------|--------|
| Repo root | `AURA_ROOT` (default: parent of `bin/`) |
| Zig 0.15.2 | `.zig-version`, **docs/ZIG_VERSION.md** |
| Python 3.10+ | Gateway, vault, ai_agency_wealth (CrewAI) |
| Node (for web) | ai_agency_web (Vite) |
| Vault (keys) | `vault/aura-vault.json` or `AURA_VAULT_FILE`; **`aura vault`** to manage |

---

## 4. First-time setup (one flow)

From repo root (or with `AURA_ROOT` set):

```bash
# 1. Vault (API keys for gateway, agents)
aura vault

# 2. Optional: Zig TUI and mesh (build on first use)
aura tui        # builds tui if needed, then launches
aura mesh status   # builds aura-tailscale if needed

# 3. Gateway (IDEs, TUIs, chat → Groq)
aura gateway    # port 8765; keep running or run via systemd/stub

# 4. Chat with agent (uses gateway)
aura chat       # minimal TUI chat; ensure gateway is up (e.g. aura gateway in background)
```

No manual “you run this, then you run that.” In build mode the agent runs these; the operator only intervenes when overriding (dirty hands).

---

## 5. Daily commands (all via `aura`)

| Command | What it does |
|--------|----------------|
| `aura status` | System health, watchdog state |
| `aura start` / `aura stop` | Daemons (autopilot, pay, web) |
| `aura vault` | Manage API keys and secrets |
| `aura logs` | Tail agency execution log |
| `aura tui` | Zig TUI (dashboard, services, vault, logs) |
| `aura mesh up \| down \| status` | Sovereign mesh VPN |
| `aura gateway` | Syncing gateway (IDEs, TUIs, LLM clients) |
| `aura chat` | Minimal TUI chat with Aura agent (gateway required) |
| `aura api` | aura-api HTTP server (e.g. port 9000) |
| `aura skill` | Skills belt (list/show/run) |
| `aura docs-maid` | Docs sweep (inbox → docs/, channel) |
| `aura help` | CLI help |

Full command and build reference: **docs/AGENTS.md**. Pro guide: **docs/AURA_PRO_GUIDE.md**.

---

## 6. Where things live (logs and execution state)

| What | Where |
|------|--------|
| Agency execution log | `ai_agency_wealth/agency_metrics.log` (or **`aura logs`**) |
| Watchdog health | `ai_agency_wealth/watchdog_state.json` |
| Payment server log | `ai_agency_wealth/server.log` |
| Gateway | Port **8765**; vault keys, no keys in clients |
| Session sync (IDE/TUI/CLI) | `aura gateway` → GET/POST `/sync/session`; store under `AURA_ROOT/.aura/gateway_sessions.json` or `AURA_GATEWAY_SESSIONS` |
| Docs maid log | `vault/maid.log` |
| Forge checkpoint | `vault/forge_checkpoint.txt` |

Orchestrator runs (e.g. newsletter, lead gen) write into the agency log; the Zig TUI and **`aura logs`** consume it. No need to run commands manually to “find” logs—use the CLI and paths above.

---

## 7. Gateway and chat (seamless)

- **Start gateway:** `aura gateway` (or run via systemd/stub so it stays up).
- **Chat:** `aura chat` — minimal TUI chat with the Aura agent (Groq via gateway). Commands in chat: `/quit`, `/clear`.
- **Cursor/IDEs:** Point OpenAI base URL to `http://localhost:8765/v1`; gateway uses vault keys. See **gateway/README.md** for details.

All of this is automated from the single onboarding flow; in build mode the agent starts gateway/chat as needed.

---

## 8. Deeper docs (branch from here)

| Topic | Doc |
|-------|-----|
| Principles, modes, build/run commands | **docs/AGENTS.md** |
| Sovereign stack, mesh, MCP, Ziggy | **docs/AURA_PRO_GUIDE.md** |
| Gateway API, vault, Cursor | **gateway/README.md** |
| Aura-owned Dragun autobuild architecture | **docs/DRAGUN_AUTOBUILD_IMMUTABLE_ARCHITECTURE.md** |
| Deployment, devices, control script | **sovereign-stack/DEPLOYMENT.md**, **sovereign-stack/prod-control.sh** |
| Zig version and compiler | **docs/ZIG_VERSION.md**, **docs/ziggy-compiler.md** |

**Onboarding is here. Everything else branches from this.**
