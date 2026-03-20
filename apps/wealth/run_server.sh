#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"

source "${SCRIPT_DIR}/venv312/bin/activate"
exec uvicorn prod_payment_server:app --host 0.0.0.0 --port "${PORT:-8000}" >> "${SCRIPT_DIR}/server.log" 2>&1
