#!/usr/bin/env bash
# Build the Zig distill OCI image with Docker only (zero Podman in this path).
# Usage: from repo root — ./ops/scripts/zig-docker-distill.sh [extra docker build args...]
set -euo pipefail

ROOT="${NEXA_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
IMAGE_TAG="${NEXA_ZIG_DISTILL_IMAGE:-nexa-zig-distill:local}"
CONTAINERFILE="${ROOT}/ops/verify/Containerfile.zig-distill"

if ! command -v docker >/dev/null 2>&1; then
  echo "[zig-docker-distill] docker is required on PATH" >&2
  exit 1
fi

echo "[zig-docker-distill] image $IMAGE_TAG"
exec docker build \
  --progress=plain \
  -f "$CONTAINERFILE" \
  -t "$IMAGE_TAG" \
  "$@" \
  "$ROOT"
