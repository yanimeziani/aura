#!/usr/bin/env bash
# sovereign-stack control: same devices, documented execution.
# See DEPLOYMENT.md for devices table and execution order.
set -euo pipefail

STACK_DIR="${SOVEREIGN_STACK_DIR:-/home/yani/sovereign-stack}"
cd "$STACK_DIR"

# Load .env for DOMAIN and compose
if [ -f .env ]; then
  set -a
  # shellcheck source=/dev/null
  source .env
  set +a
fi
DOMAIN="${DOMAIN:-}"

cmd="${1:-status}"

# ---- Pre-flight: require .env and valid compose ----
_run_preflight() {
  if [ ! -f .env ]; then
    echo "preflight: .env missing in $STACK_DIR"
    return 1
  fi
  if [ "$1" = "deploy" ] && [ -z "${DOMAIN:-}" ]; then
    echo "preflight: DOMAIN must be set in .env"
    return 1
  fi
  if ! sudo docker compose config >/dev/null 2>&1; then
    echo "preflight: docker compose config invalid"
    return 1
  fi
  return 0
}

# ---- Test: exit 1 if any check fails ----
_run_test() {
  local failed=0
  sudo docker compose ps >/dev/null 2>&1 || { echo "test: compose ps failed"; failed=1; }
  if ! curl -sf --max-time 5 "http://127.0.0.1:5678" >/dev/null; then
    echo "test: n8n fail"
    failed=1
  else
    echo "n8n: ok"
  fi
  if [ -n "$DOMAIN" ]; then
    if ! curl -sf --max-time 5 "http://127.0.0.1:80" -H "Host: $DOMAIN" -o /dev/null; then
      echo "test: Caddy ($DOMAIN) fail"
      failed=1
    else
      echo "Caddy ($DOMAIN): ok"
    fi
  else
    echo "test: DOMAIN not set, skipping Caddy check"
  fi
  return $failed
}

case "$cmd" in
  start)
    _run_preflight start || exit 1
    sudo docker compose up -d
    ;;
  stop)
    sudo docker compose down
    ;;
  restart)
    _run_preflight start || exit 1
    sudo docker compose up -d --force-recreate
    ;;
  deploy)
    _run_preflight deploy || exit 1
    FRONTEND_SRC="${FRONTEND_SRC:-/home/yani/ai_agency_web}"
    if [ ! -d "$FRONTEND_SRC" ]; then
      echo "deploy: missing frontend source: $FRONTEND_SRC (set FRONTEND_SRC)"
      exit 1
    fi
    if ! command -v npm >/dev/null 2>&1; then
      echo "deploy: npm not found"
      exit 1
    fi
    if ! command -v rsync >/dev/null 2>&1; then
      echo "deploy: rsync not found"
      exit 1
    fi
    echo "deploy: building frontend..."
    (cd "$FRONTEND_SRC" && npm run build)
    mkdir -p "$STACK_DIR/frontend"
    rsync -a --delete "$FRONTEND_SRC/dist/" "$STACK_DIR/frontend/"
    echo "deploy: frontend copied; starting stack."
    sudo docker compose up -d
    ;;
  status)
    sudo docker compose ps
    ;;
  logs)
    service="${2:-}"
    if [ -n "$service" ]; then
      sudo docker compose logs --tail 100 -f "$service"
    else
      sudo docker compose logs --tail 100 -f
    fi
    ;;
  test)
    _run_test
    ;;
  monitor)
    WATCH_CMD='sudo docker compose ps'
    if [ -n "$DOMAIN" ]; then
      WATCH_CMD="$WATCH_CMD && echo \"--- Caddy ($DOMAIN) ---\" && curl -sI --max-time 3 -H \"Host: $DOMAIN\" http://127.0.0.1:80 | sed -n 1p"
    fi
    WATCH_CMD="$WATCH_CMD && echo \"--- n8n ---\" && curl -sI --max-time 3 http://127.0.0.1:5678 | sed -n 1p"
    watch -n 5 "$WATCH_CMD"
    ;;
  *)
    printf 'usage: %s {start|stop|restart|status|deploy|logs [service]|test|monitor}\n' "$0"
    printf '  See sovereign-stack/DEPLOYMENT.md for devices and execution order.\n'
    exit 1
    ;;
esac
