#!/usr/bin/env bash
# Deploy web assets + Caddy config to VPS
# Usage: ./run deploy  OR  ./sovereign-stack/deploy-remote.sh
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# Load env
ENV_FILE="$SCRIPT_DIR/.env"
[ -f "$ENV_FILE" ] && source "$ENV_FILE"

VPS_HOST="${VPS_HOST:?Set VPS_HOST in sovereign-stack/.env}"
VPS_USER="${VPS_USER:-root}"
VPS_REPO_PATH="${VPS_REPO_PATH:-/var/www/html}"
SSH_KEY="${SSH_KEY:-$HOME/.ssh/aura_vps}"
DOMAIN="${DOMAIN:-meziani.ai}"

SSH="ssh -i $SSH_KEY -o StrictHostKeyChecking=no $VPS_USER@$VPS_HOST"

echo "» Deploying to $VPS_USER@$VPS_HOST"

# 1. Build web assets
echo "» Building frontend..."
cd "$REPO_ROOT/ai_agency_web" && npm run build

# 2. Sync built assets (includes /brand/)
echo "» Syncing web assets..."
rsync -az --delete \
  -e "ssh -i $SSH_KEY -o StrictHostKeyChecking=no" \
  "$REPO_ROOT/ai_agency_web/dist/" \
  "$VPS_USER@$VPS_HOST:$VPS_REPO_PATH/ai_agency_web/"

# 3. Sync Caddy config
echo "» Syncing Caddyfile..."
rsync -az \
  -e "ssh -i $SSH_KEY -o StrictHostKeyChecking=no" \
  "$REPO_ROOT/config/Caddyfile" \
  "$VPS_USER@$VPS_HOST:/etc/caddy/Caddyfile"

# 4. Reload Caddy
echo "» Reloading Caddy..."
$SSH "caddy reload --config /etc/caddy/Caddyfile --adapter caddyfile 2>&1 || systemctl reload caddy"

echo "✓ Done — https://brand.$DOMAIN should be live"
