#!/usr/bin/env bash
# overnight-cycle.sh — one build+test cycle with git checkpoint.
# Designed to be called repeatedly by aura-stub duplicate.
# Each run: zig build + test all packages → commit only changed src files → push.
# Sleep at end so stub doesn't thrash.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
AURA_ROOT="${AURA_ROOT:-$(cd "$SCRIPT_DIR/.." && pwd)}"
SLEEP_BETWEEN="${OVERNIGHT_SLEEP:-600}"   # 10 min default gap between cycles
LOG="$AURA_ROOT/vault/overnight.log"
CYCLE_COUNT_FILE="$AURA_ROOT/vault/overnight_cycle.txt"

cd "$AURA_ROOT"

ts() { date '+%Y-%m-%dT%H:%M:%S'; }

# Cycle counter
CYCLE=1
if [[ -f "$CYCLE_COUNT_FILE" ]]; then
  CYCLE=$(( $(cat "$CYCLE_COUNT_FILE") + 1 ))
fi
echo "$CYCLE" > "$CYCLE_COUNT_FILE"

echo "" | tee -a "$LOG"
echo "━━━ [$(ts)] Overnight cycle #$CYCLE begin ━━━" | tee -a "$LOG"

# Step 1 — full workspace build + all tests
echo "[$(ts)] Running aura gs..." | tee -a "$LOG"
if ! bin/aura-gs 1 2>&1 | tee -a "$LOG"; then
  echo "[$(ts)] BUILD FAILED — skipping commit this cycle." | tee -a "$LOG"
  sleep "$SLEEP_BETWEEN"
  exit 1
fi

echo "[$(ts)] Build+test passed." | tee -a "$LOG"

# Step 2 — stage src changes only (exclude caches and large binaries)
echo "[$(ts)] Staging changes..." | tee -a "$LOG"
git add \
  '**/src/*.zig' \
  'build.zig' \
  'build.zig.zon' \
  '**/build.zig' \
  '**/build.zig.zon' \
  'docs/' \
  'vault/*.md' \
  'vault/*.txt' \
  'vault/roster/' \
  'vault/docs_inbox/' \
  'bin/' \
  'gateway/' \
  'ai_agency_wealth/*.py' \
  'ai_agency_wealth/*.md' \
  '*.md' \
  2>/dev/null || true

# Only commit if there's something staged
if git diff --cached --quiet; then
  echo "[$(ts)] Nothing staged — skipping commit." | tee -a "$LOG"
else
  MSG="overnight #$CYCLE: build+test green [$(ts)]"
  git commit -m "$MSG" 2>&1 | tee -a "$LOG"
  echo "[$(ts)] Committed: $MSG" | tee -a "$LOG"

  echo "[$(ts)] Pushing to origin/main..." | tee -a "$LOG"
  git push origin main 2>&1 | tee -a "$LOG"
  echo "[$(ts)] Pushed." | tee -a "$LOG"
fi

echo "[$(ts)] Cycle #$CYCLE complete. Sleeping ${SLEEP_BETWEEN}s before next cycle." | tee -a "$LOG"
sleep "$SLEEP_BETWEEN"
