# Self-Hosted Nexa Web Interface on the Mesh

This runbook defines the deployment path for `apps/web` on Nexa-managed infrastructure.

## Topology

- nginx is the only public HTTP ingress
- `nexa-web` runs the Next.js application server on `127.0.0.1:3003`
- `aura-gateway` remains on `127.0.0.1:8765`
- immutable releases live under `/opt/aura/apps/web/releases/<timestamp>`
- `/opt/aura/apps/web/current` points to the active web release
- shared configuration lives in `/opt/aura/apps/web/shared/.env.production`

## First-time VPS setup

Install runtime packages:

```bash
apt-get update
apt-get install -y nginx python3 python3-venv python3-pip rsync curl git nodejs npm
mkdir -p /opt/aura/apps/web/{releases,shared}
```

The deploy script copies the environment template to the VPS on first run. Fill the runtime configuration after that:

```bash
cp /opt/aura/apps/web/shared/.env.production.example /opt/aura/apps/web/shared/.env.production
chmod 600 /opt/aura/apps/web/shared/.env.production
```

## Deploy

From the repo root:

```bash
export VPS_IP=your-vps-ip
export VPS_USER=root
export VPS_DOMAIN=dragun.app
export NEXA_PUBLIC_WEB_URL=https://dragun.app
./ops/scripts/deploy-mesh.sh
```

The deploy script will:

- sync the application into a timestamped release directory
- sync a minimal npm workspace with the repo-root `package-lock.json`
- install pinned dependencies with `npm ci --workspace apps/web`
- build the web interface on the VPS
- enable and restart `nexa-web`
- update the `current` symlink only after a successful build
- reload nginx

## Validation

```bash
MESH_VPS_IP=your-vps-ip MESH_BASE_URL=https://dragun.app MESH_WEB_URL=https://dragun.app ./ops/scripts/smoke-test-mesh.sh
```

## Rollback

List releases:

```bash
ls -1 /opt/aura/apps/web/releases
```

Activate a previous release:

```bash
ln -sfn /opt/aura/apps/web/releases/<previous-release> /opt/aura/apps/web/current
systemctl restart nexa-web
```
