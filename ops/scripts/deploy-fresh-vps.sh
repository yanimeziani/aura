#!/usr/bin/env bash
set -euo pipefail

# Fresh Debian VPS Deployment Script
# Career Digital Twin + SDR Agent
# Run this AFTER VPS is reinstalled with fresh Debian

# Colors
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

VPS_IP="89.116.170.202"
VPS_USER="root"
VPS_PASSWORD="@@Hostinger02103"

echo "════════════════════════════════════════════════════════════════"
echo "  FRESH VPS DEPLOYMENT"
echo "  Career Digital Twin + SDR Agent"
echo "  Target: ${VPS_IP} (Fresh Debian)"
echo "════════════════════════════════════════════════════════════════"
echo ""

# Wait for VPS to be ready
echo -e "${BLUE}Waiting for VPS to be accessible...${NC}"
for i in {1..30}; do
    if sshpass -p "${VPS_PASSWORD}" ssh -o StrictHostKeyChecking=no -o ConnectTimeout=5 ${VPS_USER}@${VPS_IP} "echo 'ready'" 2>/dev/null; then
        echo -e "${GREEN}✓ VPS is accessible${NC}"
        break
    fi
    echo "Attempt $i/30: VPS not ready yet, waiting 10 seconds..."
    sleep 10
done

# Step 1: Copy SSH key
echo -e "${BLUE}[1/12] Setting up SSH key authentication${NC}"
if [ ! -f ~/.ssh/id_rsa ]; then
    ssh-keygen -t rsa -b 4096 -f ~/.ssh/id_rsa -N "" -C "cerberus-$(hostname)"
fi
sshpass -p "${VPS_PASSWORD}" ssh-copy-id -o StrictHostKeyChecking=no ${VPS_USER}@${VPS_IP} 2>/dev/null || echo "Key already present"
echo -e "${GREEN}✓ SSH key configured${NC}"

# Step 2: Initial VPS setup
echo -e "${BLUE}[2/12] Updating VPS and installing dependencies${NC}"
ssh ${VPS_USER}@${VPS_IP} << 'EOFSETUP'
set -e
export DEBIAN_FRONTEND=noninteractive

# Update system
apt-get update -qq
apt-get upgrade -y -qq

# Install essential packages
apt-get install -y -qq \
    curl wget git vim nano \
    build-essential \
    ufw fail2ban \
    htop tmux \
    sqlite3 \
    ca-certificates

# Configure firewall
ufw --force enable
ufw allow 22/tcp
ufw allow 80/tcp
ufw allow 443/tcp
ufw allow 3000/tcp  # Cerberus gateway
ufw allow 3001/tcp  # Career Twin
ufw allow 3002/tcp  # SDR Agent

echo "VPS base setup complete"
EOFSETUP
echo -e "${GREEN}✓ VPS updated and secured${NC}"

# Step 3: Create directory structure
echo -e "${BLUE}[3/12] Creating directory structure${NC}"
ssh ${VPS_USER}@${VPS_IP} << 'EOF'
mkdir -p /opt/cerberus
mkdir -p /opt/configs
mkdir -p /opt/scripts
mkdir -p /root/.cerberus/{memory,logs,configs}
mkdir -p /var/log/cerberus
chmod -R 755 /opt/cerberus /opt/configs
chmod -R 700 /root/.cerberus
EOF
echo -e "${GREEN}✓ Directories created${NC}"

# Step 4: Build Cerberus locally if needed
echo -e "${BLUE}[4/12] Preparing Cerberus binary${NC}"
cd /root/cerberus/runtime/cerberus-core
if [ ! -f zig-out/bin/cerberus ]; then
    echo "Building Cerberus (this takes 2-3 minutes)..."
    zig build -Doptimize=ReleaseSmall
fi
BINARY_SIZE=$(ls -lh zig-out/bin/cerberus | awk '{print $5}')
echo -e "${GREEN}✓ Cerberus binary ready (${BINARY_SIZE})${NC}"

# Step 5: Deploy Cerberus
echo -e "${BLUE}[5/12] Deploying Cerberus to VPS${NC}"
scp /root/cerberus/runtime/cerberus-core/zig-out/bin/cerberus ${VPS_USER}@${VPS_IP}:/opt/cerberus/
ssh ${VPS_USER}@${VPS_IP} "chmod +x /opt/cerberus/cerberus"
echo -e "${GREEN}✓ Cerberus deployed${NC}"

# Step 6: Deploy configs and prompts
echo -e "${BLUE}[6/12] Deploying agent configs${NC}"
scp /root/cerberus/configs/career-twin-agent.json ${VPS_USER}@${VPS_IP}:/opt/configs/
scp /root/cerberus/configs/sdr-agent.json ${VPS_USER}@${VPS_IP}:/opt/configs/
scp /root/cerberus/runtime/cerberus-core/prompts/career_twin_prompt.txt ${VPS_USER}@${VPS_IP}:/opt/configs/
scp /root/cerberus/runtime/cerberus-core/prompts/sdr_agent_prompt.txt ${VPS_USER}@${VPS_IP}:/opt/configs/
echo -e "${GREEN}✓ Configs deployed${NC}"

# Step 7: Deploy memory structures
echo -e "${BLUE}[7/12] Deploying memory structures${NC}"
if [ -d ~/.cerberus/memory/career_twin ]; then
    scp -r ~/.cerberus/memory/career_twin ${VPS_USER}@${VPS_IP}:/root/.cerberus/memory/
    echo -e "${GREEN}✓ Career Twin memory deployed${NC}"
else
    echo -e "${YELLOW}⚠ Career Twin memory not found, will initialize on VPS${NC}"
    ssh ${VPS_USER}@${VPS_IP} "mkdir -p /root/.cerberus/memory/career_twin"
fi

if [ -d ~/.cerberus/memory/sdr ]; then
    scp -r ~/.cerberus/memory/sdr ${VPS_USER}@${VPS_IP}:/root/.cerberus/memory/
    echo -e "${GREEN}✓ SDR memory deployed${NC}"
else
    echo -e "${YELLOW}⚠ SDR memory not found, will initialize on VPS${NC}"
    ssh ${VPS_USER}@${VPS_IP} "mkdir -p /root/.cerberus/memory/sdr"
fi

# Step 8: Deploy initialization scripts
echo -e "${BLUE}[8/12] Deploying helper scripts${NC}"
scp /root/cerberus/scripts/init-career-twin-memory.sh ${VPS_USER}@${VPS_IP}:/opt/scripts/
scp /root/cerberus/scripts/init-sdr-memory.sh ${VPS_USER}@${VPS_IP}:/opt/scripts/
ssh ${VPS_USER}@${VPS_IP} "chmod +x /opt/scripts/*.sh"
echo -e "${GREEN}✓ Scripts deployed${NC}"

# Step 9: Create environment file template
echo -e "${BLUE}[9/12] Creating environment configuration${NC}"
ssh ${VPS_USER}@${VPS_IP} << 'EOFENV'
cat > /opt/configs/env.template << 'EOF'
# Cerberus Agent Environment Variables
# Copy this to /opt/configs/env and fill in your API keys

# Required: OpenRouter API Key (for Claude Sonnet 4)
OPENROUTER_API_KEY=your_openrouter_api_key_here

# Optional: Resend API Key (for SDR email sending)
RESEND_API_KEY=your_resend_api_key_here

# Optional: Cerberus Gateway
CERBERUS_GATEWAY_PORT=3000
CERBERUS_GATEWAY_HOST=0.0.0.0

# Optional: Cost limits
DAILY_TOKEN_BUDGET=100000
MONTHLY_COST_LIMIT=100
EOF

cat > /opt/configs/README.md << 'EOF'
# Cerberus VPS Deployment

## Quick Start

1. Configure API keys:
   cp /opt/configs/env.template /opt/configs/env
   nano /opt/configs/env

2. Start Career Digital Twin:
   systemctl start cerberus-career-twin
   systemctl status cerberus-career-twin

3. Start SDR Agent:
   systemctl start cerberus-sdr
   systemctl status cerberus-sdr

4. View logs:
   journalctl -u cerberus-career-twin -f
   tail -f /var/log/cerberus/career-twin.log

## Verify Installation
/opt/cerberus/cerberus version
/opt/cerberus/cerberus capabilities --json

## Memory Locations
- Career Twin: /root/.cerberus/memory/career_twin/
- SDR Agent: /root/.cerberus/memory/sdr/

## Edit Profile
nano /root/.cerberus/memory/career_twin/profile.md
EOF
EOFENV
echo -e "${GREEN}✓ Environment template created${NC}"

# Step 10: Create systemd services
echo -e "${BLUE}[10/12] Creating systemd services${NC}"
ssh ${VPS_USER}@${VPS_IP} << 'EOFSVC'
# Career Digital Twin service
cat > /etc/systemd/system/cerberus-career-twin.service << 'EOF'
[Unit]
Description=Cerberus Career Digital Twin Agent
After=network.target
Documentation=https://github.com/cerberus

[Service]
Type=simple
User=root
WorkingDirectory=/opt/cerberus
EnvironmentFile=/opt/configs/env
ExecStart=/opt/cerberus/cerberus agent --config /opt/configs/career-twin-agent.json
Restart=always
RestartSec=10
StandardOutput=append:/var/log/cerberus/career-twin.log
StandardError=append:/var/log/cerberus/career-twin-error.log

# Security
NoNewPrivileges=true
PrivateTmp=true

[Install]
WantedBy=multi-user.target
EOF

# SDR Agent service
cat > /etc/systemd/system/cerberus-sdr.service << 'EOF'
[Unit]
Description=Cerberus SDR Agent
After=network.target
Documentation=https://github.com/cerberus

[Service]
Type=simple
User=root
WorkingDirectory=/opt/cerberus
EnvironmentFile=/opt/configs/env
ExecStart=/opt/cerberus/cerberus agent --config /opt/configs/sdr-agent.json
Restart=always
RestartSec=10
StandardOutput=append:/var/log/cerberus/sdr.log
StandardError=append:/var/log/cerberus/sdr-error.log

# Security
NoNewPrivileges=true
PrivateTmp=true

[Install]
WantedBy=multi-user.target
EOF

# Reload systemd
systemctl daemon-reload
EOFSVC
echo -e "${GREEN}✓ Systemd services created${NC}"

# Step 11: Install Node.js for Dragun-app (optional)
echo -e "${BLUE}[11/12] Installing Node.js (for Dragun-app)${NC}"
ssh ${VPS_USER}@${VPS_IP} << 'EOFNODE'
# Install Node.js 20.x
curl -fsSL https://deb.nodesource.com/setup_20.x | bash - > /dev/null 2>&1
apt-get install -y -qq nodejs
node --version
npm --version
EOFNODE
echo -e "${GREEN}✓ Node.js installed${NC}"

# Step 12: Verify deployment
echo -e "${BLUE}[12/12] Verifying deployment${NC}"
ssh ${VPS_USER}@${VPS_IP} << 'EOFVERIFY'
echo "=== Cerberus Installation ==="
/opt/cerberus/cerberus version
ls -lh /opt/cerberus/cerberus

echo ""
echo "=== Configurations ==="
ls -lh /opt/configs/

echo ""
echo "=== Memory Structures ==="
ls -lh /root/.cerberus/memory/

echo ""
echo "=== Systemd Services ==="
systemctl list-unit-files | grep cerberus

echo ""
echo "=== Firewall Status ==="
ufw status | head -10
EOFVERIFY
echo -e "${GREEN}✓ Deployment verified${NC}"

echo ""
echo "════════════════════════════════════════════════════════════════"
echo -e "${GREEN}  ✓ FRESH VPS DEPLOYMENT COMPLETE${NC}"
echo "════════════════════════════════════════════════════════════════"
echo ""
echo "VPS IP: ${VPS_IP}"
echo "SSH: ssh ${VPS_USER}@${VPS_IP}"
echo ""
echo -e "${YELLOW}NEXT STEPS:${NC}"
echo ""
echo "1. SSH into VPS:"
echo "   ssh ${VPS_USER}@${VPS_IP}"
echo ""
echo "2. Configure API keys:"
echo "   cp /opt/configs/env.template /opt/configs/env"
echo "   nano /opt/configs/env"
echo "   (Add your OPENROUTER_API_KEY)"
echo ""
echo "3. Edit your profile:"
echo "   nano /root/.cerberus/memory/career_twin/profile.md"
echo ""
echo "4. Start Career Digital Twin:"
echo "   systemctl enable cerberus-career-twin"
echo "   systemctl start cerberus-career-twin"
echo "   systemctl status cerberus-career-twin"
echo ""
echo "5. Start SDR Agent (optional):"
echo "   systemctl enable cerberus-sdr"
echo "   systemctl start cerberus-sdr"
echo ""
echo "6. View logs:"
echo "   journalctl -u cerberus-career-twin -f"
echo "   tail -f /var/log/cerberus/career-twin.log"
echo ""
echo "7. Test the agent:"
echo "   /opt/cerberus/cerberus agent -m 'Tell me about my projects'"
echo ""
echo -e "${BLUE}Documentation:${NC}"
echo "  VPS: /opt/configs/README.md"
echo "  Local: /root/QUICKSTART.md"
echo ""
