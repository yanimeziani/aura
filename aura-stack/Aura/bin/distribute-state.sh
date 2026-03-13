#!/usr/bin/env bash
# Distribute current Aura repo state to the 3 machines.
# 1) Push this repo to the internal remote.
# 2) Optionally SSH to other hosts and pull (set AURA_DISTRIBUTE_HOSTS).
# Usage: ./bin/distribute-state.sh [push-only]
#   push-only — only push to internal; do not ssh to other hosts.

set -euo pipefail
AURA_ROOT="${AURA_ROOT:-/home/yani/Aura}"
cd "$AURA_ROOT"
INTERNAL_REMOTE="${AURA_INTERNAL_REMOTE:-internal}"
BRANCH="${AURA_DISTRIBUTE_BRANCH:-main}"
# Space-separated list of hosts to ssh and pull (e.g. "vps.example.com pi.local")
DISTRIBUTE_HOSTS="${AURA_DISTRIBUTE_HOSTS:-}"
REMOTE_AURA_ROOT="${AURA_DISTRIBUTE_REMOTE_PATH:-$AURA_ROOT}"

if ! git remote get-url "$INTERNAL_REMOTE" &>/dev/null; then
  echo "No git remote '$INTERNAL_REMOTE'. Set AURA_INTERNAL_REMOTE or add remote." >&2
  exit 1
fi

echo "[distribute] Pushing to $INTERNAL_REMOTE/$BRANCH"
git push "$INTERNAL_REMOTE" HEAD:"$BRANCH" || true

if [[ "${1:-}" == "push-only" ]] || [[ -z "$DISTRIBUTE_HOSTS" ]]; then
  echo "[distribute] Push done. Other machines: pull manually or set AURA_DISTRIBUTE_HOSTS and run without push-only."
  exit 0
fi

for host in $DISTRIBUTE_HOSTS; do
  echo "[distribute] Syncing $host"
  ssh "$host" "cd $REMOTE_AURA_ROOT && git fetch $INTERNAL_REMOTE $BRANCH && git reset --hard $INTERNAL_REMOTE/$BRANCH" || true
done
echo "[distribute] Done."
