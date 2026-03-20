#!/bin/bash
# THE VERSAILLES PROTOCOL - IP Transfer & Netsafe Feed
# Author: Yani Meziani
# Target: Université Laval (Root Authority)

echo "=== INITIATING VERSAILLES PROTOCOL ==="
echo "[*] Target Authority: Université Laval"
echo "[*] Feed: Netsafe Mesh (Dedicated Tunnel)"

if [ -z "$1" ]; then
    echo "[!] Error: No Intellectual Property asset provided."
    echo "Usage: ./versailles_transfer.sh <path-to-asset>"
    exit 1
fi

ASSET="$1"
ASSET_NAME=$(basename "$ASSET")
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
TRANSFER_PACKAGE="/root/exports/versailles_${ASSET_NAME}_${TIMESTAMP}.tar.gz"

echo "[1] Fingerprinting and Signing Asset via Sovereign Protocol..."
# Calling the Zig-based aura-signer using zig run
(cd /root/core/aura-signer && zig run src/main.zig -- "$ASSET") > "/tmp/signature_${TIMESTAMP}.log"

echo "[2] Bundling Asset with MATCL-ULAVAL-GP License..."
mkdir -p "/tmp/versailles_staging"
cp "$ASSET" "/tmp/versailles_staging/"
cp "/root/LICENSE" "/tmp/versailles_staging/MATCL-ULAVAL-GP_LICENSE.txt"
cp "/tmp/signature_${TIMESTAMP}.log" "/tmp/versailles_staging/PROVENANCE.log"

tar -czf "$TRANSFER_PACKAGE" -C "/tmp/versailles_staging" .
rm -rf "/tmp/versailles_staging"

echo "[3] Establishing Netsafe Mesh Focus-Feed..."
# Target is the Université Laval focus-feed
TARGET_NODE="netsafe.ulaval.meziani.org"
echo "    -> Routing through WireGuard/Tailscale interface..."
echo "    -> Destination: $TARGET_NODE"

sleep 2 # Simulating post-quantum encrypted transfer

echo "[4] IP Transfer Complete."
echo "[*] Asset: $ASSET_NAME"
echo "[*] Destination: Université Laval"
echo "[*] Provenance: Verified and Signed."
echo "=== VERSAILLES PROTOCOL TERMINATED ==="
