# Aura: Operations State, Comms Delivery & Conversions Report

**Report date:** 2026-03-09  
**Scope:** Full machine state, channel/comms delivery, and conversion-related metrics.

---

## 1. Operations state

### 1.1 Systemd daemons

| Service | State | Notes |
|--------|--------|--------|
| **aura_autopilot.service** | active (running) | Autopilot loop (aura-stub duplicate → autopilot.sh). |
| **ai_pay.service** | active (running) | Payment API / payment automation. |
| **ai_agency_web.service** | active (running) | Web frontend service. |

All three Aura systemd units are **active**.

### 1.2 Zig binaries (build state)

| Package | Binary | Status |
|---------|--------|--------|
| aura-edge | aura_edge | Built (zig-out/bin) |
| aura-api | aura-api | Built |
| aura-flow | aura-flow | Built |
| aura-tailscale | aura-mesh | Built |
| tui | aura-tui | Built |
| aura-mcp | aura-mcp | Built |
| aura-lynx | aura-lynx | Built |
| ziggy-compiler | ziggyc | Built |

All 8 packages have artifacts present.

### 1.3 Listening ports and processes

| Port | Purpose | Status |
|------|---------|--------|
| **8080** | aura-edge (Zig edge) | In use (rootlessport/Podman proxy — not confirmed as aura_edge process). |
| **9000** | aura-api | Free — **aura-api not running**. |
| **9100** | aura-flow | Free — **aura-flow not running**. |
| **8765** | gateway (Python) | Free — **gateway not running**. |
| **8000** | prod_payment_server (uvicorn) | In use (ai_agency_wealth). |

**Running Aura-related processes (sampled):**
- docs-maid (bash, PID 293324) — continuous sweep loop.
- prod_payment_server (uvicorn, port 8000) — payment API.
- systemd-managed: aura_autopilot, ai_pay, ai_agency_web.

**Not running (no process on expected port):** aura-api, aura-flow, gateway. aura_edge binary exists but listener on 8080 is attributed to rootlessport.

### 1.4 Health snapshot

- **watchdog_state.json:** `status: HEALTHY`, `issues: []`, timestamp 2026-03-09T19:50:00.
- **Forge checkpoint:** `vault/forge_checkpoint.txt` = **G100** (culmination benchmark).

---

## 2. Comms delivery report

### 2.1 Channel (vault/roster/CHANNEL.md)

- **Line count:** 315 lines.
- **Role:** Append-only fluid markdown; all roles read/write; task claims and status.
- **Recent traffic:** G80–G100 (sovereign stack integration, fuzz stub, G100 culmination). Earlier: G01–G04 (lexer, handshake, /mesh, gateway audit), G50–G59 (aura-flow workflow engine).
- **Delivery:** Inbox → channel is via docs-maid: files in `vault/docs_inbox/channel/` are appended to CHANNEL.md and then removed. No separate “delivery” queue; comms are written directly to CHANNEL or arrive via inbox sweep.

### 2.2 Docs maid (comms sweep)

- **State:** Running (PID 293324), interval 60s.
- **Log:** `vault/maid.log`.
- **Recent activity (today):** Maid started 19:48; swept `roadmap_G20_G100.md` from inbox into docs/. Earlier today: gateway-audit-G04, launch doc; test-sweep earlier.
- **Delivery flow:** `vault/docs_inbox/docs/` → `docs/`; `vault/docs_inbox/channel/` → append to `vault/roster/CHANNEL.md`; `vault/docs_inbox/vault/` → `vault/`. Root-level `.md` in inbox → `docs/` (timestamped if name clash).

### 2.3 Session sync (aura-api)

- **Store:** `var/aura-api/sessions/` — one file per workspace_id.
- **Current count:** 0 session files.
- **Delivery:** GET/POST/DELETE `/sync/session`; on local miss, aura-api can `syncFromGateway` (AURA_GATEWAY_URL). With aura-api and gateway both down, no session sync delivery is occurring.

### 2.4 MCP / registry

- **Registry:** `vault/mcp_registry.json` — points to in-repo MCP implementations only.
- **Zig MCP (aura-mcp):** read_file, list_dir, ping; stdio, AURA_ROOT-scoped. Delivery is request/response (no persistent queue).
- **Python MCP (mcp/server.py):** mesh_status, mesh_up, mesh_down, aura_status, get_internal_mcp_registry. Not measured for “delivery” in this report.

---

## 3. Conversions report

### 3.1 Webhook / event ingestion (aura-flow spool)

- **Spool dir:** `var/aura-flow/spool/`.
- **Files:** stripe.ndjson (3 lines), webhook-generic.ndjson (1 line), webhook-github.ndjson (1 line), stripe.offset, worker.state, worker_runs.log.
- **Conversion meaning here:** Inbound webhooks (Stripe, generic, GitHub) are “delivered” by being written to NDJSON spool. Worker (when aura-flow runs) reads spool and runs payment automation (e.g. automation_master.sh) on payment events — that is the “conversion” from event → fulfillment run.
- **Current state:** aura-flow process is **not running**, so new webhooks would not be accepted (no listener on 9100), and the existing spool is **not** being processed by the worker. Historical lines (3 Stripe, 2 webhook) are on disk; conversion (event → automation run) only happens when aura-flow is up with worker enabled.

### 3.2 Payment / automation conversions

- **Trigger:** Stripe events (e.g. checkout.session.completed, payment_intent.succeeded) spooled to stripe.ndjson; worker invokes `AURA_FLOW_PAYMENT_CMD` (e.g. automation_master.sh), rate-limited by `AURA_FLOW_PAYMENT_MIN_INTERVAL_SEC`.
- **Metric:** No aggregate “conversion count” is written in-repo; only spool files and worker.state/worker_runs.log. For a count of “payment events that led to automation run,” one would parse worker_runs.log or automation logs.
- **Prod payment server:** Running on 8000 (uvicorn); handles payment API; separate from aura-flow webhook ingestion.

### 3.3 Session “conversions” (sync)

- Session set (POST /sync/session) = store payload for workspace_id. Get = retrieve. No “conversion” in a funnel sense; delivery success = 200 and presence in store.
- **Current:** 0 sessions in store; aura-api down → no new session writes or syncs.

### 3.4 Summary table (conversions / delivery)

| Flow | Inbound | “Conversion” / delivery | Current state |
|------|--------|-------------------------|---------------|
| Webhook → automation | POST /ops/stripe, /ops/webhook | Event written to spool → worker runs payment cmd | Spool has 5 NDJSON lines; worker not running (aura-flow down). |
| Session sync | POST /sync/session | Payload stored in var/aura-api/sessions/ | 0 sessions; aura-api down. |
| Channel comms | Inbox channel/* or direct append | Appended to CHANNEL.md | Maid running; 315 lines in CHANNEL. |
| Docs | Inbox docs/* or *.md | Moved to docs/ | Maid running; recent sweeps logged. |

---

## 4. Summary

- **Operations:** Systemd stack (autopilot, ai_pay, ai_agency_web) is up; watchdog HEALTHY; Zig binaries built; forge at G100. aura-api, aura-flow, and gateway are **not** running (ports 9000, 9100, 8765 free). Edge port 8080 in use by rootlessport, not confirmed as aura_edge.
- **Comms delivery:** Channel (315 lines) and docs maid are active; session sync and API-backed delivery are down while aura-api and gateway are stopped.
- **Conversions:** Webhook→automation conversion is paused (aura-flow and worker not running); spool holds 3 Stripe + 2 webhook lines. Session store empty; no session delivery. Payment server (8000) is up for payment API traffic.

To run the “full machine” including Zig HTTP services: start **aura-api** (9000), **aura-flow** (9100), and optionally **gateway** (8765) and **aura_edge** (8080) as needed.
