#!/bin/bash
# Dragun.app SDR Campaign Onboarding Flow
set -e

echo "============================================================"
echo "🐉 Dragun.app SDR Agent Onboarding"
echo "============================================================"
echo "This wizard will initialize your cold email campaign environment."
echo ""

echo "Checking prerequisites..."
if [ ! -f /root/core/cerberus/configs/sdr-agent.json ]; then
    echo "❌ SDR Agent config not found! Please check Cerberus installation."
    exit 1
fi
echo "✅ Cerberus SDR config verified."

echo ""
echo "Step 1: Campaign Setup"
read -p "Enter Campaign Name (e.g., Q1 Outreach): " CAMP_NAME
read -p "Enter Target Audience (e.g., B2B SaaS CTOs): " CAMP_TARGET

mkdir -p /root/.cerberus/memory/sdr/campaigns
CAMP_FILE="/root/.cerberus/memory/sdr/campaigns/$(echo $CAMP_NAME | tr '[:upper:]' '[:lower:]' | tr ' ' '-').md"

cat << INNER_EOF > "$CAMP_FILE"
# Campaign: $CAMP_NAME
**Target:** $CAMP_TARGET
**Status:** Draft

## Objective
To autonomously engage $CAMP_TARGET using personalized insights and secure meetings.
INNER_EOF

echo "✅ Campaign file created at $CAMP_FILE"
echo ""

echo "Step 2: Connecting the SMTP Gateway (Resend)"
if grep -q "RESEND_API_KEY" /root/vault/vault_manager.py; then
    echo "✅ Resend integration detected in vault."
else
    echo "⚠️ Warning: Please configure RESEND_API_KEY in the vault."
fi

echo ""
echo "🎉 Onboarding Complete!"
echo "Next Steps:"
echo "1. Load your prospects into the Supabase 'sdr_prospects' table."
echo "2. Run the SDR Agent via Cerberus:"
echo "   /root/core/cerberus/runtime/cerberus-core/zig-out/bin/cerberus agent -m \"Launch the $CAMP_NAME campaign\" --config /root/cerberus/configs/sdr-agent.json"
echo "============================================================"
