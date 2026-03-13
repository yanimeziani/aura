#!/usr/bin/env bash
set -euo pipefail

STACK_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$STACK_DIR"

cmd="${1:-status}"

case "$cmd" in
  start)
    sudo docker compose up -d
    ;;
  restart)
    sudo docker compose up -d --force-recreate
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
    curl -sf "http://127.0.0.1:5678" >/dev/null
    curl -skf --resolve "fedora.tailafcdba.ts.net:443:127.0.0.1" "https://fedora.tailafcdba.ts.net/" >/dev/null
    sudo docker compose ps
    ;;
  monitor)
    watch -n 5 'sudo docker compose ps && printf "\n--- local ---\n" && curl -Is http://127.0.0.1:5678 | sed -n "1p" && printf "\n--- tailscale tls ---\n" && curl -Isk --resolve "fedora.tailafcdba.ts.net:443:127.0.0.1" https://fedora.tailafcdba.ts.net/ | sed -n "1p"'
    ;;
  *)
    printf 'usage: %s {start|restart|status|logs [service]|test|monitor}\n' "$0"
    exit 1
    ;;
esac
