#!/usr/bin/env bash
# Deploy Nexa mesh services.
# Usage: VPS_IP=1.2.3.4 ./ops/scripts/deploy-mesh.sh
# On deploy: backs up all dynamic logs/json/md on the org device (VPS) then deletes them for a clean slate.
set -euo pipefail

VPS_IP="${VPS_IP:-}"
VPS_USER="${VPS_USER:-root}"
REPO_ROOT="${REPO_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
REMOTE_ROOT="${NEXA_REMOTE_ROOT:-${AURA_REMOTE_ROOT:-/opt/aura}}"
REMOTE_SCRIPTS_DIR="${NEXA_REMOTE_SCRIPTS_DIR:-${AURA_REMOTE_SCRIPTS_DIR:-$REMOTE_ROOT/scripts}}"
REMOTE_DOCS_DIR="${NEXA_REMOTE_DOCS_DIR:-${AURA_REMOTE_DOCS_DIR:-$REMOTE_ROOT/docs}}"
REMOTE_GATEWAY_DIR="${NEXA_REMOTE_GATEWAY_DIR:-${AURA_REMOTE_GATEWAY_DIR:-$REMOTE_ROOT/gateway}}"
REMOTE_STATIC_SITE_DIR="${NEXA_REMOTE_STATIC_SITE_DIR:-${AURA_REMOTE_STATIC_SITE_DIR:-/opt/apps/aura-landing-next}}"
REMOTE_WEB_ROOT="${NEXA_REMOTE_WEB_ROOT:-${AURA_REMOTE_WEB_ROOT:-$REMOTE_ROOT/apps/web}}"
REMOTE_WEB_RELEASES_DIR="${NEXA_REMOTE_WEB_RELEASES_DIR:-$REMOTE_WEB_ROOT/releases}"
REMOTE_WEB_SHARED_DIR="${NEXA_REMOTE_WEB_SHARED_DIR:-$REMOTE_WEB_ROOT/shared}"
REMOTE_WEB_CURRENT_LINK="${NEXA_REMOTE_WEB_CURRENT_LINK:-$REMOTE_WEB_ROOT/current}"
REMOTE_WEB_SERVICE="${NEXA_REMOTE_WEB_SERVICE:-nexa-web}"
REMOTE_WEB_PORT="${NEXA_REMOTE_WEB_PORT:-3003}"
REMOTE_DATA_DIR="${NEXA_REMOTE_DATA_DIR:-${AURA_REMOTE_DATA_DIR:-$REMOTE_ROOT/data}}"
REMOTE_LOG_DIR="${NEXA_REMOTE_LOG_DIR:-${AURA_REMOTE_LOG_DIR:-$REMOTE_ROOT/logs}}"
REMOTE_BACKUP_DIR="${NEXA_REMOTE_BACKUP_DIR:-${AURA_REMOTE_BACKUP_DIR:-$REMOTE_ROOT/.aura/backups}}"
REMOTE_GATEWAY_SERVICE="${NEXA_REMOTE_GATEWAY_SERVICE:-${AURA_REMOTE_GATEWAY_SERVICE:-aura-gateway}}"
REMOTE_WEB_SERVER_RELOAD="${NEXA_REMOTE_WEB_SERVER_RELOAD:-${AURA_REMOTE_WEB_SERVER_RELOAD:-nginx}}"
PUBLIC_BASE_URL="${NEXA_PUBLIC_BASE_URL:-${AURA_PUBLIC_BASE_URL:-${MESH_BASE_URL:-}}}"
PUBLIC_GATEWAY_URL="${NEXA_PUBLIC_GATEWAY_URL:-${AURA_PUBLIC_GATEWAY_URL:-}}"
DEPLOY_WEB_APP="${NEXA_DEPLOY_WEB_APP:-1}"
DEPLOY_LANDING="${NEXA_DEPLOY_LANDING:-auto}"

if [[ -z "$VPS_IP" ]]; then
  echo "[deploy-mesh] Set VPS_IP before running deploy." >&2
  exit 1
fi

if [[ "$DEPLOY_WEB_APP" == "1" && ! -f "${REPO_ROOT}/package-lock.json" ]]; then
  echo "[deploy-mesh] Missing repo-root package-lock.json. Refuse to deploy an unpinned web release." >&2
  exit 1
fi

if [[ -z "$PUBLIC_BASE_URL" ]]; then
  if [[ -n "${VPS_DOMAIN:-}" ]]; then
    PUBLIC_BASE_URL="https://${VPS_DOMAIN}"
  else
    PUBLIC_BASE_URL="http://${VPS_IP}"
  fi
fi

PUBLIC_GATEWAY_URL="${PUBLIC_GATEWAY_URL:-${PUBLIC_BASE_URL%/}/gw}"
PUBLIC_WEB_URL="${NEXA_PUBLIC_WEB_URL:-${AURA_PUBLIC_WEB_URL:-$PUBLIC_BASE_URL}}"
echo "[deploy-mesh] Target: ${VPS_USER}@${VPS_IP}"

# 0. Backup then delete dynamic files on VPS (logs, json, markdown) so deploy starts clean
echo "[deploy-mesh] Backup then delete dynamic files on server..."
ssh "${VPS_USER}@${VPS_IP}" "mkdir -p '$REMOTE_SCRIPTS_DIR' '$REMOTE_DATA_DIR' '$REMOTE_LOG_DIR' '$REMOTE_BACKUP_DIR' '$REMOTE_GATEWAY_DIR' '$REMOTE_WEB_RELEASES_DIR' '$REMOTE_WEB_SHARED_DIR'"
scp "${REPO_ROOT}/ops/scripts/backup-dynamic-then-delete.sh" "${VPS_USER}@${VPS_IP}:$REMOTE_SCRIPTS_DIR/backup-dynamic-then-delete.sh"
ssh "${VPS_USER}@${VPS_IP}" "chmod +x '$REMOTE_SCRIPTS_DIR/backup-dynamic-then-delete.sh' && NEXA_ROOT='$REMOTE_ROOT' AURA_ROOT='$REMOTE_ROOT' NEXA_LOG_DIR='$REMOTE_LOG_DIR' AURA_LOG_DIR='$REMOTE_LOG_DIR' NEXA_DATA_DIR='$REMOTE_DATA_DIR' AURA_DATA_DIR='$REMOTE_DATA_DIR' '$REMOTE_SCRIPTS_DIR/backup-dynamic-then-delete.sh'"

# 1. Ensure telemetry dir on server; sync docs for realtime GET /docs/aura (NotebookLM + agents)
echo "[deploy-mesh] Ensuring remote docs/data directories and syncing docs..."
ssh "${VPS_USER}@${VPS_IP}" "mkdir -p '$REMOTE_DATA_DIR' '$REMOTE_DOCS_DIR/updates'"
rsync -az --delete \
  "${REPO_ROOT}/docs/" \
  "${VPS_USER}@${VPS_IP}:$REMOTE_DOCS_DIR/"
for f in README.md DISCLAIMER.md; do
  [[ -f "${REPO_ROOT}/$f" ]] && scp "${REPO_ROOT}/$f" "${VPS_USER}@${VPS_IP}:$REMOTE_ROOT/"
done

echo "[deploy-mesh] Deploying Python Nexa gateway..."
rsync -az --delete \
  "${REPO_ROOT}/ops/gateway/" \
  "${VPS_USER}@${VPS_IP}:$REMOTE_GATEWAY_DIR/"
scp "${REPO_ROOT}/nexa_runtime.py" "${VPS_USER}@${VPS_IP}:$REMOTE_ROOT/nexa_runtime.py"
scp "${REPO_ROOT}/aura_runtime.py" "${VPS_USER}@${VPS_IP}:$REMOTE_ROOT/aura_runtime.py"

if [[ "$DEPLOY_WEB_APP" == "1" ]]; then
  WEB_RELEASE_ID="$(date -u +%Y%m%d%H%M%S)"
  REMOTE_WEB_RELEASE_DIR="$REMOTE_WEB_RELEASES_DIR/$WEB_RELEASE_ID"
  REMOTE_WEB_WORKSPACE_DIR="$REMOTE_WEB_RELEASE_DIR/workspace"
  REMOTE_WEB_APP_DIR="$REMOTE_WEB_WORKSPACE_DIR/apps/web"
  echo "[deploy-mesh] Deploying web release ${WEB_RELEASE_ID}..."
  ssh "${VPS_USER}@${VPS_IP}" "mkdir -p '$REMOTE_WEB_APP_DIR' '$REMOTE_WEB_SHARED_DIR'"
  scp "${REPO_ROOT}/package.json" "${VPS_USER}@${VPS_IP}:$REMOTE_WEB_WORKSPACE_DIR/package.json"
  scp "${REPO_ROOT}/package-lock.json" "${VPS_USER}@${VPS_IP}:$REMOTE_WEB_WORKSPACE_DIR/package-lock.json"
  rsync -az --delete \
    --exclude '.env.local' \
    --exclude '.git' \
    --exclude 'node_modules' \
    --exclude '.next' \
    "${REPO_ROOT}/apps/web/" \
    "${VPS_USER}@${VPS_IP}:$REMOTE_WEB_APP_DIR/"
  scp "${REPO_ROOT}/ops/config/nexa-web.service" "${VPS_USER}@${VPS_IP}:/etc/systemd/system/$REMOTE_WEB_SERVICE.service"
  scp "${REPO_ROOT}/ops/config/nexa-web.env.example" "${VPS_USER}@${VPS_IP}:$REMOTE_WEB_SHARED_DIR/.env.production.example"
  ssh "${VPS_USER}@${VPS_IP}" "\
    test -f '$REMOTE_WEB_SHARED_DIR/.env.production' || cp '$REMOTE_WEB_SHARED_DIR/.env.production.example' '$REMOTE_WEB_SHARED_DIR/.env.production'; \
    cd '$REMOTE_WEB_WORKSPACE_DIR' && npm ci --workspace apps/web --include-workspace-root --no-audit --no-fund && npm run build --workspace apps/web && \
    cd '$REMOTE_WEB_APP_DIR' && mkdir -p .next/standalone/.next && \
    rm -rf .next/standalone/.next/static && \
    cp -R .next/static .next/standalone/.next/static && \
    rm -rf .next/standalone/public && cp -R public .next/standalone/public && \
    ln -sfn '$REMOTE_WEB_APP_DIR' '$REMOTE_WEB_CURRENT_LINK' && \
    systemctl daemon-reload && systemctl enable '$REMOTE_WEB_SERVICE' && systemctl restart '$REMOTE_WEB_SERVICE'"
fi

# 2b. Deploy static site bundle
STATIC_SITE_OUT_DIR="${REPO_ROOT}/apps/aura-landing-next/out"
if [[ "$DEPLOY_LANDING" == "1" || ( "$DEPLOY_LANDING" == "auto" && -d "$STATIC_SITE_OUT_DIR" ) ]]; then
  echo "[deploy-mesh] Deploying static site bundle..."
  ssh "${VPS_USER}@${VPS_IP}" "mkdir -p '$REMOTE_STATIC_SITE_DIR/out'"
  rsync -az --delete \
    "${STATIC_SITE_OUT_DIR}/" \
    "${VPS_USER}@${VPS_IP}:$REMOTE_STATIC_SITE_DIR/out/"
elif [[ "$DEPLOY_LANDING" == "1" ]]; then
  echo "[deploy-mesh] Missing static site bundle at $STATIC_SITE_OUT_DIR. Build apps/aura-landing-next before deploy." >&2
  exit 1
else
  echo "[deploy-mesh] Skipping static site bundle deploy."
fi

# 3. Deploy nginx config
echo "[deploy-mesh] Deploying nginx.conf..."
scp "${REPO_ROOT}/ops/nginx/nginx.conf" "${VPS_USER}@${VPS_IP}:/etc/nginx/nginx.conf"

# 4. Reload nginx and restart gateway
echo "[deploy-mesh] Reloading nginx and restarting gateway..."
ssh "${VPS_USER}@${VPS_IP}" "nginx -t 2>&1 && systemctl reload '$REMOTE_WEB_SERVER_RELOAD' && systemctl restart '$REMOTE_GATEWAY_SERVICE' && echo 'gateway OK'"

# 5. Quick health check
echo "[deploy-mesh] Health check..."
if [[ "$DEPLOY_WEB_APP" == "1" ]]; then
  ssh "${VPS_USER}@${VPS_IP}" "curl -fsS http://127.0.0.1:8765/health && echo '' && curl -fsS http://127.0.0.1:8765/api/specs | head -c 200 && echo '' && curl -fsS http://127.0.0.1:${REMOTE_WEB_PORT}/api/health"
else
  ssh "${VPS_USER}@${VPS_IP}" "curl -fsS http://127.0.0.1:8765/health && echo '' && curl -fsS http://127.0.0.1:8765/api/specs | head -c 200"
fi

echo "[deploy-mesh] Done. Base URL: ${PUBLIC_BASE_URL%/} | Gateway: ${PUBLIC_GATEWAY_URL%/} | Web: ${PUBLIC_WEB_URL%/}"
