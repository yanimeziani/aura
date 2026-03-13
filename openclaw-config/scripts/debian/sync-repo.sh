#!/usr/bin/env bash
# sync-repo.sh — Sync dragun-app and openclaw-config repos on Debian staging host
# Idempotent. Safe to re-run. Fetches all branches, prunes stale ones.
# Usage: bash sync-repo.sh [--branch <branch>] [--openclaw-only | --dragun-only]

set -euo pipefail

DRAGUN_DIR="${DRAGUN_REPO_DIR:-$HOME/dragun-app}"
OPENCLAW_DIR="${OPENCLAW_CONFIG_DIR:-$HOME/openclaw-config}"
BRANCH="${BRANCH:-}"

info() { printf '\033[0;34m[sync]\033[0m %s\n' "$*"; }
ok()   { printf '\033[0;32m[sync]\033[0m %s\n' "$*"; }
warn() { printf '\033[0;33m[sync]\033[0m %s\n' "$*"; }

# Parse args
DRAGUN_ONLY=false; OPENCLAW_ONLY=false
for arg in "$@"; do
  case "$arg" in
    --branch)      BRANCH="${2:-}" ;;
    --dragun-only)  DRAGUN_ONLY=true ;;
    --openclaw-only) OPENCLAW_ONLY=true ;;
  esac
done

sync_repo() {
  local DIR="$1"
  local NAME="$2"

  if [[ ! -d "$DIR/.git" ]]; then
    warn "$NAME not found at $DIR — skipping"
    return
  fi

  info "Syncing $NAME ($DIR)..."
  cd "$DIR"

  # Fetch all remote branches, prune deleted
  git fetch --all --prune --quiet

  # Pull current branch if clean
  local CURRENT
  CURRENT=$(git branch --show-current)
  if git diff --quiet && git diff --cached --quiet; then
    git pull --ff-only --quiet origin "$CURRENT" 2>/dev/null \
      && ok "$NAME: $CURRENT up to date" \
      || warn "$NAME: could not fast-forward $CURRENT (diverged or no upstream)"
  else
    warn "$NAME: working tree dirty, skipping pull (fetch only)"
  fi

  # Checkout specific branch if requested
  if [[ -n "$BRANCH" && "$BRANCH" != "$CURRENT" ]]; then
    if git show-ref --verify --quiet "refs/remotes/origin/$BRANCH"; then
      git checkout -B "$BRANCH" "origin/$BRANCH" --quiet
      ok "$NAME: checked out $BRANCH"
    else
      warn "$NAME: branch $BRANCH not found on origin"
    fi
  fi

  # Show status summary
  local AHEAD BEHIND
  AHEAD=$(git rev-list --count "origin/${BRANCH:-$CURRENT}..HEAD" 2>/dev/null || echo "?")
  BEHIND=$(git rev-list --count "HEAD..origin/${BRANCH:-$CURRENT}" 2>/dev/null || echo "?")
  info "$NAME: ahead=$AHEAD behind=$BEHIND"
  git log --oneline -3 | sed 's/^/  /'
}

if ! $OPENCLAW_ONLY; then
  sync_repo "$DRAGUN_DIR"   "dragun-app"
fi

if ! $DRAGUN_ONLY; then
  sync_repo "$OPENCLAW_DIR" "openclaw-config"
fi

ok "Sync complete"
