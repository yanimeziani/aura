#!/usr/bin/env bash
# Deploy Nexa mesh: in-house Zig gateway surface only.
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
REMOTE_DATA_DIR="${NEXA_REMOTE_DATA_DIR:-${AURA_REMOTE_DATA_DIR:-$REMOTE_ROOT/data}}"
REMOTE_LOG_DIR="${NEXA_REMOTE_LOG_DIR:-${AURA_REMOTE_LOG_DIR:-$REMOTE_ROOT/logs}}"
REMOTE_BACKUP_DIR="${NEXA_REMOTE_BACKUP_DIR:-${AURA_REMOTE_BACKUP_DIR:-$REMOTE_ROOT/.aura/backups}}"
REMOTE_GATEWAY_SERVICE="${NEXA_REMOTE_GATEWAY_SERVICE:-${AURA_REMOTE_GATEWAY_SERVICE:-aura-gateway}}"
REMOTE_WEB_SERVER_RELOAD="${NEXA_REMOTE_WEB_SERVER_RELOAD:-${AURA_REMOTE_WEB_SERVER_RELOAD:-nginx}}"
PUBLIC_BASE_URL="${NEXA_PUBLIC_BASE_URL:-${AURA_PUBLIC_BASE_URL:-}}"
PUBLIC_GATEWAY_URL="${NEXA_PUBLIC_GATEWAY_URL:-${AURA_PUBLIC_GATEWAY_URL:-}}"

if [[ -z "$VPS_IP" ]]; then
  echo "[deploy-mesh] Set VPS_IP before running deploy." >&2
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
echo "[deploy-mesh] Target: ${VPS_USER}@${VPS_IP}"

# 0. Backup then delete dynamic files on VPS (logs, json, markdown) so deploy starts clean
echo "[deploy-mesh] Backup then delete dynamic files on server..."
ssh "${VPS_USER}@${VPS_IP}" "mkdir -p '$REMOTE_SCRIPTS_DIR' '$REMOTE_DATA_DIR' '$REMOTE_LOG_DIR' '$REMOTE_BACKUP_DIR' '$REMOTE_GATEWAY_DIR'"
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
scp "${REPO_ROOT}/aura_runtime.py" "${VPS_USER}@${VPS_IP}:$REMOTE_ROOT/aura_runtime.py"

# 3. Deploy nginx config
echo "[deploy-mesh] Deploying nginx.conf..."
scp "${REPO_ROOT}/ops/nginx/nginx.conf" "${VPS_USER}@${VPS_IP}:/etc/nginx/nginx.conf"

# 4. Reload nginx and restart gateway
echo "[deploy-mesh] Reloading nginx and restarting gateway..."
ssh "${VPS_USER}@${VPS_IP}" "nginx -t 2>&1 && systemctl reload '$REMOTE_WEB_SERVER_RELOAD' && systemctl restart '$REMOTE_GATEWAY_SERVICE' && echo 'gateway OK'"

# 5. Quick health check
echo "[deploy-mesh] Health check..."
ssh "${VPS_USER}@${VPS_IP}" "curl -s http://127.0.0.1:8765/health && echo '' && curl -s http://127.0.0.1:8765/api/specs | head -c 200"

echo "[deploy-mesh] Done. Mission Control: ${PUBLIC_GATEWAY_URL%/}"
