# Latest: Automated Meziani AI Stack

*Snapshot for "latest on our automated meZiani AI" — Mar 2026.*

---

## 1. Meziani AI Management Stack (MAMS)

**Location:** `Documents/dev/pi-mono/packages/mams/`

- **What it is:** Protocol + engine for survival simulations with Human Viability Index (HVI), deterministic traces, token sandboxing, scenario modules, and a `ValidatorAgent`.
- **Status:** Implemented and tested.
  - `SimulationEngine`: time-stepped loop, HVI + Safe Mode, resource handling.
  - `SurvivalAgent`: LLM-driven decisions, `runTick()` → agents act in parallel.
  - Tests: `npx vitest --run test/engine.test.ts` (init, ticks, safe mode, gather).
- **Usage:** `import { SimulationEngine, SurvivalAgent } from "@mariozechner/mams";` — add agents, run ticks, read state.

---

## 2. Auto Proposal Engine (“The Eye”)

**Location:** `~/.gemini/antigravity/scratch/upwork-scraper/`

- **What it is:** **Meziani AI Labs — Auto Proposal Engine v2.0.** RSS job feeds → filter high-value leads → local LLM (Ollama `qwen3:8b`) generates proposals → saves to vault + optional SMTP send (`yani@meziani.ai`).
- **Feeds:** We Work Remotely (DevOps, Backend), RemoteOK (Security, AI). Keywords: security, architecture, ai, llm, agent, backend, rust, zig, etc. Rejects: unpaid, equity-only, low hourly.
- **Schedule:** Runs once at start, then **every 3 hours** via `setInterval` inside the Node process.
- **Automation:** Started by:
  - **Night Ops:** `night_ops.sh` deploys it as “The Eye” → `$LOG_DIR/eye.log`.
  - **War Machine:** `start.sh` runs `node …/upwork-scraper/index.js` → `/tmp/aura-eye.log`.
- **Requirements:** `.env` in scratch (e.g. `../.env`) with `SMTP_USER`, `SMTP_PASS` for auto-send; otherwise proposals only saved to `upwork-scraper/proposals/`. `sent_leads.json` prevents duplicate pitches.

---

## 3. AURA OS / Night Ops (full automation launcher)

**Location:** `~/.gemini/antigravity/scratch/night_ops.sh` (v2.1)

- **What it does:** One script to bring the whole stack up: RAM triage (Ollama 1 model, Node 512MB heap), Git sync to `yanimeziani/Aura-OS`, dependency check, then deploys:
  - **Dashboard Backend** (quick-cash-backend, port 8181)
  - **The Eye** (upwork-scraper)
  - **The Sniper** (sniper-node-zig, B2B outreach)
  - **SOC-CERT** (soc-cert-node, threat intel)
  - **Content Publisher** (attention-sucker, Dev.to pipeline)
  - **Agent Hub** (multi-agent RAG, if built)
  - **VA-Coder** (if present)
- **Logs:** `/tmp/aura-night-ops/*.log`, PIDs in `pids.txt`.
- **Not on cron:** Night Ops is manual (or you run it at login). Only **cron** you have is `@reboot …/syndicate/daemon.sh` (micro-business-ecosystem), not Meziani AI.

---

## 4. Identity & config layer (meziani.ai)

- **Planned/used everywhere:** `yani@meziani.ai` as owner/sender (SMTP, aura-core preconfig, PATH_TO_10K, MEM_CACHE).
- **Antigravity brain:** `aura-core-zig` + meziani.ai preconfig (identity defaults in config.zig) and Sovereign Probe / Auto Proposal branding live in `~/.gemini/antigravity/scratch/` and `brain/`.

---

## 5. Gaps / next steps (for “latest”)

| Item | Status |
|------|--------|
| MAMS | Shipped; extend with more scenarios / ValidatorAgent if needed. |
| Auto Proposal Engine | Live; runs when Night Ops or start.sh is used; 3h internal interval. |
| Scheduled automation | No systemd/cron for Night Ops or The Eye — if you want “always on,” add a user timer or cron for `night_ops.sh` or just `node …/upwork-scraper/index.js`. |
| Sniper (Zig) | Started by Night Ops if `sniper-node-zig` exists. |
| Agent 2 / avatar | Past session had `generate_agent2_avatar.py` (Yani Meziani digital twin); separate from this automation stack. |

---

---

## 6. Garbage cleanup

**Script:** `~/.gemini/antigravity/scratch/aura-garbage-cleanup.sh`

One-shot cleanup for AURA / Meziani AI cruft:

| What | Policy |
|------|--------|
| `/tmp/aura-*.log`, `aura-night-ops/*.log` | Remove older than **7 days** (config: `KEEP_LOGS_DAYS`) |
| Antigravity session logs `~/.config/Antigravity/logs/` | Remove session dirs older than **14 days** (`KEEP_ANTIGRAVITY_LOGS_DAYS`) |
| Antigravity brain cache `~/.gemini/antigravity/brain/` | Remove task dirs older than **30 days** (`KEEP_BRAIN_DAYS`) |
| Drkonqi crash reports `antigravity.*.ini` | Remove all |
| Proposal vault `upwork-scraper/proposals/` | Keep last **100** proposals, delete older (`KEEP_PROPOSALS`) |
| `sent_leads.json` | Trim to last **2000** entries if over (`MAX_SENT_LEADS`; requires `jq`) |
| **`--aggressive`** | Also remove conversation `.pb` files older than `KEEP_BRAIN_DAYS` |

**Usage:**
```bash
cd ~/.gemini/antigravity/scratch
./aura-garbage-cleanup.sh           # run cleanup
./aura-garbage-cleanup.sh --dry-run # show what would be removed
./aura-garbage-cleanup.sh --aggressive  # include old .pb conversations
KEEP_LOGS_DAYS=3 ./aura-garbage-cleanup.sh  # stricter log retention
```

**Scheduling (optional):** Add to cron for weekly cleanup, e.g.:
```cron
0 4 * * 0 /home/yani/.gemini/antigravity/scratch/aura-garbage-cleanup.sh
```

---

**TL;DR:** MAMS is implemented and tested. The **automated Meziani AI** that runs without you is **The Eye** (job scanner + LLM proposals + SMTP), started by **Night Ops** or **start.sh**; it repeats every 3h inside the process. There’s no OS-level schedule for Night Ops yet — add a cron/timer if you want it to survive reboots or run on a fixed schedule. **Garbage cleanup** is in `scratch/aura-garbage-cleanup.sh`; run manually or on a weekly cron.
