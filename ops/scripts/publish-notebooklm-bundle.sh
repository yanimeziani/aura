#!/usr/bin/env bash
set -euo pipefail

REAL_SCRIPT="$(python3 -c 'import os,sys; print(os.path.realpath(sys.argv[1]))' "$0")"
SCRIPT_DIR="$(cd "$(dirname "$REAL_SCRIPT")" && pwd)"
AURA_ROOT="${AURA_ROOT:-$(cd "$SCRIPT_DIR/../.." && pwd)}"
REPO_ROOT="${REPO_ROOT:-$AURA_ROOT}"

BUNDLE_PATH="${AURA_DOCS_BUNDLE_OUT:-$AURA_ROOT/nexa-docs-notebooklm.txt}"
EXPORTS_DIR="${AURA_NOTEBOOKLM_EXPORT_DIR:-$AURA_ROOT/.aura/exports}"
MANIFEST_PATH="${AURA_NOTEBOOKLM_MANIFEST:-$EXPORTS_DIR/notebooklm-manifest.json}"
LATEST_PATH="${AURA_NOTEBOOKLM_LATEST:-$EXPORTS_DIR/notebooklm/latest.txt}"
SOURCE_URL="${AURA_NOTEBOOKLM_SOURCE_URL:-${AURA_PUBLIC_BASE_URL:-http://127.0.0.1:${AURA_GATEWAY_PORT:-8765}}/docs/nexa}"

mkdir -p "$EXPORTS_DIR" "$(dirname "$LATEST_PATH")"

REPO_ROOT="$REPO_ROOT" AURA_ROOT="$AURA_ROOT" AURA_DOCS_BUNDLE_OUT="$BUNDLE_PATH" \
  python3 "$AURA_ROOT/ops/scripts/build-aura-docs-bundle.py"

if [[ ! -s "$BUNDLE_PATH" ]]; then
  echo "Bundle was not created or is empty: $BUNDLE_PATH" >&2
  exit 1
fi

SHA256="$(sha256sum "$BUNDLE_PATH" | awk '{print $1}')"
BYTES="$(wc -c < "$BUNDLE_PATH" | tr -d ' ')"
STAMP="$(date -u +"%Y-%m-%dT%H:%M:%SZ")"

IPFS_CID=""
IPFS_GATEWAY_URL=""
if [[ "${AURA_NOTEBOOKLM_IPFS_PUBLISH:-0}" == "1" ]]; then
  GATEWAY_URL="${AURA_GATEWAY_URL:-http://127.0.0.1:${AURA_GATEWAY_PORT:-8765}}"
  if [[ -z "${AURA_VAULT_TOKEN:-}" ]]; then
    echo "AURA_VAULT_TOKEN is required when AURA_NOTEBOOKLM_IPFS_PUBLISH=1" >&2
    exit 1
  fi
  RESP="$(
    python3 - "$BUNDLE_PATH" "$GATEWAY_URL" "$AURA_VAULT_TOKEN" <<'PY'
import json
import sys
import urllib.request
from pathlib import Path

bundle_path = Path(sys.argv[1])
gateway_url = sys.argv[2].rstrip("/")
token = sys.argv[3]
payload = json.dumps({
    "content": bundle_path.read_text(encoding="utf-8"),
    "filename": bundle_path.name,
    "pin": True,
}).encode("utf-8")
req = urllib.request.Request(
    f"{gateway_url}/transport/ipfs/add",
    data=payload,
    headers={
        "Content-Type": "application/json",
        "Authorization": f"Bearer {token}",
    },
    method="POST",
)
with urllib.request.urlopen(req, timeout=120) as response:
    print(response.read().decode("utf-8"))
PY
)"
  IPFS_CID="$(python3 -c 'import json,sys; print(json.loads(sys.stdin.read()).get("cid",""))' <<<"$RESP")"
  IPFS_GATEWAY_URL="$(python3 -c 'import json,sys; print(json.loads(sys.stdin.read()).get("gateway_url",""))' <<<"$RESP")"
fi

python3 - "$MANIFEST_PATH" "$BUNDLE_PATH" "$SHA256" "$BYTES" "$STAMP" "$SOURCE_URL" "$IPFS_CID" "$IPFS_GATEWAY_URL" <<'PY'
import json
import sys
from pathlib import Path

manifest_path = Path(sys.argv[1])
bundle_path = Path(sys.argv[2])
sha256 = sys.argv[3]
bytes_size = int(sys.argv[4])
stamp = sys.argv[5]
source_url = sys.argv[6]
ipfs_cid = sys.argv[7]
ipfs_gateway_url = sys.argv[8]

payload = {
    "name": "nexa-notebooklm-bundle",
    "generated_at": stamp,
    "bundle_path": str(bundle_path),
    "source_url": source_url,
    "sha256": sha256,
    "bytes": bytes_size,
    "ipfs": {
        "cid": ipfs_cid or None,
        "gateway_url": ipfs_gateway_url or None,
    },
}
manifest_path.write_text(json.dumps(payload, indent=2) + "\n", encoding="utf-8")
print(json.dumps(payload, indent=2))
PY

printf '%s\n' "$BUNDLE_PATH" > "$LATEST_PATH"

echo "NotebookLM bundle published"
echo "Bundle:   $BUNDLE_PATH"
echo "Manifest: $MANIFEST_PATH"
echo "Source:   $SOURCE_URL"
if [[ -n "$IPFS_CID" ]]; then
  echo "IPFS CID: $IPFS_CID"
fi
