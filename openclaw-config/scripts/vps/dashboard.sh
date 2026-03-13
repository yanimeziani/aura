#!/usr/bin/env bash
# dashboard.sh — OpenClaw VPS TUI Dashboard
# Called by connect-vps.sh --auto-dashboard from Termux.
# Shows: agent status, costs, HITL queue, recent alerts, uptime.
# Refreshes every 10s. Press q to quit.

set -euo pipefail

OPENCLAW_DIR="/data/openclaw"
QUEUE_DIR="$OPENCLAW_DIR/hitl-queue"
ARTIFACTS_DIR="$OPENCLAW_DIR/artifacts"
LOG_DIR="$OPENCLAW_DIR/logs"
CONFIG_DIR="$OPENCLAW_DIR/config"

# Colors
RED='\033[0;31m'; YELLOW='\033[0;33m'; GREEN='\033[0;32m'
BLUE='\033[0;34m'; CYAN='\033[0;36m'; BOLD='\033[1m'; DIM='\033[2m'
RESET='\033[0m'

# ── helpers ──────────────────────────────────────────────────────────────────

container_status() {
  local name="$1"
  local status
  status=$(docker inspect --format='{{.State.Status}}' "$name" 2>/dev/null || echo "not found")
  local health
  health=$(docker inspect --format='{{if .State.Health}}{{.State.Health.Status}}{{else}}n/a{{end}}' "$name" 2>/dev/null || echo "n/a")
  case "$status" in
    running)  printf "${GREEN}● running${RESET} (health: %s)" "$health" ;;
    exited)   printf "${RED}✗ exited${RESET}" ;;
    *)        printf "${DIM}? %s${RESET}" "$status" ;;
  esac
}

hitl_count() {
  ls "$QUEUE_DIR/pending/"*.json 2>/dev/null | wc -l
}

cost_today() {
  # Read from cost log if it exists, else show unknown
  local f="$ARTIFACTS_DIR/devsecops/cost_report_$(date +%Y-%m-%d).md"
  if [[ -f "$f" ]]; then
    grep -m1 'Global:' "$f" 2>/dev/null | sed 's/.*Global: //' | cut -d'/' -f1 | tr -d ' '
  else
    echo "?"
  fi
}

recent_alert() {
  # Last line from alert log
  local f="$LOG_DIR/openclaw-system-system.log"
  if [[ -f "$f" ]]; then
    tail -1 "$f" 2>/dev/null | python3 -c "import json,sys; d=json.load(sys.stdin); print(d.get('message','')[:60])" 2>/dev/null || echo "—"
  else
    echo "—"
  fi
}

last_deploy() {
  ls -1t "$ARTIFACTS_DIR/devsecops/deploy_"*.md 2>/dev/null | head -1 \
    | xargs basename 2>/dev/null | sed 's/deploy_//;s/.md//' || echo "none"
}

panic_mode() {
  [[ -f "$OPENCLAW_DIR/state/panic_mode" ]] && echo "${RED}ON${RESET}" || echo "${GREEN}OFF${RESET}"
}

# ── main render ──────────────────────────────────────────────────────────────

render() {
  clear
  local NOW
  NOW=$(date '+%Y-%m-%d %H:%M:%S UTC')

  printf "${BOLD}${BLUE}"
  printf "╔══════════════════════════════════════════════════════════╗\n"
  printf "║  OpenClaw Dashboard — dragun.app          %-14s  ║\n" "$NOW"
  printf "╚══════════════════════════════════════════════════════════╝${RESET}\n\n"

  # ── Agents ──
  printf "${BOLD}AGENTS${RESET}\n"
  printf "  %-22s %s\n" "openclaw (orch):"    "$(container_status openclaw)"
  printf "  %-22s %s\n" "devsecops:"          "$(container_status agent-devsecops)"
  printf "  %-22s %s\n" "growth:"             "$(container_status agent-growth)"
  printf "  %-22s %s\n" "caddy (proxy):"      "$(container_status caddy)"
  printf "\n"

  # ── HITL Queue ──
  local PENDING
  PENDING=$(hitl_count)
  printf "${BOLD}HITL QUEUE${RESET}\n"
  if [[ "$PENDING" -gt 0 ]]; then
    printf "  ${YELLOW}${BOLD}%d pending approval(s)${RESET}" "$PENDING"
    printf " — run: ${CYAN}bash scripts/termux/approve.sh${RESET}\n"
    ls "$QUEUE_DIR/pending/"*.json 2>/dev/null | while IFS= read -r f; do
      local tid
      tid=$(basename "$f" .json | sed 's/^task_//')
      local action
      action=$(python3 -c "import json; d=json.load(open('$f')); print(d.get('action','?'))" 2>/dev/null || echo "?")
      printf "    ${YELLOW}·${RESET} %-20s %s\n" "$tid" "$action"
    done
  else
    printf "  ${GREEN}No pending approvals${RESET}\n"
  fi
  printf "\n"

  # ── Costs ──
  printf "${BOLD}COSTS TODAY${RESET}\n"
  local COST
  COST=$(cost_today)
  printf "  Spend:      %s / \$5.00\n" "$COST"
  printf "  Panic mode: $(panic_mode)\n"
  printf "\n"

  # ── Ops ──
  printf "${BOLD}OPS${RESET}\n"
  printf "  Last deploy: %s\n" "$(last_deploy)"
  printf "  Last alert:  %s\n" "$(recent_alert)"
  printf "\n"

  # ── Recent logs (last 5 lines from openclaw log) ──
  printf "${BOLD}RECENT LOG${RESET}\n"
  local LOG="$LOG_DIR/openclaw-orchestrator-system.log"
  if [[ -f "$LOG" ]]; then
    tail -5 "$LOG" | while IFS= read -r line; do
      echo "  $line" | python3 -c "
import json,sys
for line in sys.stdin:
    try:
        d=json.loads(line)
        lvl=d.get('level','info')
        msg=d.get('message','')[:70]
        ts=d.get('timestamp','')[:19]
        print(f'  [{ts}] {lvl.upper():<7} {msg}')
    except:
        print(line.rstrip())
" 2>/dev/null || printf "  %s\n" "$line"
    done
  else
    printf "  ${DIM}No logs yet${RESET}\n"
  fi
  printf "\n"

  printf "${DIM}Refreshing every 10s. Press q to quit, r to force refresh.${RESET}\n"
}

# ── loop ─────────────────────────────────────────────────────────────────────

while true; do
  render
  # Non-blocking read with 10s timeout
  if read -t 10 -n 1 key 2>/dev/null; then
    case "$key" in
      q|Q) clear; exit 0 ;;
      r|R) continue ;;
    esac
  fi
done
