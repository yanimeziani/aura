#!/bin/bash
# Meziani AI: NotebookLM Bi-Directional Bridge
# "The road back from the City of Knowledge."

PACKET_DIR="/root/vault/notebooklm_packets"
LOG_DIR="/root/ops/autopilot/results"
REFUND_ENGINE="/root/apps/ai_agency_wealth/refund_engine.sh"

echo "=== NotebookLM Bridge: Active Sweep ==="

# 1. Look for new high-signal packets
for packet in "$PACKET_DIR"/*.md; do
    [ -e "$packet" ] || continue
    
    echo "[*] Ingesting Packet: $(basename "$packet")"
    
    # 2. Scan for specific "Versailles" signals
    if grep -qE "debt|creditor|settlement|refund" "$packet"; then
        echo "[!] HIGH SIGNAL: Debt/Creditor event detected in NotebookLM insight."
        
        # Extract keywords for the refund engine
        SIGNAL=$(grep -E "debt|creditor" "$packet" | head -n 5)
        
        echo "[*] Triggering Versailles Commercial Branch (Refund Engine)..."
        bash "$REFUND_ENGINE" --signal "$SIGNAL"
    fi
    
    # 3. Archive processed packet
    mkdir -p "$PACKET_DIR/processed"
    mv "$packet" "$PACKET_DIR/processed/"
    # Also move the corresponding JSON if it exists
    json_packet="${packet%.md}.json"
    if [ -f "$json_packet" ]; then
        mv "$json_packet" "$PACKET_DIR/processed/"
    fi
done

echo "=== Sweep Complete. Closed-loop parity maintained. ==="
