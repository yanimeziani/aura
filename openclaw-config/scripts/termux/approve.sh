#!/usr/bin/env bash
# approve.sh — HITL Approval Queue TUI
# Shows pending approvals from the VPS, lets you approve/reject from phone.
# Idempotent. Safe to re-run.
# Usage: bash approve.sh

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
[[ -f "$SCRIPT_DIR/cockpit.conf" ]] && source "$SCRIPT_DIR/cockpit.conf"

VPS_HOST="${VPS_HOST:-your-vps.example.com}"
VPS_USER="${VPS_USER:-openclaw}"
VPS_PORT="${VPS_PORT:-22}"
QUEUE_PATH="/data/openclaw/hitl-queue"

# ---------- colors ----------
RED='\033[0;31m'; YELLOW='\033[0;33m'; GREEN='\033[0;32m'
BLUE='\033[0;34m'; BOLD='\033[1m'; RESET='\033[0m'

header() {
  clear
  printf "${BOLD}${BLUE}╔══════════════════════════════════════╗${RESET}\n"
  printf "${BOLD}${BLUE}║   OpenClaw  HITL Approval Queue      ║${RESET}\n"
  printf "${BOLD}${BLUE}║   dragun.app                         ║${RESET}\n"
  printf "${BOLD}${BLUE}╚══════════════════════════════════════╝${RESET}\n\n"
}

fetch_queue() {
  ssh -q -o ConnectTimeout=8 -p "$VPS_PORT" "$VPS_USER@$VPS_HOST" \
    "ls -1t '$QUEUE_PATH'/pending/*.json 2>/dev/null | head -20" 2>/dev/null || true
}

show_item() {
  local file="$1"
  ssh -q -p "$VPS_PORT" "$VPS_USER@$VPS_HOST" "cat '$file'" 2>/dev/null
}

approve_item() {
  local task_id="$1"
  ssh -p "$VPS_PORT" "$VPS_USER@$VPS_HOST" \
    "openclaw approve '$task_id'" 2>/dev/null \
    && printf "${GREEN}Approved: %s${RESET}\n" "$task_id" \
    || printf "${RED}Failed to approve: %s${RESET}\n" "$task_id"
}

reject_item() {
  local task_id="$1"
  local reason="$2"
  ssh -p "$VPS_PORT" "$VPS_USER@$VPS_HOST" \
    "openclaw reject '$task_id' --reason '$reason'" 2>/dev/null \
    && printf "${YELLOW}Rejected: %s${RESET}\n" "$task_id" \
    || printf "${RED}Failed to reject: %s${RESET}\n" "$task_id"
}

# ---------- main loop ----------
while true; do
  header

  # Fetch pending items
  QUEUE_FILES=$(fetch_queue)

  if [[ -z "$QUEUE_FILES" ]]; then
    printf "${GREEN}No pending approvals.${RESET}\n\n"
    printf "Auto-refreshing in 30s. Press q to quit, r to refresh now.\n"
    read -t 30 -n 1 key || key=""
    [[ "$key" == "q" ]] && exit 0
    continue
  fi

  # Parse and display queue items
  declare -a TASK_IDS
  declare -a TASK_FILES
  i=0

  while IFS= read -r f; do
    TASK_FILES[$i]="$f"
    # Extract task_id from filename: pending/task_abc123.json
    TASK_IDS[$i]=$(basename "$f" .json | sed 's/^task_//')
    ((i++)) || true
  done <<< "$QUEUE_FILES"

  COUNT=${#TASK_IDS[@]}
  printf "${BOLD}Pending approvals: ${RED}$COUNT${RESET}\n\n"

  for idx in "${!TASK_IDS[@]}"; do
    printf "${BOLD}[$((idx+1))]${RESET} Task: ${YELLOW}${TASK_IDS[$idx]}${RESET}\n"
    # Show a summary line from JSON
    ssh -q -p "$VPS_PORT" "$VPS_USER@$VPS_HOST" \
      "python3 -c \"import json,sys; d=json.load(open('${TASK_FILES[$idx]}')); print('    Action:', d.get('action','?')); print('    Agent:', d.get('agent','?')); print('    Risk:', d.get('blast_radius','?')); print('    Reversible:', d.get('reversible','?'))\"" \
      2>/dev/null || printf "    (preview unavailable)\n"
    printf "\n"
  done

  printf "\n${BOLD}Commands:${RESET}\n"
  printf "  [1-%d]  view full diff\n" "$COUNT"
  printf "  a<N>   approve item N    (e.g. a1)\n"
  printf "  r<N>   reject item N     (e.g. r1)\n"
  printf "  q      quit\n"
  printf "  <enter> refresh\n\n"
  printf "> "

  read -t 60 -r cmd || cmd=""

  case "$cmd" in
    q|Q) exit 0 ;;
    a[0-9]*)
      n="${cmd:1}"
      idx=$((n-1))
      if [[ $idx -ge 0 && $idx -lt $COUNT ]]; then
        printf "\n${BOLD}Approve ${TASK_IDS[$idx]}? (y/N):${RESET} "
        read -r confirm
        [[ "$confirm" == "y" || "$confirm" == "Y" ]] && approve_item "${TASK_IDS[$idx]}"
      fi
      ;;
    r[0-9]*)
      n="${cmd:1}"
      idx=$((n-1))
      if [[ $idx -ge 0 && $idx -lt $COUNT ]]; then
        printf "\n${BOLD}Reject reason:${RESET} "
        read -r reason
        reject_item "${TASK_IDS[$idx]}" "${reason:-no reason given}"
      fi
      ;;
    [0-9]*)
      idx=$((cmd-1))
      if [[ $idx -ge 0 && $idx -lt $COUNT ]]; then
        printf "\n${BOLD}=== Full diff: ${TASK_IDS[$idx]} ===${RESET}\n\n"
        show_item "${TASK_FILES[$idx]}"
        printf "\n\nPress any key to return."
        read -n 1 -r
      fi
      ;;
  esac
done
