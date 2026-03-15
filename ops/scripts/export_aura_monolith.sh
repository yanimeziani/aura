#!/usr/bin/env bash
# export_aura_monolith.sh
# Comprehensive Aura Monolith Export for NotebookLM Ingestion.

set -euo pipefail

OUT_BASE="/root/exports"
mkdir -p "$OUT_BASE"
TS="$(date -u +%Y%m%dT%H%M%SZ)"
EXPORT_NAME="aura-monolith-${TS}"
ARCHIVE_PATH="${OUT_BASE}/${EXPORT_NAME}.7z"
PASSWORD="AuraMonolith2026!"

echo "[$(date)] Initializing Aura Monolith Export..."

# Exclude list for 7z
# -xr!node_modules -xr!android-sdk -xr!.git -xr!.npm -xr!.gradle -xr!.local -xr!.gemini
# We specifically want: apps, core, docs, research, packages, ops, README.md, PROJECT_SOURCE_TRUTH.md

7z a -p"$PASSWORD" -mhe=on "$ARCHIVE_PATH" /root \
  -xr!node_modules \
  -xr!android-sdk \
  -xr!.git \
  -xr!.npm \
  -xr!.gradle \
  -xr!.local \
  -xr!.gemini \
  -xr!.rustup \
  -xr!.cargo \
  -xr!exports

echo "[$(date)] Archive created: $ARCHIVE_PATH"
echo "[$(date)] Uploading to secure one-time host..."

DOWNLOAD_LINK=$(curl -F "file=@$ARCHIVE_PATH" https://0x0.st)

echo "------------------------------------------------"
echo "AURA MONOLITH EXPORT COMPLETE"
echo "------------------------------------------------"
echo "Download Link: $DOWNLOAD_LINK"
echo "Password:      $PASSWORD"
echo "Format:        7-Zip Encrypted (Metadata Hidden)"
echo "Target:        NotebookLM Ingestion"
echo "------------------------------------------------"

# Optional: Cleanup local copy after upload
# rm "$ARCHIVE_PATH"
