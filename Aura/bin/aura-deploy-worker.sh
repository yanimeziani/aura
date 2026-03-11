#!/usr/bin/env bash
set -euo pipefail

STATE_DIR="/home/yani/Aura/.deploy"
mkdir -p "$STATE_DIR"

LOCK_FILE="$STATE_DIR/lock"
LATEST_FILE="$STATE_DIR/latest_sha"
DEPLOYED_FILE="$STATE_DIR/deployed_sha"

exec 9>"$LOCK_FILE"
if ! flock -n 9; then
  # Another deploy worker is running; it will handle the latest SHA.
  exit 0
fi

REPO_DIR="/home/yani"
INTERNAL_REMOTE="internal"

while true; do
  if [ ! -f "$LATEST_FILE" ]; then
    break
  fi

  latest_sha="$(cat "$LATEST_FILE")"
  deployed_sha=""
  if [ -f "$DEPLOYED_FILE" ]; then
    deployed_sha="$(cat "$DEPLOYED_FILE")"
  fi

  if [ -z "$latest_sha" ] || [ "$latest_sha" = "$deployed_sha" ]; then
    break
  fi

  cd "$REPO_DIR"

  # Sync working tree to latest internal main
  if ! git fetch "$INTERNAL_REMOTE" main; then
    echo "aura-deploy: failed to fetch from '$INTERNAL_REMOTE/main'" >&2
    break
  fi

  git reset --hard "$INTERNAL_REMOTE/main"

  echo "aura-deploy: Building and deploying Next.js landing page..."
  if [ -f "/home/yani/Aura/sovereign-stack/deploy-next.sh" ]; then
    /home/yani/Aura/sovereign-stack/deploy-next.sh || echo "aura-deploy: Next.js deployment failed"
  fi

  echo "aura-deploy: restarting local Aura services for commit $latest_sha"
  sudo systemctl restart aura_autopilot.service ai_pay.service ai_agency_web.service || true

  echo "$latest_sha" > "$DEPLOYED_FILE"

  # Small debounce window: if more pushes land, loop will see new latest_sha
  sleep 2
done

