# Aura: The Pro's Guide

**Sovereign stack, mesh, MCP, Ziggy, and how to run it all.**

This document is your single source of truth for understanding and handling Aura like a pro. It is written to support deep learning, audio narration, and visual presentation—so every section builds a clear mental model and gives you the exact commands and concepts you need.

---

## Part 1: What Aura Is and Why It Matters

### The big idea

**Aura is an autonomous multi-agent command center and sovereign stack.** It does not depend on Cloudflare, Tailscale Inc, or third-party MCP runtimes for its core capabilities. Instead, it **owns the entire request lifecycle**—from the lowest network byte up to the frontend—and implements its own mesh VPN, edge protection, MCP servers, and compiler in **Zig**, locked to **0.15.2**.

Think of it in three layers:

1. **Own the network** — DDoS-style edge (aura-edge), sovereign mesh VPN (aura-tailscale), TLS and crypto via Zig `std.crypto`.
2. **Own the tooling** — Our own MCP servers (Zig + Python in-repo), our own compiler for our future language Ziggy (ziggy-compiler), our own CLI (`aura`).
3. **Own the process** — Attack team roster (Lead, Runner, Implementer, Reviewer, Scout), forge timeline (micro-tasks F01–F19), fluid markdown channel, checkpoint and safe ops only—with **escalation on your explicit instruction**.

You are the operator. The system executes, reports, and escalates when you say so. Nothing destructive happens unless you explicitly instruct it.

---

## Part 2: The Sovereign Stack in One Picture

### Layers (from the wire up)

| Layer        | Component        | What it does |
|-------------|------------------|--------------|
| **3/4**     | aura-edge        | DDoS-style protection, packet filtering; Zig HTTP listener. |
| **2.5**     | aura-tailscale   | Sovereign mesh VPN (Tailscale-like); WireGuard in Zig; `aura mesh up \| down \| status`. |
| **4/6**     | (planned)        | TLS termination with Zig `std.crypto`; no OpenSSL. |
| **7**       | (planned)        | “Zig Next.js”—SSR/SSG, io_uring/epoll, microsecond latency. |

All Zig code is **Zig 0.15.2** (see `.zig-version` and `docs/ZIG_VERSION.md`). From that baseline we **branch out to Ziggy**—our own language and our own compiler (ziggy-compiler): fast, transparent, real-time logs, alarms for security/performance/syntax/architecture.

### Repo at a glance

- **bin/aura** — Main CLI: `status`, `start`, `stop`, `vault`, `logs`, **tui**, **mesh**, `stub`, `help`.
- **aura-edge/** — Zig edge/DDoS prototype.
- **aura-tailscale/** — Zig mesh VPN (WireGuard constants, BLAKE2s hash in `wireguard.zig`; `root.zig` re-exports).
- **aura-mcp/** — Zig MCP server (stdio): `read_file`, `list_dir`, `ping`; scoped to **AURA_ROOT**.
- **ziggy-compiler/** — Our Ziggy compiler: `ziggyc`, lex stub, alarms, artifacts, lint report; `--lint-only` → `out/lint/report.jsonl`.
- **tui/** — Zig terminal UI: `aura tui`.
- **mcp/server.py** — Python MCP: mesh_status, mesh_up, mesh_down, aura_status, get_internal_mcp_registry.
- **vault/** — Secrets, MCP registry (`mcp_registry.json`), forge checkpoint (`forge_checkpoint.txt`), roster channel (`roster/CHANNEL.md`).
- **docs/** — AGENTS.md, roster, forge-timeline, ziggy-compiler spec, sovereign-mcp, ZIG_VERSION, aura-zig-network-stack.

---

## Part 3: Handling the CLI Like a Pro

### The `aura` command

From repo root, the entry point is **`aura`** (or `./bin/aura`). It routes to the right binary or script.

| Command        | What it does |
|----------------|--------------|
| `aura status`  | System health, agent states, watchdog state. |
| `aura start`   | Start Aura daemons (autopilot, pay, web). |
| `aura stop`    | Stop those daemons. |
| `aura vault`   | Manage API keys and secrets (vault_manager.py). |
| `aura logs`    | Tail agency metrics log. |
| **`aura tui`** | Launch the Zig TUI; builds `tui` on first run if needed. |
| **`aura mesh`**| Sovereign mesh: **`aura mesh up`**, **`aura mesh down`**, **`aura mesh status`**. Builds aura-tailscale on first run. |
| `aura stub`    | Run a command under persistent stub (respawn). |
| `aura help`    | Show CLI help. |

**Pro move:** Ensure Zig 0.15.2 is installed and `.zig-version` says `0.15.2`. Then `aura mesh status` and `aura tui` will build on first use and run from `aura-tailscale/zig-out/bin/aura-mesh` and `tui/zig-out/bin/aura-tui`.

---

## Part 4: Mesh VPN — Sovereign Tailscale

### What it is

**aura-tailscale** is a Tailscale-like mesh VPN implemented in Zig. Same zero-config idea; no dependency on Tailscale Inc. It uses the WireGuard protocol (Noise_IK, ChaCha20-Poly1305, BLAKE2s) via Zig `std.crypto`.

### What’s there today

- **CLI:** `aura mesh up | down | status | help` (or `aura-mesh` from `aura-tailscale/zig-out/bin/`).
- **Library:** `Config`, `Peer`, `MeshState` in `root.zig`; **wireguard.zig** has constants (CONSTRUCTION, IDENTIFIER, KEY_SIZE, MAC_SIZE, LABEL_*) and **hash(allocator, input)** (BLAKE2s-256) for the handshake.
- **Config from env:** `AURA_MESH_CONTROL_URL`, `AURA_MESH_AUTH_KEY` (used when control client is implemented).
- **Not yet:** Full WireGuard handshake, TUN device, control-plane client.

**Porting Tailscale and clients (this machine, KVM VPS, Z Fold 5):** See **docs/MESH_PORT_AND_CLIENTS.md**.

### Commands you need

```bash
cd aura-tailscale && zig build
zig build run -- status    # or: aura mesh status
zig build run -- up        # or: aura mesh up
zig build test             # run tests (config, wireguard constants, hash)
```

From repo root: **`aura mesh status`**, **`aura mesh up`**, **`aura mesh down`**.

---

## Part 5: MCP — Our Own Servers, Our Own Repo

### Philosophy

We do **not** depend on external MCP server packages. We implement the MCP surface ourselves (like Cloudflare’s Vinext for Next.js): protocol + tools in **our repo**, in Zig and Python. The internal registry (`vault/mcp_registry.json`) lists capabilities and points to **our** implementations only—no external install links.

### Two servers

1. **aura-mcp (Zig)** — Single binary, stdio, JSON-RPC. Tools:
   - **read_file** — Read a file under **AURA_ROOT** (path resolved and checked).
   - **list_dir** — List a directory under **AURA_ROOT**.
   - **ping** — Liveness; returns `pong`.

2. **mcp/server.py (Python)** — Aura CLI and registry. Tools:
   - **mesh_status**, **mesh_up**, **mesh_down**
   - **aura_status**, **aura_help**
   - **get_internal_mcp_registry** — Returns the vault registry (no external links).

### AURA_ROOT and “venv root”

**AURA_ROOT** is the single root directory under which MCP file tools operate. Paths are checked so the process cannot escape that root.

**Pro tip:** Use **rootless proot** as a “venv root”: set **AURA_ROOT** to the proot guest root. The MCP server then only sees and touches that tree—no real root required, same idea as an isolated env.

### Run aura-mcp

```bash
cd aura-mcp && zig build
./zig-out/bin/aura-mcp   # stdio; speak MCP JSON-RPC to it
```

### Run Python MCP (e.g. for Cursor)

Configure your MCP client to run `mcp/server.py` with stdio; ensure **AURA_ROOT** is set to your repo or proot root.

---

## Part 6: Ziggy and the Ziggy Compiler

### Zig version lock

- **One version:** **0.15.2** (`.zig-version` and `docs/ZIG_VERSION.md`).
- All Zig packages use `minimum_zig_version = "0.15.2"` in `build.zig.zon`.
- All Zig docs in the repo are written for 0.15.2. From that baseline we **branch out to Ziggy**.

### What Ziggy is

**Ziggy** is our language branching from Zig 0.15.2. We are building **our own compiler** (ziggy-compiler) for it: ultra fast, transparent, with **real-time logs** and **alarms** for security, performance, syntax, and architecture.

### Ziggy compiler today

- **Binary:** `ziggyc` (from `ziggy-compiler/`).
- **Commands:** `ziggyc --version`, `ziggyc <file.zig>`, **`ziggyc --lint-only <file>`** (writes **out/lint/report.jsonl**).
- **Modules:** lex (stub), alarms (categories + emitAlarm), artifacts (ensureOutDir → bin/lib/lint/reports), **lint** (LintReport, addFinding, writeToFile).
- **Spec:** `docs/ziggy-compiler.md` (principles, log stream, alarm categories, lint report format, artifact layout).

### Commands you need

```bash
cd ziggy-compiler && zig build
./zig-out/bin/ziggyc --version
./zig-out/bin/ziggyc src/main.zig          # phase=lex logs
./zig-out/bin/ziggyc --lint-only src/main.zig   # creates out/lint/report.jsonl
zig build test
```

### Lint report format

One line per finding (JSON Lines). Fields: **file**, **line**, **col**, **severity**, **rule_id**, **message**. Written to **out/lint/report.jsonl** when you pass **--lint-only**.

---

## Part 7: The Forge — Micro-Tasks and Overnight Runs

### What the forge is

The **forge timeline** (`docs/forge-timeline.md`) is a list of micro-tasks **F01–F19** that bootstrap the repo, build the Ziggy compiler skeleton, harden aura-mcp, add the lint report format, move WireGuard into aura-tailscale, and add the **forge runner** script. Every task has a **Verify** step. Execution is **safe only**: no destructive or irreversible operations unless you explicitly instruct escalation.

### Checkpoint and failure

- **Checkpoint file:** `vault/forge_checkpoint.txt` — one line, last successful task ID (e.g. `F19`).
- **On failure:** The runner writes **FORGE_FAILED=&lt;ID&gt;** (e.g. in `vault/forge_failed.txt`) and stops.

### The forge runner script

**`bin/forge-run.sh`** runs the verify steps for F01–F18 in order. For each ID it runs the verify command; on success it writes that ID to **vault/forge_checkpoint.txt**; on failure it writes FORGE_FAILED and exits 1.

**Pro move:** Run from repo root. Let it run overnight if you want; in the morning check **vault/forge_checkpoint.txt** or **vault/forge_failed.txt** to see how far it got.

```bash
./bin/forge-run.sh
```

No manual step editing is required inside the script—it encodes the verify commands from the timeline.

---

## Part 8: The Attack Team and the Channel

### Roles (hierarchy)

| Level | Role           | Scope |
|-------|----------------|--------|
| 1     | **Lead**       | Prioritise, assign, unblock, approve; single point of escalation; can instruct escalation on your explicit instruction. |
| 2     | **Runner**     | Execute forge tasks (F01–F19), run verify, write checkpoint / FORGE_FAILED. |
| 2     | **Implementer**| Implement code (ziggy-compiler, aura-mcp, aura-tailscale). |
| 2     | **Reviewer**   | Review output; validate verify steps; no destructive ops. |
| 3     | **Scout**      | Read-only; scan docs and channel; report blockers or ideas. |

All roles report to Lead. Runner, Implementer, and Reviewer can run in parallel on different task IDs when dependencies allow. **All roles have full access to all docs** and to the **fluid markdown channel**.

### The fluid channel

- **File:** **`vault/roster/CHANNEL.md`**
- **Rules:** Append-only; markdown; first line often `[Role] [Fnn] subject`, then body.
- **Use it for:** Task claim, status, blocker, handoff, checkpoint, questions.

Nobody is blocked on another except by timeline dependencies. Coordination happens in the channel.

---

## Part 9: Safe Ops and Escalation

### Default: safe only

- **No destructive or irreversible operations** unless you explicitly say so.
- **Forbidden:** Wipe, format, drop DB, overwrite production without backup, `rm -rf` on user data, irreversible key rotation.
- **Required:** New files, temp-then-move, append-only logs, read-only checks, build in `zig-out/` or `out/`, checkpoint in `vault/`.

### Escalate on your instruction

**The system must be able to escalate when you explicitly instruct it.** If you tell the operator to run a destructive or higher-privilege action, or to override a normal constraint, that instruction is **permitted**. Operator authority overrides default safeguards when **explicitly invoked**. So: handle Aura with confidence—default is safe; when you need to go further, say so clearly and the system can escalate.

---

## Part 10: Quick Reference — Commands and Paths

### Build and run (Zig 0.15.2)

```bash
# Edge
cd aura-edge && zig build && zig build run

# Mesh
aura mesh status   # or: cd aura-tailscale && zig build && zig build run -- status

# TUI
aura tui

# MCP (Zig)
cd aura-mcp && zig build && ./zig-out/bin/aura-mcp

# Ziggy compiler
cd ziggy-compiler && zig build && ./zig-out/bin/ziggyc --version
./zig-out/bin/ziggyc --lint-only src/main.zig
```

### Docs maid — one place, then sweep

**All docs go to one place first:** **`vault/docs_inbox/`**. A **persistent docs maid** sweeps that inbox into the right locations while you code with agents.

- **Inbox subdirs:** `docs_inbox/docs/` → moved to `docs/`; `docs_inbox/channel/` → appended to `vault/roster/CHANNEL.md` then removed; `docs_inbox/vault/` → moved to `vault/`. Root-level `*.md` in inbox → `docs/`.
- **Start maid (persistent):** `aura docs-maid` (loops every 60s; set `MAID_INTERVAL_SEC` to change). Or one-shot: `aura docs-maid sweep`.
- **Log:** `vault/maid.log`. Run the maid in the background or under `aura stub` so it keeps sweeping.

### Key paths

| Path | Purpose |
|------|--------|
| `bin/aura` | Main CLI. |
| `bin/forge-run.sh` | Forge runner (F01–F18 verify). |
| `bin/docs-maid` | Docs maid: sweep `vault/docs_inbox/` → docs/, channel, vault. |
| `vault/docs_inbox/` | **One place for docs**; maid sweeps to final locations. |
| `vault/maid.log` | Docs maid sweep log. |
| `docs/DISTRIBUTION.md` | How to distribute Aura state to the 3 machines (git internal remote, checklist). |
| `bin/distribute-state.sh` | Push to internal + optional SSH pull on other hosts (`AURA_DISTRIBUTE_HOSTS`). |
| `vault/forge_checkpoint.txt` | Last successful forge task ID. |
| `vault/forge_failed.txt` | FORGE_FAILED on first failure. |
| `vault/roster/CHANNEL.md` | Attack team fluid channel. |
| `vault/mcp_registry.json` | Internal MCP registry (no external links). |
| `docs/AGENTS.md` | Principles, roster, build commands, escalation. |
| `docs/forge-timeline.md` | Micro-tasks F01–F19, verify, checkpoint. |
| `docs/sovereign-mcp.md` | MCP philosophy, tools, AURA_ROOT, proot. |
| `docs/ziggy-compiler.md` | Ziggy compiler spec, alarms, lint, artifacts. |
| `docs/ZIG_VERSION.md` | Zig 0.15.2 lock and “branch out to Ziggy”. |
| `.zig-version` | 0.15.2. |

---

## Part 11: Teaching Summary — Handle Aura Like a Pro

1. **One CLI:** `aura` — use it for status, mesh, tui, vault, logs, start/stop.
2. **One Zig version:** 0.15.2 — lock and docs everywhere; Ziggy branches from here.
3. **Own the stack:** Edge, mesh, MCP, Ziggy compiler — all in-repo, sovereign.
4. **Own the process:** Roster (Lead → Runner/Implementer/Reviewer/Scout), channel (`vault/roster/CHANNEL.md`), forge timeline and `forge-run.sh`, checkpoint in `vault/`.
5. **Safe by default:** No destructive ops unless you explicitly instruct escalation.
6. **AURA_ROOT:** Confines MCP file tools; use rootless proot as a venv-style root if you want.
7. **Community + privatise:** We keep support for community packages; we slowly replace with our own implementations (MCP, mesh, Ziggy, edge) using our architecture. See **docs/COMMUNITY_AND_PRIVATE.md**.
8. **One place to look:** This guide plus `docs/AGENTS.md` and the paths table above—you have everything you need to get your ears and eyes blown away by what Aura is and how to handle it like a pro.

---

*End of Aura Pro Guide. For the latest task status and handoffs, check `vault/roster/CHANNEL.md` and `vault/forge_checkpoint.txt`.*
