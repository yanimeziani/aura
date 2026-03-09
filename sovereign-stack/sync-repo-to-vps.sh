#!/usr/bin/env bash
# Push repo to VPS over SSH (no GitHub key needed). Creates VPS_REPO_PATH and untars there.
set -euo pipefail
STACK_DIR="${SOVEREIGN_STACK_DIR:-$(cd "$(dirname "$0")" && pwd)}"
REPO_ROOT="$(cd "$STACK_DIR/.." && pwd)"
cd "$STACK_DIR"

if [ ! -f .env ]; then
  echo "error: .env missing. Set VPS_HOST, VPS_USER, VPS_REPO_PATH."
  exit 1
fi
set -a
# shellcheck source=/dev/null
source .env
set +a
for v in VPS_HOST VPS_USER VPS_REPO_PATH; do
  [ -n "${!v:-}" ] || { echo "error: $v not set"; exit 1; }
done

if [ -n "${SSH_KEY_PATH:-}" ]; then
  RSH="ssh -i ${SSH_KEY_PATH} -o StrictHostKeyChecking=accept-new"
else
  RSH="ssh -o StrictHostKeyChecking=accept-new"
fi
REMOTE="${VPS_USER}@${VPS_HOST}"

echo "Syncing repo to ${REMOTE}:${VPS_REPO_PATH} ..."
tar czf - -C "$REPO_ROOT" \
  --exclude=node_modules --exclude=dist --exclude=dist-ssr \
  --exclude=venv --exclude=venv_* --exclude=.venv --exclude=__pycache__ \
  --exclude='*.pyc' --exclude='.env' --exclude='*.key' --exclude='*.crt' --exclude='*.pem' \
  --exclude=sovereign-stack/frontend --exclude=sovereign-stack/deploy.log \
  --exclude=ai_agency_wealth/agency.db --exclude=ai_agency_wealth/backpack_ledger.json \
  --exclude=ai_agency_wealth/leads.json --exclude=ai_agency_wealth/watchdog_state.json \
  ai_agency_web ai_agency_wealth sovereign-stack AGENTS.md run .gitignore .git 2>/dev/null \
  | $RSH "$REMOTE" "mkdir -p $VPS_REPO_PATH && tar xzf - -C $VPS_REPO_PATH"
echo "Done. Run: ./run rx 'cd $VPS_REPO_PATH/sovereign-stack && ./bootstrap-vps.sh'"
echo "Then edit sovereign-stack/.env on VPS and run ./run lr"
