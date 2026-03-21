#!/usr/bin/env bash
# Quick VPS connection helper

VPS_IP="89.116.170.202"
VPS_USER="root"
VPS_PASSWORD="${VPS_PASSWORD:?Set VPS_PASSWORD env var}"

echo "Connecting to VPS: ${VPS_IP}"
echo ""

# Install sshpass if not present
if ! command -v sshpass &> /dev/null; then
    echo "Installing sshpass..."
    apt-get update -qq && apt-get install -y sshpass > /dev/null 2>&1
fi

# Connect
sshpass -p "${VPS_PASSWORD}" ssh -o StrictHostKeyChecking=no ${VPS_USER}@${VPS_IP}
