#!/usr/bin/env bash
# Deploy Next.js landing page + Caddy config to VPS (Docker version)
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# Load env
ENV_FILE="$SCRIPT_DIR/.env"
if [ -f "$ENV_FILE" ]; then
    source "$ENV_FILE"
else
    echo "Error: sovereign-stack/.env missing"
    exit 1
fi

VPS_HOST="${VPS_HOST:?Set VPS_HOST in sovereign-stack/.env}"
VPS_USER="${VPS_USER:-root}"
SSH_KEY="${SSH_KEY:-$HOME/.ssh/aura_vps}"
# Path on the VPS host where the repo is located
VPS_ROOT="${VPS_ROOT:-/root/aura-stack/sovereign-stack}"

SSH="ssh -i $SSH_KEY -o StrictHostKeyChecking=no $VPS_USER@$VPS_HOST"

echo "» Deploying to $VPS_USER@$VPS_HOST"

# 1. Build Next.js
echo "» Building Next.js frontend (static export)..."
cd "$REPO_ROOT/aura-landing-next"
npm run build

# 2. Sync built assets to the landing_page directory on VPS
echo "» Syncing web assets to VPS landing_page..."
rsync -az --delete \
  -e "ssh -i $SSH_KEY -o StrictHostKeyChecking=no" \
  "$REPO_ROOT/aura-landing-next/out/" \
  "$VPS_USER@$VPS_HOST:$VPS_ROOT/landing_page/"

# 3. Sync Caddy config
echo "» Syncing Caddyfile..."
rsync -az \
  -e "ssh -i $SSH_KEY -o StrictHostKeyChecking=no" \
  "$REPO_ROOT/config/Caddyfile" \
  "$VPS_USER@$VPS_HOST:$VPS_ROOT/Caddyfile"

# 4. Reload Caddy inside the container
echo "» Reloading Caddy container..."
$SSH "docker exec sovereign-stack-caddy-1 caddy reload --config /etc/caddy/Caddyfile"

echo "✓ Done — https://meziani.ai should be live and responsive"
