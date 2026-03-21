#!/usr/bin/env bash
set -euo pipefail

# VPS Deployment Script for Career Digital Twin + SDR Agent
# Target VPS: 89.116.170.202 (Hostinger)

# Colors
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

VPS_IP="89.116.170.202"
VPS_USER="root"
VPS_PASSWORD="${VPS_PASSWORD:?Set VPS_PASSWORD env var}"

echo "════════════════════════════════════════════════════════════════"
echo "  VPS DEPLOYMENT - Career Digital Twin + SDR Agent"
echo "  Target: ${VPS_IP}"
echo "════════════════════════════════════════════════════════════════"
echo ""

# Step 1: Generate SSH key if not exists
echo -e "${BLUE}[1/10] Setting up SSH keys${NC}"
if [ ! -f ~/.ssh/id_rsa ]; then
    ssh-keygen -t rsa -b 4096 -f ~/.ssh/id_rsa -N "" -C "cerberus-deploy@$(hostname)"
    echo -e "${GREEN}✓ SSH key generated${NC}"
else
    echo -e "${GREEN}✓ SSH key already exists${NC}"
fi

# Step 2: Copy SSH key to VPS (using sshpass)
echo -e "${BLUE}[2/10] Installing sshpass for password authentication${NC}"
apt-get update -qq && apt-get install -y sshpass > /dev/null 2>&1
echo -e "${GREEN}✓ sshpass installed${NC}"

echo -e "${BLUE}[3/10] Copying SSH key to VPS${NC}"
sshpass -p "${VPS_PASSWORD}" ssh-copy-id -o StrictHostKeyChecking=no ${VPS_USER}@${VPS_IP} 2>/dev/null || true
echo -e "${GREEN}✓ SSH key copied (or already present)${NC}"

# Step 3: Test SSH connection
echo -e "${BLUE}[4/10] Testing SSH connection${NC}"
if ssh -o ConnectTimeout=10 ${VPS_USER}@${VPS_IP} "echo 'Connection successful'"; then
    echo -e "${GREEN}✓ SSH connection working${NC}"
else
    echo -e "${RED}✗ SSH connection failed${NC}"
    echo "Please verify VPS password and try again"
    exit 1
fi

# Step 4: Prepare deployment directories on VPS
echo -e "${BLUE}[5/10] Creating deployment directories on VPS${NC}"
ssh ${VPS_USER}@${VPS_IP} << 'EOF'
mkdir -p /opt/cerberus
mkdir -p /opt/dragun-app
mkdir -p /opt/configs
mkdir -p /root/.cerberus/memory
mkdir -p /var/log/cerberus
chown -R root:root /opt/cerberus /opt/dragun-app /opt/configs
EOF
echo -e "${GREEN}✓ Directories created${NC}"

# Step 5: Build Cerberus for production
echo -e "${BLUE}[6/10] Building Cerberus (ReleaseSmall)${NC}"
cd /root/cerberus/runtime/cerberus-core
# Check if already built
if [ -f zig-out/bin/cerberus ]; then
    echo -e "${GREEN}✓ Using existing Cerberus binary${NC}"
else
    echo "Building (this may take 2-3 minutes)..."
    zig build -Doptimize=ReleaseSmall
    echo -e "${GREEN}✓ Cerberus built successfully${NC}"
fi

# Step 6: Copy Cerberus to VPS
echo -e "${BLUE}[7/10] Deploying Cerberus to VPS${NC}"
scp /root/cerberus/runtime/cerberus-core/zig-out/bin/cerberus ${VPS_USER}@${VPS_IP}:/opt/cerberus/
scp /root/cerberus/configs/career-twin-agent.json ${VPS_USER}@${VPS_IP}:/opt/configs/
scp /root/cerberus/configs/sdr-agent.json ${VPS_USER}@${VPS_IP}:/opt/configs/
scp /root/cerberus/runtime/cerberus-core/prompts/career_twin_prompt.txt ${VPS_USER}@${VPS_IP}:/opt/configs/
scp /root/cerberus/runtime/cerberus-core/prompts/sdr_agent_prompt.txt ${VPS_USER}@${VPS_IP}:/opt/configs/
echo -e "${GREEN}✓ Cerberus deployed${NC}"

# Step 7: Copy memory structures to VPS
echo -e "${BLUE}[8/10] Copying memory structures to VPS${NC}"
if [ -d ~/.cerberus/memory/career_twin ]; then
    scp -r ~/.cerberus/memory/career_twin ${VPS_USER}@${VPS_IP}:/root/.cerberus/memory/
    echo -e "${GREEN}✓ Career Twin memory copied${NC}"
else
    echo -e "${YELLOW}⚠ Career Twin memory not initialized yet${NC}"
fi

if [ -d ~/.cerberus/memory/sdr ]; then
    scp -r ~/.cerberus/memory/sdr ${VPS_USER}@${VPS_IP}:/root/.cerberus/memory/
    echo -e "${GREEN}✓ SDR memory copied${NC}"
else
    echo -e "${YELLOW}⚠ SDR memory not initialized yet${NC}"
fi

# Step 8: Create systemd service files on VPS
echo -e "${BLUE}[9/10] Creating systemd services on VPS${NC}"
ssh ${VPS_USER}@${VPS_IP} << 'EOFSERVICE'
# Career Digital Twin service
cat > /etc/systemd/system/cerberus-career-twin.service << 'EOF'
[Unit]
Description=Cerberus Career Digital Twin Agent
After=network.target

[Service]
Type=simple
User=root
WorkingDirectory=/opt/cerberus
Environment="OPENROUTER_API_KEY=YOUR_KEY_HERE"
ExecStart=/opt/cerberus/cerberus agent --config /opt/configs/career-twin-agent.json
Restart=always
RestartSec=10
StandardOutput=append:/var/log/cerberus/career-twin.log
StandardError=append:/var/log/cerberus/career-twin.error.log

[Install]
WantedBy=multi-user.target
EOF

# SDR Agent service
cat > /etc/systemd/system/cerberus-sdr.service << 'EOF'
[Unit]
Description=Cerberus SDR Agent
After=network.target

[Service]
Type=simple
User=root
WorkingDirectory=/opt/cerberus
Environment="OPENROUTER_API_KEY=YOUR_KEY_HERE"
Environment="RESEND_API_KEY=YOUR_KEY_HERE"
ExecStart=/opt/cerberus/cerberus agent --config /opt/configs/sdr-agent.json
Restart=always
RestartSec=10
StandardOutput=append:/var/log/cerberus/sdr.log
StandardError=append:/var/log/cerberus/sdr.error.log

[Install]
WantedBy=multi-user.target
EOF

# Reload systemd
systemctl daemon-reload
EOFSERVICE
echo -e "${GREEN}✓ Systemd services created${NC}"

# Step 9: Verify deployment
echo -e "${BLUE}[10/10] Verifying deployment${NC}"
ssh ${VPS_USER}@${VPS_IP} << 'EOF'
echo "Checking binary..."
/opt/cerberus/cerberus version

echo ""
echo "Checking configs..."
ls -lh /opt/configs/

echo ""
echo "Checking memory..."
ls -lh /root/.cerberus/memory/ 2>/dev/null || echo "Memory directories created"

echo ""
echo "Checking services..."
systemctl list-unit-files | grep cerberus
EOF
echo -e "${GREEN}✓ Deployment verified${NC}"

echo ""
echo "════════════════════════════════════════════════════════════════"
echo -e "${GREEN}  ✓ DEPLOYMENT COMPLETE${NC}"
echo "════════════════════════════════════════════════════════════════"
echo ""
echo "Next steps:"
echo ""
echo "1. SSH into your VPS:"
echo "   ssh ${VPS_USER}@${VPS_IP}"
echo ""
echo "2. Edit systemd service files to add your API keys:"
echo "   nano /etc/systemd/system/cerberus-career-twin.service"
echo "   nano /etc/systemd/system/cerberus-sdr.service"
echo ""
echo "3. Start the services:"
echo "   systemctl enable cerberus-career-twin"
echo "   systemctl start cerberus-career-twin"
echo "   systemctl status cerberus-career-twin"
echo ""
echo "4. View logs:"
echo "   tail -f /var/log/cerberus/career-twin.log"
echo "   journalctl -u cerberus-career-twin -f"
echo ""
echo "5. Deploy Dragun-app (optional, for web interface):"
echo "   See /root/QUICKSTART.md for Next.js deployment"
echo ""
