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
VPS_PASSWORD="${VPS_PASSWORD:?Set VPS_PASSWORD env var}"
DOMAIN="meziani.ai"

echo "════════════════════════════════════════════════════════════════"
echo "  FRESH VPS DEPLOYMENT"
echo "  Career Digital Twin + SDR Agent + Dragun App"
echo "  Target: ${VPS_IP} (${DOMAIN})"
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
    ca-certificates \
    debian-keyring debian-archive-keyring apt-transport-https

# Install Caddy
curl -1sLf 'https://dl.cloudsmith.io/public/caddy/stable/gpg.key' | gpg --dearmor -o /usr/share/keyrings/caddy-stable-archive-keyring.gpg
curl -1sLf 'https://dl.cloudsmith.io/public/caddy/stable/debian.deb.txt' | tee /etc/apt/sources.list.d/caddy-stable.list
apt-get update
apt-get install -y caddy

# Configure firewall
ufw --force enable
ufw allow 22/tcp
ufw allow 80/tcp
ufw allow 443/tcp
ufw allow 3000/tcp  # Dragun App / Cerberus Gateway
ufw allow 3001/tcp  # Career Twin
ufw allow 3002/tcp  # SDR Agent

echo "VPS base setup complete"
EOFSETUP
echo -e "${GREEN}✓ VPS updated and secured (Caddy installed)${NC}"

# Step 3: Create directory structure
echo -e "${BLUE}[3/12] Creating directory structure${NC}"
ssh ${VPS_USER}@${VPS_IP} << 'EOF'
mkdir -p /opt/cerberus
mkdir -p /opt/configs
mkdir -p /opt/scripts
mkdir -p /opt/apps/web
mkdir -p /opt/aura-cert
mkdir -p /root/.cerberus/{memory,logs,configs}
mkdir -p /var/log/cerberus
chmod -R 755 /opt/cerberus /opt/configs /opt/apps /opt/aura-cert
chmod -R 700 /root/.cerberus
EOF
echo -e "${GREEN}✓ Directories created${NC}"

# Step 4: Build Cerberus and Aura Cert locally
echo -e "${BLUE}[4/12] Preparing binaries${NC}"
cd /root/core/cerberus/runtime/cerberus-core
if [ ! -f zig-out/bin/cerberus ]; then
    echo "Building Cerberus..."
    zig build -Doptimize=ReleaseSmall
fi

cd /root/apps/web/aura-cert
if [ ! -f zig-out/bin/aura_cert ]; then
    echo "Building Aura Cert..."
    zig build -Doptimize=ReleaseSmall
fi
echo -e "${GREEN}✓ Binaries ready${NC}"

# Step 5: Deploy Binaries to VPS
echo -e "${BLUE}[5/12] Deploying binaries to VPS${NC}"
scp /root/core/cerberus/runtime/cerberus-core/zig-out/bin/cerberus ${VPS_USER}@${VPS_IP}:/opt/cerberus/
scp /root/apps/web/aura-cert/zig-out/bin/aura_cert ${VPS_USER}@${VPS_IP}:/opt/aura-cert/
ssh ${VPS_USER}@${VPS_IP} "chmod +x /opt/cerberus/cerberus /opt/aura-cert/aura_cert"
echo -e "${GREEN}✓ Binaries deployed${NC}"

# Step 6: Deploy configs and prompts
echo -e "${BLUE}[6/12] Deploying agent configs${NC}"
scp /root/core/cerberus/configs/career-twin-agent.json ${VPS_USER}@${VPS_IP}:/opt/configs/
scp /root/core/cerberus/configs/sdr-agent.json ${VPS_USER}@${VPS_IP}:/opt/configs/
scp /root/core/cerberus/runtime/cerberus-core/prompts/career_twin_prompt.txt ${VPS_USER}@${VPS_IP}:/opt/configs/
scp /root/core/cerberus/runtime/cerberus-core/prompts/sdr_agent_prompt.txt ${VPS_USER}@${VPS_IP}:/opt/configs/
echo -e "${GREEN}✓ Configs deployed${NC}"

# Step 7: Deploy memory structures
echo -e "${BLUE}[7/12] Deploying memory structures${NC}"
if [ -d /root/.cerberus/memory/career_twin ]; then
    scp -r /root/.cerberus/memory/career_twin ${VPS_USER}@${VPS_IP}:/root/.cerberus/memory/
    echo -e "${GREEN}✓ Career Twin memory deployed${NC}"
else
    echo -e "${YELLOW}⚠ Career Twin memory not found locally, initializing on VPS${NC}"
    ssh ${VPS_USER}@${VPS_IP} "mkdir -p /root/.cerberus/memory/career_twin"
fi

if [ -d /root/.cerberus/memory/sdr ]; then
    scp -r /root/.cerberus/memory/sdr ${VPS_USER}@${VPS_IP}:/root/.cerberus/memory/
    echo -e "${GREEN}✓ SDR memory deployed${NC}"
else
    echo -e "${YELLOW}⚠ SDR memory not found locally, initializing on VPS${NC}"
    ssh ${VPS_USER}@${VPS_IP} "mkdir -p /root/.cerberus/memory/sdr"
fi

# Step 8: Deploy initialization scripts
echo -e "${BLUE}[8/12] Deploying helper scripts${NC}"
scp /root/core/cerberus/scripts/init-career-twin-memory.sh ${VPS_USER}@${VPS_IP}:/opt/scripts/
scp /root/core/cerberus/scripts/init-sdr-memory.sh ${VPS_USER}@${VPS_IP}:/opt/scripts/
ssh ${VPS_USER}@${VPS_IP} "chmod +x /opt/scripts/*.sh"
echo -e "${GREEN}✓ Scripts deployed${NC}"

# Step 9: Configure SSL and Caddy for meziani.ai
echo -e "${BLUE}[9/12] Configuring SSL and Caddy reverse proxy${NC}"
ssh ${VPS_USER}@${VPS_IP} << EOF
cd /opt/aura-cert
./aura_cert
mkdir -p /etc/caddy/certs
cp cert.pem /etc/caddy/certs/meziani.ai.crt
cp key.pem /etc/caddy/certs/meziani.ai.key

cat > /etc/caddy/Caddyfile << 'EOFCADDY'
{
    email yani@meziani.ai
}

${DOMAIN}, www.${DOMAIN} {
    encode zstd gzip
    tls /etc/caddy/certs/meziani.ai.crt /etc/caddy/certs/meziani.ai.key
    reverse_proxy localhost:3000
}

api.${DOMAIN} {
    encode zstd gzip
    tls /etc/caddy/certs/meziani.ai.crt /etc/caddy/certs/meziani.ai.key
    reverse_proxy localhost:3001
}
EOFCADDY
systemctl reload caddy
EOF
echo -e "${GREEN}✓ SSL and Caddy configured for ${DOMAIN}${NC}"

# Step 10: Deploy Dragun App (Web Interface)
echo -e "${BLUE}[10/12] Deploying Dragun App${NC}"
echo "Building Dragun App locally..."
cd /root/apps/web
npm install --production=false
npm run build
echo "Deploying built application..."
# We use rsync if available, otherwise scp
ssh ${VPS_USER}@${VPS_IP} "mkdir -p /opt/apps/web"
rsync -avz --delete .next public package.json next.config.ts ${VPS_USER}@${VPS_IP}:/opt/apps/web/
echo -e "${GREEN}✓ Dragun App deployed${NC}"

# Step 11: Create systemd services
echo -e "${BLUE}[11/12] Creating systemd services${NC}"
ssh ${VPS_USER}@${VPS_IP} << 'EOFSVC'
# Career Digital Twin service
cat > /etc/systemd/system/cerberus-career-twin.service << 'EOF'
[Unit]
Description=Cerberus Career Digital Twin Agent
After=network.target

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
EnvironmentFile=/opt/configs/env
ExecStart=/opt/cerberus/cerberus agent --config /opt/configs/sdr-agent.json
Restart=always
RestartSec=10
StandardOutput=append:/var/log/cerberus/sdr.log
StandardError=append:/var/log/cerberus/sdr-error.log

[Install]
WantedBy=multi-user.target
EOF

# Dragun App service
cat > /etc/systemd/system/dragun-app.service << 'EOF'
[Unit]
Description=Dragun App (Next.js)
After=network.target

[Service]
Type=simple
User=root
WorkingDirectory=/opt/apps/web
ExecStart=/usr/bin/npm start
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF

# Reload systemd
systemctl daemon-reload
EOFSVC
echo -e "${GREEN}✓ Systemd services created${NC}"

# Step 12: Final Verify
echo -e "${BLUE}[12/12] Verifying deployment${NC}"
ssh ${VPS_USER}@${VPS_IP} << 'EOFVERIFY'
echo "=== Cerberus Installation ==="
/opt/cerberus/cerberus version || echo "Cerberus not found"

echo ""
echo "=== Services Status ==="
systemctl is-active cerberus-career-twin || echo "career-twin inactive"
systemctl is-active dragun-app || echo "dragun-app inactive"
systemctl is-active caddy || echo "caddy inactive"

echo ""
echo "=== Firewall Status ==="
ufw status | head -5
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
