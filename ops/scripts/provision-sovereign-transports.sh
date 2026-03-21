#!/usr/bin/env bash
set -euo pipefail

if [[ "${EUID:-$(id -u)}" -ne 0 ]]; then
  echo "[transport] Run as root." >&2
  exit 1
fi

INSTALL_TOR="${INSTALL_TOR:-1}"
INSTALL_IPFS="${INSTALL_IPFS:-1}"
KUBO_VERSION="${KUBO_VERSION:-v0.32.1}"
KUBO_ARCHIVE="kubo_${KUBO_VERSION}_linux-amd64.tar.gz"
KUBO_URL="${KUBO_URL:-https://dist.ipfs.tech/kubo/${KUBO_VERSION}/${KUBO_ARCHIVE}}"
IPFS_USER="${IPFS_USER:-ipfs}"
IPFS_HOME="${IPFS_HOME:-/var/lib/ipfs}"
TOR_SERVICE="${TOR_SERVICE:-tor}"
IPFS_SERVICE="${IPFS_SERVICE:-ipfs}"

export DEBIAN_FRONTEND=noninteractive

apt-get update -y
apt-get install -y curl tar ca-certificates gnupg lsb-release

if [[ "$INSTALL_TOR" == "1" ]]; then
  apt-get install -y tor
  systemctl enable --now "$TOR_SERVICE"
  echo "[transport] Tor enabled on socks5://127.0.0.1:9050"
fi

if [[ "$INSTALL_IPFS" == "1" ]]; then
  tmp_dir="$(mktemp -d)"
  trap 'rm -rf "$tmp_dir"' EXIT
  curl -fsSL "$KUBO_URL" -o "$tmp_dir/$KUBO_ARCHIVE"
  tar -xzf "$tmp_dir/$KUBO_ARCHIVE" -C "$tmp_dir"
  install -m 0755 "$tmp_dir/kubo/ipfs" /usr/local/bin/ipfs

  if ! id "$IPFS_USER" >/dev/null 2>&1; then
    useradd --system --home "$IPFS_HOME" --create-home --shell /usr/sbin/nologin "$IPFS_USER"
  fi

  mkdir -p "$IPFS_HOME"
  chown -R "$IPFS_USER:$IPFS_USER" "$IPFS_HOME"

  if [[ ! -f "$IPFS_HOME/config" ]]; then
    su -s /bin/bash "$IPFS_USER" -c "export IPFS_PATH='$IPFS_HOME'; ipfs init --profile server"
  fi

  cat > /etc/systemd/system/${IPFS_SERVICE}.service <<EOF
[Unit]
Description=IPFS daemon
After=network.target

[Service]
User=${IPFS_USER}
Group=${IPFS_USER}
Environment=IPFS_PATH=${IPFS_HOME}
ExecStart=/usr/local/bin/ipfs daemon --enable-gc
Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF

  systemctl daemon-reload
  systemctl enable --now "$IPFS_SERVICE"
  echo "[transport] IPFS enabled at http://127.0.0.1:5001 and http://127.0.0.1:8080"
fi

cat <<'EOF'
[transport] Export these for Aura:
  AURA_ROUTE_CLOUD_THROUGH_TOR=1
  AURA_TOR_SOCKS_URL=socks5://127.0.0.1:9050
  AURA_TOR_CONTROL_HOST=127.0.0.1
  AURA_TOR_CONTROL_PORT=9051
  AURA_TOR_CONTROL_PASSWORD=...
  AURA_IPFS_API_URL=http://127.0.0.1:5001
  AURA_IPFS_GATEWAY_URL=http://127.0.0.1:8080
EOF
