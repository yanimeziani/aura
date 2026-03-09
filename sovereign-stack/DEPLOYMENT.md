# Deployment Architecture

Single public entry: **one domain** → **hotsinger kvm2 VPS** → Caddy → secure client funnel (onboarding, API, automation). All client traffic must enter via this domain.

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

All commands assume you are on **hotsinger kvm2** (or a machine with the repo and env). Use one control script: **`sovereign-stack/prod-control.sh`**.

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

- `SOVEREIGN_STACK_DIR` — directory of sovereign-stack (default: `/home/yani/sovereign-stack`).
- `FRONTEND_SRC` — directory of ai_agency_web for deploy (default: `/home/yani/ai_agency_web`).

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

## Hardening checklist

- [x] Caddy: reverse_proxy timeouts
- [x] Caddy: healthcheck in compose
- [x] All services: memory limits
- [x] Frontend: served from stack when `./frontend` exists
- [x] prod-control.sh: uses DOMAIN from .env
- [ ] API: move into compose or document systemd unit for host process
- [ ] Backups: postgres and n8n_data volume backup schedule
- [ ] TLS: optional explicit min version / ciphers in Caddy if needed

---

## Deploy commands (summary)

From repo root, same devices as above:

```bash
./sovereign-stack/prod-control.sh deploy   # full deploy
./sovereign-stack/prod-control.sh test    # must pass after deploy
```

See **Execution** above for all commands and execution order.

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
