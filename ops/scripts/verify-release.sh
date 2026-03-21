#!/usr/bin/env bash
set -euo pipefail

ROOT="${NEXA_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
MODE="${1:---container}"
IMAGE_TAG="${NEXA_VERIFY_IMAGE:-nexa-release-verify:local}"

case "$MODE" in
  --container)
    command -v docker >/dev/null 2>&1 || {
      echo "[verify-release] docker is required for --container mode" >&2
      exit 1
    }
    echo "[verify-release] building verification image: $IMAGE_TAG"
    docker build --progress=plain -t "$IMAGE_TAG" -f "$ROOT/ops/verify/Dockerfile.release" "$ROOT"
    ;;
  --local)
    echo "[verify-release] running on local host"
    bash "$ROOT/ops/scripts/verify-release-inner.sh"
    ;;
  *)
    echo "usage: $0 [--container|--local]" >&2
    exit 1
    ;;
esac
