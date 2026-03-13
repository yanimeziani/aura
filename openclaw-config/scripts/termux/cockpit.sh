#!/usr/bin/env bash
# cockpit.sh — OpenClaw Termux Cockpit
# Z Fold "Final Boss" main entry point
# Idempotent: safe to re-run at any time
# Usage: bash cockpit.sh [--vps-only | --debian-only | --no-attach]

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG="$SCRIPT_DIR/cockpit.conf"

# ---------- defaults (override in cockpit.conf) ----------
VPS_HOST="${VPS_HOST:-your-vps.example.com}"
VPS_USER="${VPS_USER:-openclaw}"
VPS_PORT="${VPS_PORT:-22}"
DEBIAN_HOST="${DEBIAN_HOST:-192.168.1.100}"
DEBIAN_USER="${DEBIAN_USER:-yani}"
DEBIAN_PORT="${DEBIAN_PORT:-22}"
SESSION="openclaw"

# Load local overrides if present
[[ -f "$CONFIG" ]] && source "$CONFIG"

# ---------- helpers ----------
info()  { printf '\033[0;34m[cockpit]\033[0m %s\n' "$*"; }
warn()  { printf '\033[0;33m[cockpit]\033[0m %s\n' "$*"; }
ok()    { printf '\033[0;32m[cockpit]\033[0m %s\n' "$*"; }

require_cmd() {
  if ! command -v "$1" &>/dev/null; then
    warn "Missing: $1. Install with: pkg install $1"
    exit 1
  fi
}

# ---------- pre-flight ----------
require_cmd tmux
require_cmd ssh

# ---------- tmux session ----------
# Kill stale session if requested
if [[ "${1:-}" == "--reset" ]]; then
  tmux kill-session -t "$SESSION" 2>/dev/null || true
  info "Killed existing session '$SESSION'"
fi

# Attach if session already running
if tmux has-session -t "$SESSION" 2>/dev/null; then
  ok "Session '$SESSION' exists — attaching"
  exec tmux attach-session -t "$SESSION"
fi

info "Creating tmux session: $SESSION"

# ---------- layout ----------
# Window 0: VPS (primary)
# Window 1: Debian staging
# Window 2: Approval queue (HITL)
# Window 3: Logs tail
# Window 4: Local shell

tmux new-session -d -s "$SESSION" -n "vps" \
  "bash '$SCRIPT_DIR/connect-vps.sh' --auto-dashboard; bash"

tmux new-window -t "$SESSION" -n "debian" \
  "bash '$SCRIPT_DIR/connect-debian.sh'; bash"

tmux new-window -t "$SESSION" -n "hitl" \
  "bash '$SCRIPT_DIR/approve.sh'; bash"

tmux new-window -t "$SESSION" -n "logs" \
  "ssh -p $VPS_PORT $VPS_USER@$VPS_HOST 'tail -F /data/openclaw/logs/openclaw.log 2>/dev/null || echo waiting for logs...; bash' || bash"

tmux new-window -t "$SESSION" -n "local" \
  "bash"

# Set status bar
tmux set-option -t "$SESSION" status-style "bg=colour235,fg=colour250"
tmux set-option -t "$SESSION" status-left  "#[fg=colour82,bold] OPENCLAW #[fg=colour250]| "
tmux set-option -t "$SESSION" status-right "#[fg=colour250]%H:%M  %d-%b  #[fg=colour82]dragun.app"
tmux set-option -t "$SESSION" status-interval 5

# Focus VPS window
tmux select-window -t "$SESSION:vps"

ok "Cockpit ready. Attaching..."
exec tmux attach-session -t "$SESSION"
