#!/usr/bin/env bash
# Deploy from this machine to the VPS: build frontend, rsync to VPS, start stack via SSH.
# Requires: .env with VPS_HOST, VPS_USER, VPS_REPO_PATH. Optional: SSH_KEY_PATH.
# Persist SSH access: use a key in ~/.ssh/ and add it to .env as SSH_KEY_PATH (or rely on default).
# See DEPLOYMENT.md § SSH and remote deploy.
set -euo pipefail

STACK_DIR="${SOVEREIGN_STACK_DIR:-$(cd "$(dirname "$0")" && pwd)}"
cd "$STACK_DIR"

if [ ! -f .env ]; then
  echo "error: .env missing. Copy .env.example and set VPS_HOST, VPS_USER, VPS_REPO_PATH."
  exit 1
fi
set -a
# shellcheck source=/dev/null
source .env
set +a

for v in VPS_HOST VPS_USER VPS_REPO_PATH; do
  if [ -z "${!v:-}" ]; then
    echo "error: $v not set in .env"
    exit 1
  fi
done

FRONTEND_SRC="${FRONTEND_SRC:-/home/yani/ai_agency_web}"
if [ ! -d "$FRONTEND_SRC" ]; then
  echo "error: frontend source not found: $FRONTEND_SRC (set FRONTEND_SRC)"
  exit 1
fi

# SSH: use key if set; accept new host keys and persist to known_hosts
if [ -n "${SSH_KEY_PATH:-}" ]; then
  RSH="ssh -i ${SSH_KEY_PATH} -o StrictHostKeyChecking=accept-new"
else
  RSH="ssh -o StrictHostKeyChecking=accept-new"
fi

REMOTE="${VPS_USER}@${VPS_HOST}"
REMOTE_FRONTEND="${VPS_REPO_PATH}/sovereign-stack/frontend"
DEPLOY_LOG="${STACK_DIR}/deploy.log"

log() { echo "[$(date -Iseconds)] $*"; }

{
  log "=== deploy-remote start ==="
  log "build frontend..."
  (cd "$FRONTEND_SRC" && npm run build)
  log "rsync frontend to ${REMOTE}:${REMOTE_FRONTEND}"
  rsync -avz --delete -e "$RSH" "$FRONTEND_SRC/dist/" "${REMOTE}:${REMOTE_FRONTEND}/"
  log "start stack on VPS..."
  $RSH "$REMOTE" "cd ${VPS_REPO_PATH} && ./sovereign-stack/prod-control.sh start"
  log "deploy-remote done."
} 2>&1 | tee -a "$DEPLOY_LOG"
exit "${PIPESTATUS[0]}"
