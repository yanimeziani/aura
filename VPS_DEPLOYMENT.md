# VPS Deployment Guide - Fresh Debian

## Overview

This guide will deploy both **Career Digital Twin** and **SDR Agent** to your fresh Debian VPS at `89.116.170.202`.

## Prerequisites

- ✅ Fresh Debian VPS (you're reinstalling now)
- ✅ Root access
- ✅ Password: `@@Hostinger02103`
- ✅ Local Cerberus built and ready
- ✅ Memory structures initialized

## One-Command Deployment

Once your VPS reinstallation is complete, run:

```bash
bash /root/deploy-fresh-vps.sh
```

This script will:
1. ✅ Set up SSH key authentication
2. ✅ Update VPS and install dependencies
3. ✅ Configure firewall (UFW + fail2ban)
4. ✅ Deploy Cerberus binary (2.5MB)
5. ✅ Deploy agent configs and prompts
6. ✅ Deploy memory structures
7. ✅ Create systemd services
8. ✅ Install Node.js for Dragun-app
9. ✅ Verify deployment

**Estimated time:** 5-10 minutes (depending on VPS speed)

---

## What Gets Deployed

### Directory Structure on VPS
```
/opt/
├── cerberus/
│   └── cerberus              # 2.5MB binary
├── configs/
│   ├── career-twin-agent.json
│   ├── sdr-agent.json
│   ├── career_twin_prompt.txt
│   ├── sdr_agent_prompt.txt
│   ├── env.template          # API keys template
│   └── README.md
└── scripts/
    ├── init-career-twin-memory.sh
    └── init-sdr-memory.sh

/root/.cerberus/
├── memory/
│   ├── career_twin/          # Your profile, skills, projects
│   └── sdr/                  # Email templates, campaigns
├── logs/
└── configs/

/var/log/cerberus/
├── career-twin.log
├── career-twin-error.log
├── sdr.log
└── sdr-error.log

/etc/systemd/system/
├── cerberus-career-twin.service
└── cerberus-sdr.service
```

### Systemd Services Created

1. **cerberus-career-twin.service**
   - Auto-restart on failure
   - Logs to `/var/log/cerberus/career-twin.log`
   - Reads API keys from `/opt/configs/env`

2. **cerberus-sdr.service**
   - Auto-restart on failure
   - Logs to `/var/log/cerberus/sdr.log`
   - Reads API keys from `/opt/configs/env`

### Firewall Rules (UFW)

```
Port 22   (SSH)            ✓ Allowed
Port 80   (HTTP)           ✓ Allowed
Port 443  (HTTPS)          ✓ Allowed
Port 3000 (Cerberus)       ✓ Allowed
Port 3001 (Career Twin)    ✓ Allowed
Port 3002 (SDR)            ✓ Allowed
```

---

## Post-Deployment Configuration

### Step 1: SSH into VPS

```bash
ssh root@89.116.170.202
```

### Step 2: Configure API Keys

```bash
# Copy environment template
cp /opt/configs/env.template /opt/configs/env

# Edit and add your API keys
nano /opt/configs/env
```

Add your keys:
```bash
OPENROUTER_API_KEY=sk-or-v1-xxxxx
RESEND_API_KEY=re_xxxxx  # Optional, for SDR emails
```

### Step 3: Edit Your Profile

```bash
# Edit career profile
nano /root/.cerberus/memory/career_twin/profile.md

# Update with your real:
# - Contact info (email, LinkedIn, GitHub)
# - Work authorization
# - Salary expectations
# - Current availability
```

### Step 4: Start Career Digital Twin

```bash
# Enable service to start on boot
systemctl enable cerberus-career-twin

# Start the service
systemctl start cerberus-career-twin

# Check status
systemctl status cerberus-career-twin

# View logs
journalctl -u cerberus-career-twin -f
```

### Step 5: Start SDR Agent (Optional)

```bash
systemctl enable cerberus-sdr
systemctl start cerberus-sdr
systemctl status cerberus-sdr
```

---

## Testing the Deployment

### Test 1: Verify Cerberus Binary

```bash
/opt/cerberus/cerberus version
/opt/cerberus/cerberus capabilities --json
```

Expected output:
```
cerberus 2026.3.1
```

### Test 2: Test Career Twin Locally

```bash
/opt/cerberus/cerberus agent \
  -m "Tell me about my TypeScript experience" \
  --config /opt/configs/career-twin-agent.json
```

### Test 3: Check Service Status

```bash
# Both should be "active (running)"
systemctl status cerberus-career-twin
systemctl status cerberus-sdr
```

### Test 4: Check Logs

```bash
# Career Twin logs
tail -f /var/log/cerberus/career-twin.log

# SDR logs
tail -f /var/log/cerberus/sdr.log

# Or use journalctl
journalctl -u cerberus-career-twin -n 50
```

---

## Deploying Dragun-app Web Interface (Optional)

If you want the web dashboard at `http://89.116.170.202:3000/career-twin`:

```bash
# On VPS
cd /opt
git clone <your-dragun-repo> dragun-app
cd dragun-app

# Install dependencies
npm ci --production

# Configure environment
cp .env.example .env.production
nano .env.production
# Add:
# CERBERUS_API_URL=http://localhost:3000
# DATABASE_URL=your_supabase_url
# etc.

# Build
npm run build

# Create systemd service
cat > /etc/systemd/system/dragun-app.service << 'EOF'
[Unit]
Description=Dragun App (Next.js)
After=network.target

[Service]
Type=simple
User=root
WorkingDirectory=/opt/dragun-app
EnvironmentFile=/opt/dragun-app/.env.production
ExecStart=/usr/bin/npm start
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF

# Start service
systemctl daemon-reload
systemctl enable dragun-app
systemctl start dragun-app
systemctl status dragun-app
```

---

## Monitoring and Maintenance

### View Real-time Logs

```bash
# Career Twin
journalctl -u cerberus-career-twin -f

# SDR Agent
journalctl -u cerberus-sdr -f

# All Cerberus logs
tail -f /var/log/cerberus/*.log
```

### Check Resource Usage

```bash
# CPU and memory
htop

# Disk space
df -h

# Service resource usage
systemctl status cerberus-career-twin
systemctl status cerberus-sdr
```

### Restart Services

```bash
# Restart Career Twin
systemctl restart cerberus-career-twin

# Restart SDR
systemctl restart cerberus-sdr

# Reload after config changes
systemctl daemon-reload
systemctl restart cerberus-career-twin
```

### Update Agent Memory

```bash
# Edit profile
nano /root/.cerberus/memory/career_twin/profile.md

# No restart needed - memory is read dynamically
```

### View Cost Logs

```bash
# Check token usage
grep "tokens" /root/.cerberus/logs/cost.log | tail -20

# Check daily spend
grep "$(date +%Y-%m-%d)" /root/.cerberus/logs/cost.log
```

---

## Troubleshooting

### Issue: Service won't start

**Check:**
```bash
# View detailed logs
journalctl -u cerberus-career-twin -xe

# Check config syntax
cat /opt/configs/career-twin-agent.json | python3 -m json.tool

# Verify API key
cat /opt/configs/env | grep OPENROUTER
```

### Issue: Binary not found

**Fix:**
```bash
# Verify binary exists
ls -lh /opt/cerberus/cerberus

# Make executable
chmod +x /opt/cerberus/cerberus

# Test directly
/opt/cerberus/cerberus version
```

### Issue: Memory errors

**Fix:**
```bash
# Reinitialize memory
bash /opt/scripts/init-career-twin-memory.sh
bash /opt/scripts/init-sdr-memory.sh

# Check permissions
chmod -R 700 /root/.cerberus
```

### Issue: Firewall blocking

**Check:**
```bash
# View firewall status
ufw status verbose

# Allow port
ufw allow 3000/tcp

# Reload
ufw reload
```

---

## Security Best Practices

### 1. SSH Key Only (Disable Password)

```bash
# After SSH key is working
nano /etc/ssh/sshd_config

# Set:
PasswordAuthentication no
PermitRootLogin prohibit-password

# Restart SSH
systemctl restart sshd
```

### 2. Configure fail2ban

```bash
# Already installed by deploy script
systemctl status fail2ban

# Check banned IPs
fail2ban-client status sshd
```

### 3. Regular Updates

```bash
# Weekly updates
apt-get update && apt-get upgrade -y

# Check for security updates
apt-get upgrade -s | grep -i security
```

### 4. Backup Memory Structures

```bash
# Backup to local machine
scp -r root@89.116.170.202:/root/.cerberus/memory /root/backups/vps-memory-$(date +%Y%m%d)

# Or create cron job on VPS
crontab -e
# Add: 0 2 * * * tar -czf /root/backups/cerberus-memory-$(date +\%Y\%m\%d).tar.gz /root/.cerberus/memory
```

---

## Uninstall (if needed)

```bash
# Stop services
systemctl stop cerberus-career-twin cerberus-sdr
systemctl disable cerberus-career-twin cerberus-sdr

# Remove systemd services
rm /etc/systemd/system/cerberus-*.service
systemctl daemon-reload

# Remove files
rm -rf /opt/cerberus /opt/configs /root/.cerberus /var/log/cerberus
```

---

## Success Checklist

After deployment, verify:

- [ ] SSH connection works without password
- [ ] Cerberus binary runs (`/opt/cerberus/cerberus version`)
- [ ] API keys configured in `/opt/configs/env`
- [ ] Profile edited in `/root/.cerberus/memory/career_twin/profile.md`
- [ ] Career Twin service running (`systemctl status cerberus-career-twin`)
- [ ] Logs show no errors (`journalctl -u cerberus-career-twin -n 50`)
- [ ] Agent responds to test query
- [ ] Firewall configured correctly (`ufw status`)
- [ ] fail2ban active (`systemctl status fail2ban`)

---

## Support

- **Deployment script**: `/root/deploy-fresh-vps.sh`
- **Local docs**: `/root/QUICKSTART.md`, `/root/PROJECT_SUMMARY.md`
- **VPS docs**: `/opt/configs/README.md`
- **Logs**: `/var/log/cerberus/` and `journalctl`

---

**Ready to deploy? Wait for VPS reinstall to complete, then run:**

```bash
bash /root/deploy-fresh-vps.sh
```
