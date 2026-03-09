#!/usr/bin/env bash
# Run on VPS once after cloning repo to VPS_REPO_PATH. Ensures .env exists (from example), frontend dir, and optional venv for payment API.
set -euo pipefail
cd "$(dirname "$0")"
REPO_ROOT="$(cd .. && pwd)"

if [ ! -f .env ]; then
  cp .env.example .env
  echo "Created .env from .env.example; edit and set DOMAIN (and VPS_* if this host is used as deploy target)."
fi
mkdir -p frontend
echo "Bootstrap done. Next: edit sovereign-stack/.env (DOMAIN, etc.), copy TLS cert/key if needed, then run ./run lp or receive deploy via ./run lr from another device."
