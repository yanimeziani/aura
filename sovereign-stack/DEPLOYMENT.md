# Deployment Architecture

Single public entry: **one domain** → **hotsinger kvm2 VPS** → Caddy → secure client funnel (onboarding, API, automation). All client traffic must enter via this domain.

---

## Approved deployment

**From any device (e.g. on Tailscale):** configure once, then run the full launch sequence.

1. **One-time setup** — in `sovereign-stack/`:
   ```bash
   cp sovereign-stack/.env.example sovereign-stack/.env
   # Edit .env: set DOMAIN, VPS_HOST (Tailscale name), VPS_USER, VPS_REPO_PATH
   ```
2. **Run approved deployment:**
   ```bash
   ./run lr
   ```
   This runs **launch-remote**: build frontend → rsync to VPS → start stack on VPS → run test on VPS.

**On the VPS only:** if you are already on the serving host with Docker and the repo:
   ```bash
   ./run lp
   ```
   This runs **launch**: deploy then test locally.

**First-time VPS setup (for launch-remote):** The repo must exist on the VPS at `VPS_REPO_PATH`. Clone once (if private repo, add the VPS SSH key as a GitHub deploy key first):
   ```bash
   ./run rx "git clone git@github.com:yanimeziani/aura-stack.git /root/aura-stack"
   ./run rx "cd /root/aura-stack/sovereign-stack && ./bootstrap-vps.sh"
   ```
   Then on the VPS: edit `sovereign-stack/.env` (DOMAIN, etc.), copy TLS cert/key into `sovereign-stack/` if Caddy uses them. After that, `./run lr` from any device will deploy and start the stack.

---

## Devices (same hardware, documented)

| Device / role      | What it is                | What runs on it |
|--------------------|----------------------------|-----------------|
| **hotsinger kvm2** | Single VPS (serving host)  | Docker Compose (Caddy, n8n, Postgres, Redis); optional host process: payment API on port 8000. |
| **Domain**         | One public hostname        | DNS points here to hotsinger kvm2; Caddy serves this hostname only (HTTPS + HTTP). |
| **Frontend**       | Static build (SPA)         | Served by Caddy from `sovereign-stack/frontend/` (populated by deploy). |
| **API**            | Payment/backend (FastAPI)  | Today: host process (e.g. systemd) on port 8000; Caddy proxies `/api/*` to it. |

No other devices or public entry points. Same devices = same execution path below.

---

## Execution (how to run it)

All commands assume you are on **hotsinger kvm2** (or a machine with the repo and env). For **seamless operations inside** the repo, use the single entry point from repo root:

```bash
./run deploy          # full deploy (build + copy + start)
./run deploy-remote   # build locally, rsync to VPS, start on VPS
./run start|stop|restart|status|test|logs|monitor
```

Or call **`sovereign-stack/prod-control.sh`** directly when you are already in the stack directory.

| Command | What it does |
|--------|----------------|
| `prod-control.sh deploy` | Pre-flight (env, deps) → build frontend → copy to `frontend/` → `docker compose up -d`. **Use this for a full deploy.** |
| `prod-control.sh start` | Start stack only (`docker compose up -d`). Use when frontend is already in place. |
| `prod-control.sh stop` | Stop stack (`docker compose down`). |
| `prod-control.sh restart` | Recreate and start (`docker compose up -d --force-recreate`). |
| `prod-control.sh status` | Container status (`docker compose ps`). |
| `prod-control.sh test` | Smoke check: compose ps, then n8n and Caddy (Host: $DOMAIN). Exits 1 if any check fails. |
| `prod-control.sh logs [service]` | Tail logs; optional service name. |
| `prod-control.sh monitor` | Watch status + Caddy + n8n every 5s. |

**Execution order for a clean run:**

1. On the VPS: ensure `sovereign-stack/.env` exists and has `DOMAIN=` set.
2. From repo root: `./sovereign-stack/prod-control.sh deploy`
3. After start: `./sovereign-stack/prod-control.sh test`
4. Optional: run payment API on host (port 8000), e.g. via systemd.

**Paths (override with env):**

- `REPO_ROOT` — repo root (auto-detected if it contains `sovereign-stack/` and `ai_agency_web/`).
- `SOVEREIGN_STACK_DIR` — directory of sovereign-stack (default: `$REPO_ROOT/sovereign-stack`).
- `FRONTEND_SRC` — directory of ai_agency_web for deploy (default: `$REPO_ROOT/ai_agency_web`).

---

## Current Fragilities (addressed where possible)

| Risk | Description | Mitigation in stack |
|------|-------------|---------------------|
| **Frontend outside stack** | React app (onboarding funnel) was not served by compose; manual or separate process. | Caddy now serves static from `./frontend` when present; use `prod-control.sh deploy` to build and copy. |
| **Backend on host only** | Payment API (port 8000) runs on host via `host.docker.internal`; no restart policy or healthcheck in compose. | Documented; consider adding `api` service to compose later. For now ensure host process is supervised (systemd or similar). |
| **No proxy timeouts** | Backend hang can wedge Caddy connections. | Caddy `reverse_proxy` now has `transport` timeouts. |
| **No Caddy healthcheck** | Compose could mark stack "up" while Caddy is not actually serving. | Caddy healthcheck added (local GET). |
| **No resource limits** | One service can OOM the host. | Soft `deploy.resources.limits.memory` added to all services. |
| **Control script mismatch** | `prod-control.sh` tested Tailscale hostname instead of `DOMAIN`. | Script now sources `DOMAIN` from `.env` for test/monitor. |
| **Single node** | No redundancy; VPS outage = full outage. | Accepted for current scale; document backup and restore. |
| **Secrets in .env** | Single file; no rotation story. | Use `.env.example`; never commit `.env`. Consider vault later. |

---

## Target Shape (short term)

```
                    [Internet]
                         |
                    [DOMAIN]
                         |
                    [Caddy]  :80/:443  (TLS, timeouts, healthcheck)
                    /  |  \
                   /   |   \
            static   /api   /automation
            (./frontend)   (host:8000)  (n8n)
                   |         |            |
            file_server   payment API   n8n container
                           (host)       postgres, redis
```

- **One deploy path:** build frontend → copy to `sovereign-stack/frontend` → `docker compose up -d`.
- **API:** Either keep on host (supervised) or add an `api` service to compose (build from `ai_agency_wealth`, run `prod_payment_server`).
- **Health:** Caddy, postgres, redis, n8n all have healthchecks; use `prod-control.sh test` after deploy.

---

## Payment API (host process on port 8000)

Caddy proxies `/api/*` to `host.docker.internal:8000`. Run the payment API on the host via systemd:

1. Copy and edit the example unit: `sovereign-stack/payment-api.service.example` → `/etc/systemd/system/payment-api.service` (set `User`, `WorkingDirectory`, `ExecStart`, `EnvironmentFile` to your paths and `ai_agency_wealth/.env`).
2. In `ai_agency_wealth/.env`: set `STRIPE_SECRET_KEY`, `STRIPE_WEBHOOK_SECRET`, `N8N_WEBHOOK_URL`.
3. `sudo systemctl daemon-reload && sudo systemctl enable --now payment-api`.

See comments in `payment-api.service.example` for details.

---

## Backups

- **Postgres:** `docker compose exec postgres pg_dump -U $POSTGRES_USER $POSTGRES_DB` (redirect to file or backup tool). Schedule via cron (e.g. daily) and store off-VPS.
- **n8n data:** Back up the n8n Docker volume (e.g. `docker run --rm -v sovereign-stack_n8n_data:/data -v /backup:/backup alpine tar czf /backup/n8n_data.tar.gz -C /data .`). Schedule similarly.
- Document your chosen schedule and retention (e.g. daily, keep 7) in runbooks or cron comments.

---

## Hardening checklist

- [x] Caddy: reverse_proxy timeouts
- [x] Caddy: healthcheck in compose
- [x] All services: memory limits
- [x] Frontend: served from stack when `./frontend` exists
- [x] prod-control.sh: uses DOMAIN from .env
- [x] API: systemd unit documented (`payment-api.service.example`)
- [x] Backups: postgres and n8n volume backup approach documented
- [x] TLS: Caddy defaults (optional: add `tls min_version` / ciphers in Caddyfile if required by policy)

---

## Deploy commands (summary)

From repo root, same devices as above:

```bash
./run deploy      # full deploy (or use prod-control.sh deploy)
./run test        # must pass after deploy
```

Seamless operations (all from repo root):

| Command | Purpose |
|--------|--------|
| **Two-letter** | **Full** | |
| `lp` | launch | **Full sequence:** deploy then test (on this machine) |
| `lr` | launch-remote | **Full sequence:** deploy-remote then test on VPS |
| `dp` | deploy | Build frontend, copy to stack, start |
| `dr` | deploy-remote | Build, rsync to VPS, start stack on VPS |
| `st` \| `sp` \| `rs` \| `ss` | start \| stop \| restart \| status | Compose control |
| `te` | test | Smoke check Caddy + n8n |
| `lo` \| `lo caddy` | logs [service] | Tail stack logs (follow) |
| `sm` | stream | **Drop-in streaming:** deploy.log + compose logs (Ctrl+C exits) |
| `sr` \| `re sm` | stream-remote \| remote stream | Stream from VPS (any Tailscale device) |
| `re <cmd>` | remote &lt;cmd&gt; | Run cmd on VPS (e.g. `re ss`, `re lo caddy`) |
| `mo` | monitor | Watch status every 5s |

**Drop-in stream monitoring and logging:** run `./run stream` to attach to a single live stream. It tails `sovereign-stack/deploy.log` (prefix `[deploy]`) and, when Docker is available, `docker compose logs -f` (prefix `[compose]`). Use Ctrl+C to exit. For logs of one service only: `./run logs caddy` or `./run logs n8n`.

---

### From any device on your Tailscale network

Use the VPS **Tailscale hostname** in `sovereign-stack/.env` so every device on your Tailnet can run deploy and streaming without being on the VPS:

1. **In `sovereign-stack/.env`** set:
   - `VPS_HOST=` to the machine’s Tailscale name (e.g. `myvps.5tail12345.ts.net` or the short name shown in the Tailscale admin).
   - `VPS_USER=` and `VPS_REPO_PATH=` as before.

2. **From any device** (laptop, another PC, etc.) that has the repo and Tailscale:
   - **Deploy:** `./run deploy-remote` (builds locally, rsyncs to VPS, starts stack).
   - **Stream logs:** `./run stream-remote` or `./run remote stream` (SSH to VPS and run `./run stream` there; you see the same live stream).
   - **Status / logs on VPS:** `./run remote status`, `./run remote logs`, `./run remote logs caddy`, `./run remote test`, etc.

No need to SSH manually; `./run remote <cmd>` runs `./run <cmd>` on the VPS. Ensure the device has the repo (clone or sync) and the same `.env` (or at least `VPS_HOST`, `VPS_USER`, `VPS_REPO_PATH`, optional `SSH_KEY_PATH`).

See **Execution** above for all commands and execution order.

### SSH and remote deploy (persist agent access to VPS)

To let the agent (or your machine) deploy to the VPS without interactive SSH prompts:

1. **SSH key (one-time)**  
   On your machine, use an existing key or create one:
   ```bash
   # If you don't have a key:
   ssh-keygen -t ed25519 -f ~/.ssh/id_ed25519 -N ""
   # Copy public key to VPS (run once, then you can log in without password):
   ssh-copy-id -i ~/.ssh/id_ed25519.pub VPS_USER@VPS_HOST
   ```
   Replace `VPS_USER` and `VPS_HOST` with your VPS user and host (e.g. `yani@89.116.170.202`).

2. **Persist VPS credentials in `.env` (not committed)**  
   In `sovereign-stack/`, copy the example and set VPS variables:
   ```bash
   cp sovereign-stack/.env.example sovereign-stack/.env
   # Edit .env and set at least:
   # DOMAIN=n8n.meziani.org
   # VPS_HOST=89.116.170.202
   # VPS_USER=yani
   # VPS_REPO_PATH=/home/yani/aura-stack
   # Optional: SSH_KEY_PATH=/home/yani/.ssh/id_ed25519
   ```
   The first SSH connection will add the VPS host key to `~/.ssh/known_hosts` (script uses `StrictHostKeyChecking=accept-new`), so later runs are non-interactive.

3. **Run remote deploy**  
   From repo root:
   ```bash
   ./sovereign-stack/deploy-remote.sh
   ```
   This builds the frontend locally, rsyncs it to the VPS, and runs `prod-control.sh start` on the VPS. Logs append to `sovereign-stack/deploy.log`.

### Deploy to VPS after pushing to GitHub

1. **On your machine:** Push code to GitHub (already done if you used the repo `aura-stack`).
2. **On the VPS (e.g. SSH in):**
   ```bash
   cd /home/yani   # or wherever you keep the repo
   git pull origin main
   ./sovereign-stack/prod-control.sh deploy
   ./sovereign-stack/prod-control.sh test
   ```
   If the repo is not on the VPS yet:
   ```bash
   git clone https://github.com/yanimeziani/aura-stack.git
   cd aura-stack
   # Copy or create sovereign-stack/.env with DOMAIN= and any secrets (do not commit .env)
   # Copy TLS cert/key into sovereign-stack/ if Caddy uses them
   ./sovereign-stack/prod-control.sh deploy
   ./sovereign-stack/prod-control.sh test
   ```

---

## Troubleshooting

### ERR_SSL_PROTOCOL_ERROR when opening the site

**Cause:** You opened the site by **IP** (e.g. `https://89.116.170.202`) instead of by **domain**. Caddy is configured only for the hostname in `DOMAIN`. TLS certificates are issued for that hostname, not for the server IP, so the browser reports an invalid or non‑TLS response.

**Fix:**

1. **Use the domain with HTTPS**  
   Open **`https://<your-domain>`** (e.g. `https://n8n.meziani.org` from your `.env`). Do not use `https://<server-ip>`.

2. **Check DNS**  
   The domain must resolve to your VPS IP (e.g. 89.116.170.202).  
   - `dig +short n8n.meziani.org` (or your `DOMAIN`) should return that IP.  
   - If it doesn’t, add or fix the A record at your DNS provider.

3. **Optional: HTTP by IP (no TLS)**  
   For quick checks you can use **`http://89.116.170.202`** (no `s` in `http`). The current Caddyfile serves only the configured domain; if you need the site to respond when opening the IP in the browser, you can add a separate HTTP-only block for the IP in the Caddyfile (see comment there). Prefer using the domain and HTTPS in production.
