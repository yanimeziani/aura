#!/bin/bash
# Secure station setup — TOR + IPFS + Ed25519
set -euo pipefail

echo "=== Conductor Secure Setup ==="

# Install TOR
if ! command -v tor &>/dev/null; then
    apt-get update && apt-get install -y tor
fi

# Install IPFS
if ! command -v ipfs &>/dev/null; then
    IPFS_VERSION="0.27.0"
    curl -LO "https://dist.ipfs.tech/kubo/v${IPFS_VERSION}/kubo_v${IPFS_VERSION}_linux-amd64.tar.gz"
    tar -xzf "kubo_v${IPFS_VERSION}_linux-amd64.tar.gz"
    mv kubo/ipfs /usr/local/bin/
    rm -rf kubo kubo_*.tar.gz
fi

# Create conductor user
id conductor &>/dev/null || useradd -m -s /bin/bash conductor
mkdir -p /home/conductor/.ssh
chmod 700 /home/conductor/.ssh

# Generate Ed25519 host key (if not exists)
if [[ ! -f /home/conductor/.ssh/id_ed25519 ]]; then
    ssh-keygen -t ed25519 -f /home/conductor/.ssh/id_ed25519 -N "" -C "conductor@station"
    echo "Generated Ed25519 key:"
    cat /home/conductor/.ssh/id_ed25519.pub
fi

# Harden SSHD — Ed25519 only
cat > /etc/ssh/sshd_config.d/conductor.conf << 'EOF'
# Conductor hardened SSH config

# Ed25519 only
HostKey /etc/ssh/ssh_host_ed25519_key
PubkeyAcceptedAlgorithms ssh-ed25519
HostKeyAlgorithms ssh-ed25519

# Disable weak auth
PasswordAuthentication no
ChallengeResponseAuthentication no
KbdInteractiveAuthentication no
PermitRootLogin prohibit-password

# Security
MaxAuthTries 3
LoginGraceTime 30
ClientAliveInterval 300
ClientAliveCountMax 2

# Disable RSA/ECDSA explicitly
# Only Ed25519 signatures accepted
EOF

# Remove RSA/ECDSA host keys
rm -f /etc/ssh/ssh_host_rsa_key* /etc/ssh/ssh_host_ecdsa_key* /etc/ssh/ssh_host_dsa_key*

# Generate Ed25519 host key if missing
if [[ ! -f /etc/ssh/ssh_host_ed25519_key ]]; then
    ssh-keygen -t ed25519 -f /etc/ssh/ssh_host_ed25519_key -N ""
fi

# TOR hidden service config
mkdir -p /var/lib/tor/conductor
cat >> /etc/tor/torrc << 'EOF'

# Conductor hidden service
HiddenServiceDir /var/lib/tor/conductor/
HiddenServicePort 22 127.0.0.1:22
HiddenServicePort 8080 127.0.0.1:8080
EOF

chown -R debian-tor:debian-tor /var/lib/tor/conductor
chmod 700 /var/lib/tor/conductor

# Restart services
systemctl restart tor
systemctl restart sshd

# Wait for onion address
sleep 3
if [[ -f /var/lib/tor/conductor/hostname ]]; then
    echo ""
    echo "=== Onion Address ==="
    cat /var/lib/tor/conductor/hostname
fi

# IPFS init (if needed)
if [[ ! -d /home/conductor/.ipfs ]]; then
    sudo -u conductor ipfs init
fi

echo ""
echo "=== Setup Complete ==="
echo "SSH: Ed25519 only"
echo "TOR: Hidden service active"
echo "IPFS: Ready"
