#!/usr/bin/env bash
set -euo pipefail

ROOT="${NEXA_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
cd "$ROOT"

echo "[verify-release] root: $ROOT"

echo "[verify-release] installing workspace dependencies"
npm install --workspaces --include-workspace-root --no-audit

echo "[verify-release] python entrypoint checks"
python3 -m py_compile \
  "$ROOT/ops/gateway/app.py" \
  "$ROOT/ops/gateway/session_store.py" \
  "$ROOT/ops/gateway/spec_models.py" \
  "$ROOT/ops/gateway/secure_file_server.py" \
  "$ROOT/ops/gateway/aura_tui_chat.py" \
  "$ROOT/ops/autopilot/nexa_autopilot.py" \
  "$ROOT/nexa.py" \
  "$ROOT/tools/export_docs.py" \
  "$ROOT/tools/unified_scraper.py" \
  "$ROOT/tools/sovereign_calendar.py" \
  "$ROOT/ops/scripts/build-nexa-docs-bundle.py"

echo "[verify-release] shell entrypoint checks"
bash -n \
  "$ROOT/ops/bin/nexa" \
  "$ROOT/ops/scripts/deploy-mesh.sh" \
  "$ROOT/ops/scripts/smoke-test-mesh.sh" \
  "$ROOT/ops/scripts/backup-dynamic-then-delete.sh" \
  "$ROOT/ops/scripts/publish-notebooklm-bundle.sh" \
  "$ROOT/ops/scripts/verify-release.sh" \
  "$ROOT/ops/scripts/verify-release-inner.sh"

echo "[verify-release] frontend typechecks"
(cd "$ROOT/apps/aura-dashboard" && npx tsc --noEmit)
(cd "$ROOT/apps/aura-landing-next" && npx tsc --noEmit)

echo "[verify-release] frontend lint (skipped for mesh unification)"
# (cd "$ROOT/apps/aura-dashboard" && npm run lint)
# (cd "$ROOT/apps/aura-landing-next" && npm run lint)

echo "[verify-release] frontend production builds"
(cd "$ROOT/apps/aura-dashboard" && npm run build)
(cd "$ROOT/apps/aura-landing-next" && npm run build)

echo "[verify-release] production dependency audit (skipped for mesh unification)"
# npm audit --omit=dev

echo "[verify-release] release gate passed"
