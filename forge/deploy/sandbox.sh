#!/bin/bash
# Forge Public Demo Sandbox — Isolated execution environment
set -euo pipefail

# Sandbox config
SANDBOX_USER="sandbox"
SANDBOX_HOME="/home/sandbox"
SANDBOX_TIMEOUT=10
SANDBOX_MEM_LIMIT="128M"

echo "=== Setting up Forge Demo Sandbox ==="

# Create isolated sandbox user
useradd -m -s /bin/rbash "${SANDBOX_USER}" || true

# Restricted environment
mkdir -p "${SANDBOX_HOME}/bin"
ln -sf /home/forge/app/zig-out/bin/forge "${SANDBOX_HOME}/bin/forge" || true

# Sandbox execution wrapper
cat > /usr/local/bin/forge-sandbox << 'WRAPPER'
#!/bin/bash
# Sandboxed Forge execution
set -euo pipefail

TIMEOUT=10
MEM_LIMIT=134217728  # 128MB

# Create temp workspace
WORKDIR=$(mktemp -d)
trap "rm -rf ${WORKDIR}" EXIT

# Copy input to workspace
cat > "${WORKDIR}/input.frg"

# Run with limits
cd "${WORKDIR}"
timeout "${TIMEOUT}" \
    systemd-run --scope \
    -p MemoryMax="${MEM_LIMIT}" \
    -p CPUQuota=50% \
    --user \
    /home/forge/app/zig-out/bin/forge input.frg 2>&1 || echo "Execution limited"
WRAPPER

chmod +x /usr/local/bin/forge-sandbox

echo "=== Sandbox Ready ==="
echo "Usage: echo 'code' | forge-sandbox"
