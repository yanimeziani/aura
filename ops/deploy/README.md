# Pegasus Debian VPS Deploy

This deploy stack runs the full Pegasus project from one repository:

- `pegasus-web` (Kotlin/Ktor web entry)
- `pegasus-api` (FastAPI backend)
- Host `caddy` service (TLS + reverse proxy)

## Domains

- `pegasus.meziani.org` -> web UI
- `api.pegasus.meziani.org` -> API

Point both DNS records to your VPS IPv4 address.

## 1) Configure environment

```bash
cd ops/deploy
cp .env.example .env
```

Set at least:

- `PEGASUS_ADMIN_PASSWORD`

## 2) Deploy from local machine

From repo root:

```bash
VPS_HOST=your.vps.ip VPS_USER=root VPS_PORT=22 ops/deploy/deploy_vps.sh
```

## 3) Validate

```bash
curl -I https://pegasus.meziani.org
curl -I https://api.pegasus.meziani.org/health
```

## Notes

- Data is stored in Docker volume `pegasus-data` mounted at `/data/cerberus` inside the API container.
- For Cerberus runtime integration, run Cerberus on the same VPS and share `/data/cerberus` with the runtime process.
