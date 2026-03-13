#!/usr/bin/env bash
# connect-vps.sh — SSH into Debian VPS with optional auto-dashboard
# Idempotent. Safe to re-run.
# Usage: bash connect-vps.sh [--auto-dashboard] [--tmux-attach]

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
[[ -f "$SCRIPT_DIR/cockpit.conf" ]] && source "$SCRIPT_DIR/cockpit.conf"

VPS_HOST="${VPS_HOST:-your-vps.example.com}"
VPS_USER="${VPS_USER:-openclaw}"
VPS_PORT="${VPS_PORT:-22}"
REMOTE_SESSION="dragun-vps"

AUTO_DASHBOARD=false
TMUX_ATTACH=false

for arg in "$@"; do
  case $arg in
    --auto-dashboard) AUTO_DASHBOARD=true ;;
    --tmux-attach)    TMUX_ATTACH=true ;;
  esac
done

info() { printf '\033[0;34m[vps]\033[0m %s\n' "$*"; }

# Test connectivity first (non-blocking, short timeout)
info "Connecting to $VPS_USER@$VPS_HOST:$VPS_PORT ..."
if ! ssh -q -o ConnectTimeout=8 -o BatchMode=yes \
       -p "$VPS_PORT" "$VPS_USER@$VPS_HOST" exit 2>/dev/null; then
  printf '\033[0;33m[vps]\033[0m Connection check failed (network may be flaky).\n'
  printf '      Retrying with password fallback in 3s...\n'
  sleep 3
fi

if $TMUX_ATTACH; then
  # Attach to or create remote tmux session
  exec ssh -p "$VPS_PORT" "$VPS_USER@$VPS_HOST" \
    "tmux new-session -A -s '$REMOTE_SESSION'"
elif $AUTO_DASHBOARD; then
  # Run the openclaw dashboard TUI
  exec ssh -t -p "$VPS_PORT" "$VPS_USER@$VPS_HOST" \
    "cd /data/openclaw && bash scripts/dashboard.sh 2>/dev/null || \
     (echo 'Dashboard not ready yet. Dropping to shell.'; bash)"
else
  exec ssh -p "$VPS_PORT" "$VPS_USER@$VPS_HOST"
fi
