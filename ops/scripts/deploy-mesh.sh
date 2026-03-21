#!/usr/bin/env bash
# Deploy Nexa mesh services.
# Usage: VPS_IP=1.2.3.4 ./ops/scripts/deploy-mesh.sh
# The VPS runs as a synced node of the Git repository plus a separate runtime directory.
set -euo pipefail

VPS_IP="${VPS_IP:-}"
VPS_USER="${VPS_USER:-root}"
REPO_ROOT="${REPO_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
NEXA_SSH_KEY_FILE="${NEXA_SSH_KEY_FILE:-}"
REMOTE_ROOT="${NEXA_REMOTE_ROOT:-${AURA_REMOTE_ROOT:-/opt/nexa}}"
REMOTE_RUNTIME_ROOT="${NEXA_RUNTIME_ROOT:-$REMOTE_ROOT/runtime}"
REMOTE_REPO_DIR="${NEXA_REPO_DIR:-$REMOTE_ROOT/repo}"
REMOTE_SCRIPTS_DIR="${NEXA_REMOTE_SCRIPTS_DIR:-${AURA_REMOTE_SCRIPTS_DIR:-$REMOTE_RUNTIME_ROOT/scripts}}"
REMOTE_DOCS_DIR="${NEXA_REMOTE_DOCS_DIR:-${AURA_REMOTE_DOCS_DIR:-$REMOTE_RUNTIME_ROOT/docs}}"
REMOTE_STATIC_SITE_DIR="${NEXA_REMOTE_STATIC_SITE_DIR:-${AURA_REMOTE_STATIC_SITE_DIR:-/opt/apps/nexa-public}}"
REMOTE_WEB_ROOT="${NEXA_REMOTE_WEB_ROOT:-${AURA_REMOTE_WEB_ROOT:-$REMOTE_RUNTIME_ROOT/apps/web}}"
REMOTE_WEB_SHARED_DIR="${NEXA_REMOTE_WEB_SHARED_DIR:-$REMOTE_WEB_ROOT/shared}"
REMOTE_WEB_SERVICE="${NEXA_REMOTE_WEB_SERVICE:-nexa-web}"
REMOTE_WEB_PORT="${NEXA_REMOTE_WEB_PORT:-3003}"
REMOTE_DATA_DIR="${NEXA_REMOTE_DATA_DIR:-${AURA_REMOTE_DATA_DIR:-$REMOTE_RUNTIME_ROOT/data}}"
REMOTE_LOG_DIR="${NEXA_REMOTE_LOG_DIR:-${AURA_REMOTE_LOG_DIR:-$REMOTE_RUNTIME_ROOT/logs}}"
REMOTE_BACKUP_DIR="${NEXA_REMOTE_BACKUP_DIR:-${AURA_REMOTE_BACKUP_DIR:-$REMOTE_RUNTIME_ROOT/.nexa/backups}}"
REMOTE_GATEWAY_SERVICE="${NEXA_REMOTE_GATEWAY_SERVICE:-${AURA_REMOTE_GATEWAY_SERVICE:-nexa-gateway}}"
REMOTE_WEB_SERVER_RELOAD="${NEXA_REMOTE_WEB_SERVER_RELOAD:-${AURA_REMOTE_WEB_SERVER_RELOAD:-nginx}}"
REMOTE_REPO_URL="${NEXA_REPO_URL:-${GITHUB_SERVER_URL:-https://github.com}/${GITHUB_REPOSITORY:-yanimeziani/nexa}.git}"
REMOTE_REPO_REF="${NEXA_REPO_REF:-main}"
PUBLIC_BASE_URL="${NEXA_PUBLIC_BASE_URL:-${AURA_PUBLIC_BASE_URL:-${MESH_BASE_URL:-}}}"
PUBLIC_GATEWAY_URL="${NEXA_PUBLIC_GATEWAY_URL:-${AURA_PUBLIC_GATEWAY_URL:-}}"
DEPLOY_WEB_APP="${NEXA_DEPLOY_WEB_APP:-1}"
DEPLOY_LANDING="${NEXA_DEPLOY_LANDING:-auto}"
LEGACY_REMOTE_ROOT="${AURA_REMOTE_ROOT:-/opt/aura}"
LEGACY_STATIC_SITE_DIR="${AURA_REMOTE_STATIC_SITE_DIR:-/opt/apps/aura-landing-next}"
LEGACY_GATEWAY_SERVICE="${AURA_REMOTE_GATEWAY_SERVICE:-aura-gateway}"
PURGE_LEGACY_AURA="${NEXA_PURGE_LEGACY_AURA:-1}"

SSH_ARGS=(-o BatchMode=yes)
if [[ -n "$NEXA_SSH_KEY_FILE" ]]; then
  SSH_ARGS+=(-i "$NEXA_SSH_KEY_FILE" -o IdentitiesOnly=yes)
fi

ssh_remote() {
  ssh "${SSH_ARGS[@]}" "$@"
}

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
PUBLIC_WEB_URL="${NEXA_PUBLIC_WEB_URL:-${AURA_PUBLIC_WEB_URL:-$PUBLIC_BASE_URL}}"
echo "[deploy-mesh] Target: ${VPS_USER}@${VPS_IP}"

# 0. Prepare Nexa directories and migrate legacy Aura runtime state.
echo "[deploy-mesh] Preparing Nexa runtime root..."
ssh_remote "${VPS_USER}@${VPS_IP}" "\
  mkdir -p '$REMOTE_ROOT' '$REMOTE_RUNTIME_ROOT' '$REMOTE_REPO_DIR' '$REMOTE_STATIC_SITE_DIR' /etc/nexa && \
  if [ '$REMOTE_RUNTIME_ROOT' != '$LEGACY_REMOTE_ROOT' ] && [ -d '$LEGACY_REMOTE_ROOT' ]; then rsync -a '$LEGACY_REMOTE_ROOT/' '$REMOTE_RUNTIME_ROOT/'; fi && \
  if [ -d '$LEGACY_STATIC_SITE_DIR' ]; then rsync -a '$LEGACY_STATIC_SITE_DIR/' '$REMOTE_STATIC_SITE_DIR/'; fi"

# 1. Sync the repository on the VPS so the machine is a Git-backed node.
echo "[deploy-mesh] Syncing repository node..."
ssh_remote "${VPS_USER}@${VPS_IP}" "\
  export GIT_TERMINAL_PROMPT=0 && \
  if [ ! -d '$REMOTE_REPO_DIR/.git' ]; then \
    rm -rf '$REMOTE_REPO_DIR' && git clone --branch '$REMOTE_REPO_REF' '$REMOTE_REPO_URL' '$REMOTE_REPO_DIR'; \
  else \
    cd '$REMOTE_REPO_DIR' && \
    git remote set-url origin '$REMOTE_REPO_URL' && \
    git fetch origin '$REMOTE_REPO_REF' --prune && \
    git checkout -B '$REMOTE_REPO_REF' 'origin/$REMOTE_REPO_REF' && \
    git reset --hard 'origin/$REMOTE_REPO_REF'; \
  fi"

# 2. Backup then delete dynamic runtime files on the VPS.
echo "[deploy-mesh] Backup then delete dynamic files on server..."
ssh_remote "${VPS_USER}@${VPS_IP}" "\
  mkdir -p '$REMOTE_SCRIPTS_DIR' '$REMOTE_DATA_DIR' '$REMOTE_LOG_DIR' '$REMOTE_BACKUP_DIR' '$REMOTE_WEB_SHARED_DIR' && \
  install -m 755 '$REMOTE_REPO_DIR/ops/scripts/backup-dynamic-then-delete.sh' '$REMOTE_SCRIPTS_DIR/backup-dynamic-then-delete.sh' && \
  NEXA_ROOT='$REMOTE_RUNTIME_ROOT' AURA_ROOT='$REMOTE_RUNTIME_ROOT' NEXA_LOG_DIR='$REMOTE_LOG_DIR' AURA_LOG_DIR='$REMOTE_LOG_DIR' NEXA_DATA_DIR='$REMOTE_DATA_DIR' AURA_DATA_DIR='$REMOTE_DATA_DIR' '$REMOTE_SCRIPTS_DIR/backup-dynamic-then-delete.sh'"

# 3. Sync runtime content and install service configuration from the repository checkout.
echo "[deploy-mesh] Syncing runtime assets from repository node..."
ssh_remote "${VPS_USER}@${VPS_IP}" "\
  mkdir -p '$REMOTE_DOCS_DIR/updates' '$REMOTE_RUNTIME_ROOT/specs' && \
  rsync -a --delete '$REMOTE_REPO_DIR/docs/' '$REMOTE_DOCS_DIR/' && \
  if [ -d '$REMOTE_REPO_DIR/specs' ]; then rsync -a --delete '$REMOTE_REPO_DIR/specs/' '$REMOTE_RUNTIME_ROOT/specs/'; fi && \
  ln -sfn '$REMOTE_RUNTIME_ROOT/specs' /opt/specs && \
  for f in README.md DISCLAIMER.md nexa_runtime.py aura_runtime.py; do \
    if [ -f '$REMOTE_REPO_DIR/'\"\$f\" ]; then cp '$REMOTE_REPO_DIR/'\"\$f\" '$REMOTE_RUNTIME_ROOT/'\"\$f\"; fi; \
  done && \
  install -m 644 '$REMOTE_REPO_DIR/ops/config/nexa-gateway.service' '/etc/systemd/system/$REMOTE_GATEWAY_SERVICE.service' && \
  install -m 644 '$REMOTE_REPO_DIR/ops/config/nexa-runtime.env.example' /etc/nexa/runtime.env.example && \
  printf '%s\n' 'NEXA_ROOT=$REMOTE_RUNTIME_ROOT' 'NEXA_REPO_DIR=$REMOTE_REPO_DIR' 'NEXA_GATEWAY_PORT=8765' 'NEXA_PUBLIC_ROOT=$REMOTE_STATIC_SITE_DIR' > /etc/nexa/runtime.env"

if [[ "$DEPLOY_WEB_APP" == "1" ]]; then
  echo "[deploy-mesh] Building web app from repository node..."
  ssh_remote "${VPS_USER}@${VPS_IP}" "\
    install -m 644 '$REMOTE_REPO_DIR/ops/config/nexa-web.service' '/etc/systemd/system/$REMOTE_WEB_SERVICE.service' && \
    install -m 644 '$REMOTE_REPO_DIR/ops/config/nexa-web.env.example' '$REMOTE_WEB_SHARED_DIR/.env.production.example' && \
    test -f '$REMOTE_WEB_SHARED_DIR/.env.production' || cp '$REMOTE_WEB_SHARED_DIR/.env.production.example' '$REMOTE_WEB_SHARED_DIR/.env.production' && \
    cd '$REMOTE_REPO_DIR' && npm ci --workspace apps/web --include-workspace-root --no-audit --no-fund && npm run build --workspace apps/web"
fi

# 4. Build and publish the public docs site from the repository node.
if [[ "$DEPLOY_LANDING" == "1" || "$DEPLOY_LANDING" == "auto" ]]; then
  echo "[deploy-mesh] Building public docs site from repository node..."
  ssh_remote "${VPS_USER}@${VPS_IP}" "\
    mkdir -p '$REMOTE_STATIC_SITE_DIR/out' && \
    cd '$REMOTE_REPO_DIR' && npm ci --workspace apps/aura-landing-next --no-audit --no-fund && npm run build --workspace apps/aura-landing-next && \
    rsync -a --delete '$REMOTE_REPO_DIR/apps/aura-landing-next/out/' '$REMOTE_STATIC_SITE_DIR/out/'"
elif [[ "$DEPLOY_LANDING" == "1" ]]; then
  echo "[deploy-mesh] Public docs build requested but no build path is available." >&2
  exit 1
else
  echo "[deploy-mesh] Skipping public docs build."
fi

# 5. Install nginx and restart services.
echo "[deploy-mesh] Installing ingress configuration..."
ssh_remote "${VPS_USER}@${VPS_IP}" "install -m 644 '$REMOTE_REPO_DIR/ops/nginx/nginx.conf' /etc/nginx/nginx.conf"

echo "[deploy-mesh] Reloading nginx and restarting gateway..."
ssh_remote "${VPS_USER}@${VPS_IP}" "\
  systemctl daemon-reload && \
  systemctl enable '$REMOTE_GATEWAY_SERVICE' && \
  systemctl restart '$REMOTE_GATEWAY_SERVICE' && \
  if [ '$DEPLOY_WEB_APP' = '1' ]; then systemctl enable '$REMOTE_WEB_SERVICE' && systemctl restart '$REMOTE_WEB_SERVICE'; fi && \
  nginx -t 2>&1 && systemctl reload '$REMOTE_WEB_SERVER_RELOAD' && \
  echo 'gateway OK'"

# 6. Quick health check
echo "[deploy-mesh] Health check..."
if [[ "$DEPLOY_WEB_APP" == "1" ]]; then
  ssh_remote "${VPS_USER}@${VPS_IP}" "curl -fsS http://127.0.0.1:8765/health && echo '' && curl -fsS http://127.0.0.1:8765/api/specs | head -c 200 && echo '' && curl -fsS http://127.0.0.1:${REMOTE_WEB_PORT}/api/health"
else
  ssh_remote "${VPS_USER}@${VPS_IP}" "curl -fsS http://127.0.0.1:8765/health && echo '' && curl -fsS http://127.0.0.1:8765/api/specs | head -c 200"
fi

if [[ "$PURGE_LEGACY_AURA" == "1" && "$REMOTE_RUNTIME_ROOT" != "$LEGACY_REMOTE_ROOT" ]]; then
  echo "[deploy-mesh] Purging legacy Aura runtime..."
  ssh_remote "${VPS_USER}@${VPS_IP}" "\
    systemctl disable --now '$LEGACY_GATEWAY_SERVICE' 2>/dev/null || true && \
    rm -f '/etc/systemd/system/$LEGACY_GATEWAY_SERVICE.service' && \
    systemctl daemon-reload && \
    rm -rf '$LEGACY_REMOTE_ROOT' '$LEGACY_STATIC_SITE_DIR'"
fi

echo "[deploy-mesh] Done. Base URL: ${PUBLIC_BASE_URL%/} | Gateway: ${PUBLIC_GATEWAY_URL%/} | Web: ${PUBLIC_WEB_URL%/}"
