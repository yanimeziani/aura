#!/usr/bin/env bash
set -euo pipefail

VPS_HOST="${VPS_HOST:-}"
VPS_USER="${VPS_USER:-root}"
VPS_PORT="${VPS_PORT:-22}"
REMOTE_DIR="${REMOTE_DIR:-/opt/pegasus}"

if [[ -z "${VPS_HOST}" ]]; then
  echo "VPS_HOST is required"
  exit 1
fi

echo "[1/5] Creating remote directory"
ssh -p "${VPS_PORT}" "${VPS_USER}@${VPS_HOST}" "mkdir -p '${REMOTE_DIR}'"

echo "[2/5] Syncing repository"
rsync -az --delete \
  --exclude '.git' \
  --exclude '.gradle' \
  --exclude 'app/build' \
  --exclude 'web/build' \
  -e "ssh -p ${VPS_PORT}" \
  ./ "${VPS_USER}@${VPS_HOST}:${REMOTE_DIR}/"

echo "[3/5] Preparing deployment env"
ssh -p "${VPS_PORT}" "${VPS_USER}@${VPS_HOST}" "cp -n '${REMOTE_DIR}/ops/deploy/.env.example' '${REMOTE_DIR}/ops/deploy/.env' || true"

echo "[4/5] Starting stack with Docker Compose"
ssh -p "${VPS_PORT}" "${VPS_USER}@${VPS_HOST}" "cd '${REMOTE_DIR}/ops/deploy' && docker compose up -d --build"

echo "[5/5] Updating host Caddy routes"
ssh -p "${VPS_PORT}" "${VPS_USER}@${VPS_HOST}" "cp '${REMOTE_DIR}/ops/caddy/Caddyfile' /etc/caddy/Caddyfile && systemctl reload caddy"

echo "Deployment complete"
echo "Web: https://pegasus.meziani.org"
echo "API: https://api.pegasus.meziani.org"
