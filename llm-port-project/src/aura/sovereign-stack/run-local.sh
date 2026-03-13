#!/usr/bin/env bash
set -euo pipefail

STACK_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$STACK_DIR"

cmd="${1:-status}"
COMPOSE_FILE="${COMPOSE_FILE:-docker-compose.local.yml}"
ENV_FILE="${ENV_FILE:-.env.local}"

dc() {
  sudo docker compose --env-file "$ENV_FILE" -f "$COMPOSE_FILE" "$@"
}

case "$cmd" in
  start)
    dc up -d
    ;;
  restart)
    dc up -d --force-recreate
    ;;
  status)
    dc ps
    ;;
  logs)
    service="${2:-}"
    if [ -n "$service" ]; then
      dc logs --tail 100 -f "$service"
    else
      dc logs --tail 100 -f
    fi
    ;;
  test)
    curl -sf "http://127.0.0.1:5678" >/dev/null
    curl -sf "http://127.0.0.1:8765/health" >/dev/null
    dc ps
    ;;
  prefill)
    set -a
    # shellcheck disable=SC1091
    [ -f "$ENV_FILE" ] && . "$ENV_FILE"
    set +a
    python3 "$STACK_DIR/prefill_n8n_flows.py"
    ;;
  monitor)
    watch -n 5 'sudo docker compose --env-file "'$ENV_FILE'" -f "'$COMPOSE_FILE'" ps && printf "\n--- n8n ---\n" && curl -Is http://127.0.0.1:5678 | sed -n "1p" && printf "\n--- gateway ---\n" && curl -Is http://127.0.0.1:8765/health | sed -n "1p"'
    ;;
  *)
    printf 'usage: %s {start|restart|status|logs [service]|test|prefill|monitor}\n' "$0"
    exit 1
    ;;
esac
