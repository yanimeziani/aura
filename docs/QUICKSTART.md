# Nexa Quickstart — 99% automated, plug-and-play on any system

Architectural source of truth before refactors or deployment changes:

- [ARCHITECTURE.md](/root/docs/ARCHITECTURE.md)
- [PROTOCOL.md](/root/docs/PROTOCOL.md)
- [TRUST_MODEL.md](/root/docs/TRUST_MODEL.md)
- [THREAT_MODEL.md](/root/docs/THREAT_MODEL.md)

**Goal:** Almost every task is fully automated in a **safe**, **efficient**, and **standardized** way. Works on **Linux, macOS, and Windows** with a single entry point. You’re building the **OSS foundation** plus a **boilerplate workspace** for an **instant demo**, then **onboarding**.

---

## One entry point — Linux, macOS, Windows

**Requires:** Python 3.8+ (and Node 18+ for the demo dashboard). No other setup; clone and run.

| System   | Run from repo root |
|----------|---------------------|
| Linux/macOS | `./ops/bin/nexa demo` or `python3 nexa.py demo` |
| Windows  | `nexa.cmd demo` or `py -3 nexa.py demo` |

`NEXA_ROOT` defaults to the repo root (directory containing `nexa.py`). Same commands everywhere:

```bash
# Unix
./ops/bin/nexa help
./ops/bin/nexa demo
./ops/bin/nexa gateway
./ops/bin/nexa vault

# Windows (cmd)
nexa.cmd help
nexa.cmd demo
nexa.cmd gateway
nexa.cmd vault
```

**Automation commands (no manual steps):**

| Command | What it does |
|--------|----------------|
| `nexa deploy-mesh` | Deploy gateway + dashboard + landing to a VPS (backup first, then sync). Requires `VPS_IP`; `VPS_DOMAIN` or `NEXA_PUBLIC_BASE_URL` is recommended. |
| `nexa backup` | Backup dynamic logs/json/md; route to largest org node if configured. |
| `nexa docs-bundle` | Build the NotebookLM-safe doc bundle (core docs + `docs/updates/`). |
| `nexa smoke-test` | Run smoke tests against the deployed mesh. |
| `nexa demo` | **Instant demo:** start gateway + dashboard locally; open Mission Control. |
| `make verify-release` | Run the hermetic production verification gate in Docker before push/deploy. |

**Or use Make:**

```bash
make deploy-mesh
make backup
make demo
```

---

## Instant demo (boilerplate workspace)

To see Nexa in under a minute, no vault or VPS — **on any system**:

1. **Start the demo** (from repo root)
   - **Linux/macOS:** `./ops/bin/nexa demo` or `python3 nexa.py demo`
   - **Windows:** `nexa.cmd demo` or `py -3 nexa.py demo`
   This starts the gateway and (if Node is installed) the Mission Control dashboard locally.

2. **Open**
   - Dashboard: http://localhost:3003  
   - You’ll need a vault token to log in (see onboarding below).

3. **Public docs URL (NotebookLM / media)**  
   Once the gateway is up:  
   **http://localhost:8765/docs/nexa**  
   (Realtime bundle of core docs + `docs/updates/` — no logs, PII, or vault.)

---

## Onboarding (full foundation)

After the demo, to run the full stack and deploy:

1. **Vault (secrets once)**
   ```bash
   nexa vault
   ```
   Follow the prompts to set API keys and `NEXA_VAULT_TOKEN`. Then:
   ```bash
   nexa vault sync    # sync to .env targets
   ```

2. **Token for Mission Control**
   Use the vault token from the previous step (or run `nexa vault` → `rotate-token` and use the printed token) to log in at the dashboard.

3. **Deploy to your VPS**
   Set `VPS_IP`, `VPS_USER`, and either `VPS_DOMAIN` or `NEXA_PUBLIC_BASE_URL` first. For CI, also set `MESH_SSH_KEY`. Then:
   ```bash
   nexa deploy-mesh
   ```
   Or push to `main` (if GitHub Actions is configured) to deploy automatically.

5. **Run the release gate before deploy**
   ```bash
   make verify-release
   ```
   This validates the release from a clean Docker build context instead of relying on host-local Node state.

4. **Agents: document where it’s visible**
   All agent-written updates for the **public docs URL** must go under **`docs/updates/`**. They appear in realtime at `GET /docs/nexa`.

---

## Safe, efficient, standardized

- **Safe:** Backup runs before deploy; no logs/PII/vault in the public docs bundle; vault and tokens stay local or in env.
- **Efficient:** One command per task; idempotent deploy and backup; docs built on demand.
- **Standardized:** Same commands for everyone: `nexa deploy-mesh`, `nexa backup`, `nexa demo`, `make verify-release`. Env vars (`NEXA_ROOT`, `VPS_IP`, `NEXA_VAULT_FILE`, etc.) override paths and targets.

---

## The 1% that stays manual

- **First-time secrets:** Initial vault bootstrap (`nexa vault`) and storing the vault token.
- **Legal / policy:** Accepting DISCLAIMER and responsible use.
- **One-time infra:** SSH key to VPS, domain/DNS if you use your own.

Everything else — deploy, backup, docs, smoke test, demo — is one command.

---

## Plug-and-play on any system

- **Linux / macOS:** Run `./ops/bin/nexa <command>`. Uses `python3`; paths are resolved from repo root.
- **Windows:** Run `nexa.cmd <command>` or `py -3 nexa.py <command>`. For `backup` and `deploy-mesh` (bash scripts), Git Bash must be on PATH, or use WSL.
- **No hardcoded paths:** All defaults resolve from the repo root and the current stack layout. Override with `NEXA_ROOT`, `NEXA_VAULT_FILE`, `NEXA_DATA_DIR`, `NEXA_LOG_DIR`, `VPS_IP`, etc.
- **Transport-ready:** Set `NEXA_ROUTE_CLOUD_THROUGH_TOR=1` plus `NEXA_TOR_*` and `NEXA_IPFS_*` env vars to enable Tor-routed cloud egress and IPFS document transport through the gateway.
- **Same commands everywhere:** `demo`, `gateway`, `vault`, `docs-bundle`, `status` run natively on all platforms; `deploy-mesh`, `backup`, `smoke-test` run via bash when available.
