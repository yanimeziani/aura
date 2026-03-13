#!/usr/bin/env bash
# connect-debian.sh — SSH into local Debian staging machine
# Idempotent. Safe to re-run.
# Usage: bash connect-debian.sh [--tmux-attach] [--sync-repo]

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
[[ -f "$SCRIPT_DIR/cockpit.conf" ]] && source "$SCRIPT_DIR/cockpit.conf"

DEBIAN_HOST="${DEBIAN_HOST:-192.168.1.100}"
DEBIAN_USER="${DEBIAN_USER:-yani}"
DEBIAN_PORT="${DEBIAN_PORT:-22}"
REMOTE_SESSION="dragun-dev"

TMUX_ATTACH=false
SYNC_REPO=false

for arg in "$@"; do
  case $arg in
    --tmux-attach) TMUX_ATTACH=true ;;
    --sync-repo)   SYNC_REPO=true ;;
  esac
done

info() { printf '\033[0;34m[debian]\033[0m %s\n' "$*"; }
warn() { printf '\033[0;33m[debian]\033[0m %s\n' "$*"; }

info "Connecting to $DEBIAN_USER@$DEBIAN_HOST:$DEBIAN_PORT ..."

if ! ssh -q -o ConnectTimeout=5 -o BatchMode=yes \
       -p "$DEBIAN_PORT" "$DEBIAN_USER@$DEBIAN_HOST" exit 2>/dev/null; then
  warn "Cannot reach Debian host (are you on the same network?)."
  warn "Try: ssh -p $DEBIAN_PORT $DEBIAN_USER@$DEBIAN_HOST"
  exit 1
fi

if $SYNC_REPO; then
  info "Syncing repos on Debian host..."
  ssh -p "$DEBIAN_PORT" "$DEBIAN_USER@$DEBIAN_HOST" \
    'cd ~/dragun-app && git fetch --all && echo "Synced dragun-app"'
fi

if $TMUX_ATTACH; then
  exec ssh -t -p "$DEBIAN_PORT" "$DEBIAN_USER@$DEBIAN_HOST" \
    "tmux new-session -A -s '$REMOTE_SESSION'"
else
  exec ssh -p "$DEBIAN_PORT" "$DEBIAN_USER@$DEBIAN_HOST"
fi
