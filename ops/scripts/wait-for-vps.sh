#!/usr/bin/env bash
# Wait for VPS to become available after reinstall

VPS_IP="89.116.170.202"
VPS_USER="root"
VPS_PASSWORD="${VPS_PASSWORD:?Set VPS_PASSWORD env var}"

echo "════════════════════════════════════════════════════════════════"
echo "  Waiting for VPS to be ready after reinstall"
echo "  IP: ${VPS_IP}"
echo "════════════════════════════════════════════════════════════════"
echo ""

attempt=1
max_attempts=60  # 10 minutes (60 * 10 seconds)

while [ $attempt -le $max_attempts ]; do
    echo -n "[$attempt/$max_attempts] Checking VPS... "
    
    if timeout 5 bash -c "sshpass -p '${VPS_PASSWORD}' ssh -o StrictHostKeyChecking=no -o ConnectTimeout=5 ${VPS_USER}@${VPS_IP} 'echo ready' 2>/dev/null" > /dev/null 2>&1; then
        echo "✓ VPS IS READY!"
        echo ""
        echo "VPS Information:"
        sshpass -p "${VPS_PASSWORD}" ssh -o StrictHostKeyChecking=no ${VPS_USER}@${VPS_IP} << 'EOF'
echo "Hostname: $(hostname)"
echo "OS: $(cat /etc/os-release | grep PRETTY_NAME | cut -d'"' -f2)"
echo "Kernel: $(uname -r)"
echo "Uptime: $(uptime -p)"
echo "Disk: $(df -h / | tail -1 | awk '{print $4" free of "$2}')"
echo "Memory: $(free -h | grep Mem | awk '{print $7" free of "$2}')"
EOF
        echo ""
        echo "════════════════════════════════════════════════════════════════"
        echo "  ✓ VPS READY FOR DEPLOYMENT"
        echo "════════════════════════════════════════════════════════════════"
        echo ""
        echo "Next step: Run deployment script"
        echo "  bash /root/deploy-fresh-vps.sh"
        echo ""
        exit 0
    else
        echo "not ready yet"
    fi
    
    sleep 10
    ((attempt++))
done

echo ""
echo "✗ VPS did not become ready after $max_attempts attempts"
echo "Please check:"
echo "  1. VPS reinstall completed successfully"
echo "  2. VPS is actually powered on"
echo "  3. Network connectivity is working"
echo "  4. IP address is correct: ${VPS_IP}"
echo ""
exit 1
