# Aura: Current State Log & Projection

**Log date:** 2026-03-09 (snapshot of workspace and `docs/` at this date.)

**Purpose:** Snapshot of the repo as it is, then the furthest coherent projection of the architectural logic **without inventing new goals or contradicting existing docs**. All claims are grounded in the codebase and `docs/`.

**Lock:** Zig 0.15.2 (see `docs/ZIG_VERSION.md`, `.zig-version`). Ziggy branches from this baseline; compiler: `ziggy-compiler/`.

---

## Part 1 — Current State Log

### 1.1 Workspace and build

| Item | State |
|------|--------|
| **Root** | `build.zig` + `build.zig.zon`; workspace builds 8 Zig packages (no cross-package Zig imports except aura-tailscale exe → aura_tailscale module). |
| **Zon deps** | `aura_edge`, `aura_api`, `aura_flow`, `aura_lynx`, `aura_mcp`, `aura_tailscale`, `tui`, `ziggy_compiler` — each path points to a subdir with its own `build.zig` / `build.zig.zon`. |
| **Build** | `zig build` from repo root installs all 8 artifacts; LSP/zls resolves Aura modules from root. |

### 1.2 Zig packages (artifact, module, entry, status)

| Package | Artifact | Library module | Root source | Entry (main) | Implemented vs stubbed |
|---------|----------|----------------|-------------|--------------|-------------------------|
| **aura-edge** | `aura_edge` | `aura_edge` (root: `src/root.zig`) | `src/root.zig` | `src/main.zig` | **Exe:** TCP listen 8080, in-memory per-IP rate limit (100/min), HTTP 200/429, static HTML. **Library:** root re-exports `http`, `proxy`, `cert`, `sni`, `limit`; **main does not use the module** — standalone server. |
| **aura-api** | `aura-api` | — | `src/main.zig` | same | HTTP API on `AURA_API_PORT` (default 9000). Routes: `/`, `/health`, `/status`, `/mesh`, `/providers`, `/sync/session` (GET/POST/DELETE). Session store in `var/aura-api/sessions/`; `sessions.syncFromGateway` when local miss (env: `AURA_GATEWAY_URL`). **Unused by main:** `sse.zig`, `ai.zig` (present, not imported). |
| **aura-flow** | `aura-flow` | — | `src/main.zig` | same | Webhook server on `AURA_FLOW_PORT` (default 9100). POST `/ops/stripe` → spool `stripe.ndjson`; POST `/ops/webhook`[/source] → spool `webhook-{source}.ndjson`. Optional worker thread: reads spool, runs `AURA_FLOW_PAYMENT_CMD` on payment events, rate-limited by `AURA_FLOW_PAYMENT_MIN_INTERVAL_SEC`. **Separate library surface:** `flow.zig`, `executor.zig`, `stripe.zig`, `worker.zig` (workflow DAG + Stripe parse + executor) — **not wired into the executable**; main is self-contained. |
| **aura-tailscale** | `aura-mesh` | `aura_tailscale` (root: `src/root.zig`) | `src/root.zig` | `src/main.zig` | **Exe:** CLI `up` / `down` / `status` / `daemon` / `help`; state in `~/.local/state/aura/mesh.state` or `AURA_STATE_DIR`. **Library:** wireguard (constants, KeyPair), tun, peers, registry, udp, control; daemon loop is stub (prints "Initiating handshake" per peer, no real handshake yet). |
| **aura-lynx** | `aura-lynx` | — | `src/main.zig` | same | CLI: `aura-lynx <URL>`. HTTP GET only; parse URL, fetch, strip HTML to text + links; print. No TLS. Android build step: `zig build mobile`. |
| **aura-mcp** | `aura-mcp` | — | `src/main.zig` | same | MCP server over stdio (newline-delimited JSON). Tools: `read_file`, `list_dir` (under `AURA_ROOT`), `ping`. Path resolution enforces root; no external MCP runtime. |
| **tui** | `aura-tui` | `tui` (root: `src/root.zig`) | `src/root.zig` | `src/main.zig` | Dashboard: systemctl status (aura_autopilot, ai_pay, ai_agency_web), mesh/traffic stub, menu (start/stop services, vault manager, logs, frontend build, webhooks, mesh curl). Uses `tui` module for root.zig (root currently minimal: bufferedPrint, add, tests). |
| **ziggy-compiler** | `ziggyc` | — | `src/main.zig` | same | CLI: `ziggyc <file>`. Pipeline: read file → **lex** (lex.zig) → **parse** (parse.zig) → print node count. No sema, lower, codegen, or lint wiring in main. **Other files:** ir, type, sema, symbol, lower, dump, dump_ir, lint, artifacts, alarms — present and used by each other where applicable; **main only uses lex + parse**. |

### 1.3 Internal import graph (Zig)

- **aura-edge:** root.zig → http, proxy, cert, sni, limit (all std only). main.zig → std only.
- **aura-api:** main.zig → sessions.zig. sessions.zig → std; syncFromGateway uses std.http.Client.
- **aura-flow:** main.zig → std only. flow.zig ← executor.zig, stripe.zig; worker.zig → flow, executor.
- **aura-tailscale:** root.zig → wireguard, tun, peers, registry, udp, control. registry/control → peers, wireguard. loop.zig → udp, tun, registry, wireguard. main.zig → aura_tailscale (module).
- **ziggy-compiler:** main → lex, parse. parse → lex. lower → parse, ir, type. dump_ir → ir. dump → parse, lex. sema → parse. type → parse.

### 1.4 Non-Zig components (in tree)

| Path | Role |
|------|------|
| **vault/** | vault_manager.py, browser sync, chrome backup; aura-vault.json (keys); mcp_registry.json (our MCP implementations). |
| **gateway/** | Python (if present); gateway URL used by aura-api sessions as `AURA_GATEWAY_URL`. |
| **ai_agency_wealth/** | Python automation (payments, lead gen, etc.); invoked by aura-flow worker via `AURA_FLOW_PAYMENT_CMD`. |
| **ai_agency_web/** | Frontend (e.g. Vite/TS); built separately; TUI can trigger `npm run build`. |
| **sovereign-stack/** | Deployment/run scripts (run-local, bootstrap). |
| **config/** | Configuration assets. |
| **docs/** | Source of truth for roadmap, Zig version, Ziggy compiler spec, sovereign MCP, mesh, forge timeline. |
| **.agents/skills/** | e.g. zig-ddos-protection (edge protection, rate limiting, egress monitoring); aligns with aura-edge evolution. |

### 1.5 Doc-aligned status (no editorializing)

- **aura-zig-network-stack.md:** Phase 1 = "Prototype the Zig TCP/HTTP listener (aura-edge)" — **done** (TCP + HTTP + rate limit in main). Phase 2 = TLS with std.crypto — **not done**. Phase 2.5 = mesh handshake + transport + TUN + control — **partial** (state + CLI + library surface; no full handshake). Phases 3–5 = XDP, Zig Next.js, swap Caddy — **not started**.
- **ziggy-compiler.md:** Lex + parse in use; real-time log stream, alarms, lint report artifact, phase timing — **partially implemented** (alarms/artifacts/lint exist as modules; not wired in main).
- **sovereign-mcp.md:** read_file, list_dir, ping in Zig — **done**. Git, fetch, Postgres, etc. — **planned**.
- **forge-timeline.md:** F01–F19; checkpoint in vault/forge_checkpoint.txt — **task list**; current code satisfies many F0x items (ziggy compiler skeleton, aura-mcp ping, wireguard.zig constants, etc.).

---

## Part 2 — Projection (furthest without accuracy degradation)

Projection follows **only** the order and goals already stated in the repo. No new layers or product goals are added.

### 2.1 Network stack (docs/aura-zig-network-stack.md)

1. **Phase 2 — TLS termination**  
   Next logical step: implement TLS in Zig using `std.crypto` (Ed25519, ChaCha20-Poly1305, etc.) and wire it into the **aura_edge** library (e.g. cert.zig, sni.zig) so the edge binary can terminate TLS. Current main does not use root.zig; a natural step is to have main (or a new runner) use `aura_edge` (root) so http + cert + sni are in the request path.

2. **Phase 2.5 — Mesh completion**  
   aura-tailscale: complete WireGuard handshake + transport, TUN I/O, and control-plane client (Headscale-compatible or Aura coordination). Docs already specify Noise_IK, ChaCha20-Poly1305, X25519, BLAKE2s. `loop.zig` and daemon in main are the natural place to drive handshake and TUN once crypto and control client exist.

3. **Phase 3 — XDP**  
   Add eBPF/XDP programs and a Zig control plane to drop/filter packets at line rate (rate limit, SYN flood, geo) as stated in the doc. This extends the “replace Cloudflare” goal without changing it.

4. **Phase 4 — Zig “Next.js”**  
   Layer 7: Zig HTTP server with io_uring/epoll, routing, and templating/JSX-like engine for serving Aura TUI backend and commercial pages. Doc already defines this; no new goal.

5. **Phase 5 — Edge router**  
   Swap Caddy for the custom Aura Edge Router (using aura_edge + TLS + XDP when available). Doc already states this.

### 2.2 Ziggy compiler (docs/ziggy-compiler.md)

- **Pipeline:** Wire **sema** and **type** into main after parse; then **lower** → IR; then codegen (or emit Zig). Main currently stops at parse; the next steps are in-repo and spec-aligned.
- **Observability:** Emit structured progress/alarm lines on stderr (phase=lex|parse|sema|…) and phase timing; use existing `alarms.zig` and `artifacts.zig` so behaviour matches the “real-time logs” and “alarming” design.
- **Lint:** `--lint-only` path: run lex/parse/sema + lint; write report to artifact (e.g. `out/lint/report.jsonl`) using the specified format and existing `lint.zig`.

### 2.3 Sovereign MCP (docs/sovereign-mcp.md)

- Extend **aura-mcp** with tools in the “Planned” table: git (e.g. status), fetch (URL), then Postgres/Supabase/Sentry/Memory/sequential think/Puppeteer as dedicated or extended tools. All in-repo; no new protocol goal.

### 2.4 aura-edge and DDoS skill (.agents/skills/zig-ddos-protection)

- Skill describes dynamic inbound filtering (reloadable rules, per-IP state, connection limits) and egress monitoring. **Current** main has a fixed per-IP rate limit and no egress monitoring. **Projection:** Evolve the running server to use the **aura_edge** module (root → limit, http, etc.), then add dynamic rules and outbound monitoring as in the skill, without changing the “sovereign edge” or Zig-only constraints.

### 2.5 aura-flow library surface

- **flow.zig**, **executor.zig**, **stripe.zig**, **worker.zig** form a workflow/Stripe execution path that is **not** used by the current executable. Projection: either (a) refactor main to use this pipeline for Stripe/webhook handling (single code path, testable), or (b) keep main as the fast spool-only path and use the library for a separate “replay” or “admin” tool. No new product goal; just resolving the existing two paths.

### 2.6 Ordering and dependencies

- TLS (Phase 2) does not depend on mesh or XDP. Mesh (2.5) and Ziggy pipeline/lint can proceed in parallel with TLS.
- XDP (Phase 3) and “Zig Next.js” (Phase 4) can be sequenced per team capacity; both assume a working edge (Phase 2).
- MCP tools and aura-edge DDoS evolution are independent of Ziggy; they can run in parallel with compiler work.
- Forge timeline (F01–F19) and `vault/forge_checkpoint.txt` remain the micro-task checklist; projection above is phase-level and does not replace it.

---

## Summary

- **Current state:** 8 Zig packages build; aura-edge and aura-api and aura-flow and aura-mcp and aura-lynx and tui and ziggyc/aura-mesh are runnable. Library surfaces exist for aura_edge, aura_tailscale, and tui; aura-flow has an unused workflow library. Ziggy has lex + parse in main; sema/lower/lint/alarms/artifacts are in-tree but not wired in main. Docs define Phases 1–5 (network), Ziggy design, sovereign MCP, and forge tasks.
- **Projection:** Implement Phase 2 (TLS) and complete Phase 2.5 (mesh handshake + TUN + control); wire Ziggy sema → lower → codegen and lint report; extend aura-mcp tools; evolve aura-edge to use its module and the DDoS skill; then Phases 3–5 and MCP extensions in the order and scope already written. No new architectural goals; only execution of the stated roadmap.
