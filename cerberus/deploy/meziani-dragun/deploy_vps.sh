#!/usr/bin/env bash
# Deploy Cerberus binary + Meziani/Dragun roster to remote Debian VPS.

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
RUNTIME_DIR="${RUNTIME_DIR:-${ROOT_DIR}/runtime/cerberus-core}"
DEPLOY_DIR="${ROOT_DIR}/deploy/meziani-dragun"
PEGASUS_COMPAT_DIR="${ROOT_DIR}/deploy/pegasus-compat"

CERBERUS_SSH_HOST="${CERBERUS_SSH_HOST:-}"
CERBERUS_SSH_USER="${CERBERUS_SSH_USER:-root}"
CERBERUS_SSH_PORT="${CERBERUS_SSH_PORT:-22}"
CERBERUS_SSH_KEY_PATH="${CERBERUS_SSH_KEY_PATH:-}"
CERBERUS_SSH_PASSWORD="${CERBERUS_SSH_PASSWORD:-}"
CERBERUS_INSTALL_DIR="${CERBERUS_INSTALL_DIR:-/data/cerberus}"
CERBERUS_GATEWAY_PORT="${CERBERUS_GATEWAY_PORT:-3000}"
CERBERUS_PEGASUS_API_PORT="${CERBERUS_PEGASUS_API_PORT:-8080}"
CERBERUS_ZIG_TARGET="${CERBERUS_ZIG_TARGET:-}"
DRAGUN_PATH="${DRAGUN_PATH:-/data/dragun}"
CERBERUS_SYSTEMD_SERVICE="${CERBERUS_SYSTEMD_SERVICE:-cerberus-gateway}"
CERBERUS_PEGASUS_API_SERVICE="${CERBERUS_PEGASUS_API_SERVICE:-cerberus-pegasus-api}"
CERBERUS_REMOVE_OPENCLAW="${CERBERUS_REMOVE_OPENCLAW:-0}"
CERBERUS_REMOVE_OPENCLAW_USER="${CERBERUS_REMOVE_OPENCLAW_USER:-0}"
OPENCLAW_DATA_DIR="${OPENCLAW_DATA_DIR:-/data/openclaw}"
OPENCLAW_BACKUP_DIR="${OPENCLAW_BACKUP_DIR:-/data/backups}"
PEGASUS_ADMIN_USERNAME="${PEGASUS_ADMIN_USERNAME:-yani}"
PEGASUS_ADMIN_PASSWORD="${PEGASUS_ADMIN_PASSWORD:-cerberus2026}"
CERBERUS_ENABLE_CADDY="${CERBERUS_ENABLE_CADDY:-0}"
CERBERUS_DOMAIN="${CERBERUS_DOMAIN:-}"

info() { printf '\033[0;34m[deploy-vps]\033[0m %s\n' "$*"; }
ok()   { printf '\033[0;32m[deploy-vps]\033[0m %s\n' "$*"; }
die()  { printf '\033[0;31m[deploy-vps]\033[0m %s\n' "$*"; exit 1; }

[[ -n "$CERBERUS_SSH_HOST" ]] || die "Set CERBERUS_SSH_HOST"
[[ -d "$RUNTIME_DIR" ]] || die "Runtime directory not found: $RUNTIME_DIR"
[[ -f "${PEGASUS_COMPAT_DIR}/app.py" ]] || die "Pegasus compat app not found: ${PEGASUS_COMPAT_DIR}/app.py"
[[ -f "${PEGASUS_COMPAT_DIR}/requirements.txt" ]] || die "Pegasus compat requirements not found: ${PEGASUS_COMPAT_DIR}/requirements.txt"
command -v zig >/dev/null 2>&1 || die "zig is required locally"
command -v python3 >/dev/null 2>&1 || die "python3 is required locally"
command -v ssh >/dev/null 2>&1 || die "ssh is required"
command -v scp >/dev/null 2>&1 || die "scp is required"
if [[ -n "$CERBERUS_SSH_KEY_PATH" && ! -f "$CERBERUS_SSH_KEY_PATH" ]]; then
  die "CERBERUS_SSH_KEY_PATH not found: $CERBERUS_SSH_KEY_PATH"
fi
if [[ -n "$CERBERUS_SSH_PASSWORD" ]] && ! command -v sshpass >/dev/null 2>&1; then
  die "sshpass is required when CERBERUS_SSH_PASSWORD is set"
fi

info "Compiling Cerberus runtime"
(
  cd "$RUNTIME_DIR"
  if [[ -n "${CERBERUS_ZIG_TARGET}" ]]; then
    zig build -Doptimize=ReleaseSmall -Dtarget="${CERBERUS_ZIG_TARGET}"
  else
    zig build -Doptimize=ReleaseSmall
  fi
)

bin_src="${RUNTIME_DIR}/zig-out/bin/cerberus"
[[ -x "$bin_src" ]] || die "Compiled binary not found: $bin_src"

generated_config="${DEPLOY_DIR}/config.roster.json"
python3 "$DEPLOY_DIR/generate_roster_config.py" \
  --output "$generated_config" \
  --gateway-host "0.0.0.0" \
  --gateway-port "$CERBERUS_GATEWAY_PORT" \
  --dragun-path "$DRAGUN_PATH" \
  --cerberus-path "$CERBERUS_INSTALL_DIR"

ssh_target="${CERBERUS_SSH_USER}@${CERBERUS_SSH_HOST}"
remote_tmp="/tmp/cerberus-deploy"
SSH_KEY_ARGS=()
if [[ -n "$CERBERUS_SSH_KEY_PATH" ]]; then
  SSH_KEY_ARGS=(-i "$CERBERUS_SSH_KEY_PATH")
fi
SSH_PASS_ARGS=()
if [[ -n "$CERBERUS_SSH_PASSWORD" ]]; then
  export SSHPASS="$CERBERUS_SSH_PASSWORD"
  SSH_PASS_ARGS=(sshpass -e)
fi

info "Uploading artifacts to ${ssh_target}"
"${SSH_PASS_ARGS[@]}" ssh "${SSH_KEY_ARGS[@]}" -o StrictHostKeyChecking=accept-new -o ConnectTimeout=15 -p "$CERBERUS_SSH_PORT" "$ssh_target" "mkdir -p '$remote_tmp'"
"${SSH_PASS_ARGS[@]}" scp "${SSH_KEY_ARGS[@]}" -o StrictHostKeyChecking=accept-new -o ConnectTimeout=15 -P "$CERBERUS_SSH_PORT" "$bin_src" "${ssh_target}:${remote_tmp}/cerberus"
"${SSH_PASS_ARGS[@]}" scp "${SSH_KEY_ARGS[@]}" -o StrictHostKeyChecking=accept-new -o ConnectTimeout=15 -P "$CERBERUS_SSH_PORT" "$generated_config" "${ssh_target}:${remote_tmp}/config.json"
"${SSH_PASS_ARGS[@]}" scp "${SSH_KEY_ARGS[@]}" -o StrictHostKeyChecking=accept-new -o ConnectTimeout=15 -P "$CERBERUS_SSH_PORT" "${PEGASUS_COMPAT_DIR}/app.py" "${ssh_target}:${remote_tmp}/pegasus-compat-app.py"
"${SSH_PASS_ARGS[@]}" scp "${SSH_KEY_ARGS[@]}" -o StrictHostKeyChecking=accept-new -o ConnectTimeout=15 -P "$CERBERUS_SSH_PORT" "${PEGASUS_COMPAT_DIR}/requirements.txt" "${ssh_target}:${remote_tmp}/pegasus-compat-requirements.txt"

info "Installing on remote host"
"${SSH_PASS_ARGS[@]}" ssh "${SSH_KEY_ARGS[@]}" -o StrictHostKeyChecking=accept-new -o ConnectTimeout=15 -p "$CERBERUS_SSH_PORT" "$ssh_target" "CERBERUS_INSTALL_DIR='${CERBERUS_INSTALL_DIR}' CERBERUS_GATEWAY_PORT='${CERBERUS_GATEWAY_PORT}' CERBERUS_PEGASUS_API_PORT='${CERBERUS_PEGASUS_API_PORT}' CERBERUS_SYSTEMD_SERVICE='${CERBERUS_SYSTEMD_SERVICE}' CERBERUS_PEGASUS_API_SERVICE='${CERBERUS_PEGASUS_API_SERVICE}' CERBERUS_REMOVE_OPENCLAW='${CERBERUS_REMOVE_OPENCLAW}' CERBERUS_REMOVE_OPENCLAW_USER='${CERBERUS_REMOVE_OPENCLAW_USER}' OPENCLAW_DATA_DIR='${OPENCLAW_DATA_DIR}' OPENCLAW_BACKUP_DIR='${OPENCLAW_BACKUP_DIR}' PEGASUS_ADMIN_USERNAME='${PEGASUS_ADMIN_USERNAME}' PEGASUS_ADMIN_PASSWORD='${PEGASUS_ADMIN_PASSWORD}' CERBERUS_ENABLE_CADDY='${CERBERUS_ENABLE_CADDY}' CERBERUS_DOMAIN='${CERBERUS_DOMAIN}' REMOTE_TMP='${remote_tmp}' bash -s" <<'EOF'
set -euo pipefail

info() { printf '\033[0;34m[remote]\033[0m %s\n' "$*"; }
ok()   { printf '\033[0;32m[remote]\033[0m %s\n' "$*"; }
warn() { printf '\033[0;33m[remote]\033[0m %s\n' "$*"; }
die()  { printf '\033[0;31m[remote]\033[0m %s\n' "$*"; exit 1; }

install_dir="${CERBERUS_INSTALL_DIR}"
config_dir="${install_dir}/.cerberus"
workspace_dir="${install_dir}/workspace"
gateway_port="${CERBERUS_GATEWAY_PORT}"
api_port="${CERBERUS_PEGASUS_API_PORT}"
tmp_dir="${REMOTE_TMP}"
service_name="${CERBERUS_SYSTEMD_SERVICE}"
api_service_name="${CERBERUS_PEGASUS_API_SERVICE}"
remove_openclaw="${CERBERUS_REMOVE_OPENCLAW}"
remove_openclaw_user="${CERBERUS_REMOVE_OPENCLAW_USER}"
openclaw_data_dir="${OPENCLAW_DATA_DIR}"
openclaw_backup_dir="${OPENCLAW_BACKUP_DIR}"
pegasus_admin_username="${PEGASUS_ADMIN_USERNAME}"
pegasus_admin_password="${PEGASUS_ADMIN_PASSWORD}"
enable_caddy="${CERBERUS_ENABLE_CADDY}"
caddy_domain="${CERBERUS_DOMAIN}"
compat_api_dir="${install_dir}/compat-api"
compat_venv="${install_dir}/compat-venv"
compat_env_file="${install_dir}/config/pegasus-api.env"

SUDO=""
if [[ "$(id -u)" -ne 0 ]]; then
  if command -v sudo >/dev/null 2>&1 && sudo -n true 2>/dev/null; then
    SUDO="sudo -n"
  else
    die "Remote user is not root and passwordless sudo is unavailable."
  fi
fi

if [[ "$remove_openclaw" == "1" ]]; then
  info "Removing OpenClaw stack and data"
  ${SUDO} mkdir -p "${openclaw_backup_dir}"
  if [[ -d "${openclaw_data_dir}" ]]; then
    ts="$(date -u +%Y%m%dT%H%M%SZ)"
    backup_tar="${openclaw_backup_dir}/openclaw-pre-remove-${ts}.tar.gz"
    ${SUDO} tar -C "$(dirname "${openclaw_data_dir}")" -czf "${backup_tar}" "$(basename "${openclaw_data_dir}")"
    ok "Backed up OpenClaw data to ${backup_tar}"
  else
    warn "OpenClaw data directory not found: ${openclaw_data_dir}"
  fi

  for svc in openclaw openclaw-gateway openclaw-orchestrator openclaw-agent-devsecops openclaw-agent-growth; do
    ${SUDO} systemctl disable --now "$svc" >/dev/null 2>&1 || true
  done
  ${SUDO} rm -f /etc/systemd/system/openclaw*.service >/dev/null 2>&1 || true

  for c in openclaw agent-devsecops agent-growth caddy vector uptime-check; do
    ${SUDO} docker rm -f "$c" >/dev/null 2>&1 || true
  done
  ${SUDO} docker network rm openclaw >/dev/null 2>&1 || true
  while IFS= read -r vol; do
    [[ -n "$vol" ]] && ${SUDO} docker volume rm "$vol" >/dev/null 2>&1 || true
  done < <(${SUDO} docker volume ls --format '{{.Name}}' | sed -n '/openclaw/p')

  ${SUDO} rm -rf "${openclaw_data_dir}" >/dev/null 2>&1 || true
  ${SUDO} rm -f /usr/local/bin/openclaw >/dev/null 2>&1 || true
  if [[ "$remove_openclaw_user" == "1" ]] && id openclaw >/dev/null 2>&1; then
    ${SUDO} userdel -r openclaw >/dev/null 2>&1 || true
    ok "Removed openclaw user"
  fi
  ${SUDO} systemctl daemon-reload
  ok "OpenClaw removal complete"
fi

if ! id cerberus >/dev/null 2>&1; then
  ${SUDO} useradd -m -s /bin/bash cerberus
fi
${SUDO} usermod -aG docker cerberus >/dev/null 2>&1 || true

${SUDO} mkdir -p "${install_dir}/config" "${install_dir}/artifacts" "${install_dir}/logs"
${SUDO} mkdir -p "${config_dir}" "${workspace_dir}" "${install_dir}/task-queue" "${install_dir}/hitl-queue/pending" "${install_dir}/hitl-queue/approved" "${install_dir}/hitl-queue/rejected" "${compat_api_dir}"
${SUDO} install -m 0755 "${tmp_dir}/cerberus" /usr/local/bin/cerberus
${SUDO} install -m 0644 "${tmp_dir}/pegasus-compat-app.py" "${compat_api_dir}/app.py"
${SUDO} install -m 0644 "${tmp_dir}/pegasus-compat-requirements.txt" "${compat_api_dir}/requirements.txt"

if ! command -v python3 >/dev/null 2>&1; then
  ${SUDO} apt-get update -qq
  ${SUDO} env DEBIAN_FRONTEND=noninteractive apt-get install -y python3
fi
if [[ ! -x "${compat_venv}/bin/python" ]]; then
  if ! ${SUDO} python3 -m venv "${compat_venv}" >/dev/null 2>&1; then
    py_minor="$(${SUDO} python3 - <<'PY'
import sys
print(f"{sys.version_info.major}.{sys.version_info.minor}")
PY
)"
    ${SUDO} apt-get update -qq
    ${SUDO} env DEBIAN_FRONTEND=noninteractive apt-get install -y "python${py_minor}-venv" python3-venv
    ${SUDO} rm -rf "${compat_venv}"
    ${SUDO} python3 -m venv "${compat_venv}"
  fi
fi
if [[ ! -x "${compat_venv}/bin/pip" ]]; then
  if ! ${SUDO} "${compat_venv}/bin/python" -m ensurepip --upgrade >/dev/null 2>&1; then
    py_minor="$(${SUDO} python3 - <<'PY'
import sys
print(f"{sys.version_info.major}.{sys.version_info.minor}")
PY
)"
    ${SUDO} apt-get update -qq
    ${SUDO} env DEBIAN_FRONTEND=noninteractive apt-get install -y "python${py_minor}-venv" python3-venv
    ${SUDO} rm -rf "${compat_venv}"
    ${SUDO} python3 -m venv "${compat_venv}"
  fi
fi
${SUDO} "${compat_venv}/bin/python" -m pip install --upgrade pip >/dev/null
${SUDO} "${compat_venv}/bin/python" -m pip install -r "${compat_api_dir}/requirements.txt" >/dev/null

${SUDO} tee "${compat_env_file}" >/dev/null <<ENV
CERBERUS_BASE_DIR=${install_dir}
CERBERUS_CONFIG_FILE=${config_dir}/config.json
PEGASUS_ADMIN_USERNAME=${pegasus_admin_username}
PEGASUS_ADMIN_PASSWORD=${pegasus_admin_password}
ENV
${SUDO} chmod 0600 "${compat_env_file}"

if [[ -f "${config_dir}/config.json" ]]; then
  ts="$(date -u +%Y%m%dT%H%M%SZ)"
  ${SUDO} cp "${config_dir}/config.json" "${config_dir}/config.backup.${ts}.json"
  ok "Backed up existing config"
fi

${SUDO} install -m 0644 "${tmp_dir}/config.json" "${config_dir}/config.json"
${SUDO} chown -R cerberus:cerberus "${install_dir}"

${SUDO} tee "/etc/systemd/system/${service_name}.service" >/dev/null <<UNIT
[Unit]
Description=Cerberus Gateway
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
User=cerberus
Group=cerberus
Environment=HOME=${install_dir}
Environment=CERBERUS_WORKSPACE=${workspace_dir}
WorkingDirectory=${install_dir}
ExecStart=/usr/local/bin/cerberus gateway --host 0.0.0.0 --port ${gateway_port}
Restart=always
RestartSec=2
LimitNOFILE=65535

[Install]
WantedBy=multi-user.target
UNIT

${SUDO} tee "/etc/systemd/system/${api_service_name}.service" >/dev/null <<UNIT
[Unit]
Description=Cerberus Pegasus Compatibility API
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
User=cerberus
Group=cerberus
Environment=HOME=${install_dir}
Environment=CERBERUS_WORKSPACE=${workspace_dir}
EnvironmentFile=${compat_env_file}
WorkingDirectory=${compat_api_dir}
ExecStart=${compat_venv}/bin/uvicorn app:app --host 0.0.0.0 --port ${api_port}
Restart=always
RestartSec=2
LimitNOFILE=65535

[Install]
WantedBy=multi-user.target
UNIT

${SUDO} systemctl daemon-reload
${SUDO} systemctl enable --now "${service_name}"
${SUDO} systemctl enable --now "${api_service_name}"
${SUDO} systemctl --no-pager --full status "${service_name}" || true
${SUDO} systemctl --no-pager --full status "${api_service_name}" || true
if ! ${SUDO} systemctl is-active --quiet "${service_name}"; then
  ${SUDO} journalctl --no-pager -u "${service_name}" -n 80 || true
  die "${service_name} failed to start"
fi
if ! ${SUDO} systemctl is-active --quiet "${api_service_name}"; then
  ${SUDO} journalctl --no-pager -u "${api_service_name}" -n 80 || true
  die "${api_service_name} failed to start"
fi
if command -v curl >/dev/null 2>&1; then
  health_ok=0
  for _ in $(seq 1 20); do
    if curl -fsS "http://127.0.0.1:${api_port}/health" >/dev/null; then
      health_ok=1
      break
    fi
    sleep 1
  done
  [[ "${health_ok}" == "1" ]] || die "Pegasus compatibility API health check failed"
  ok "Pegasus compatibility API health check passed"
fi

if [[ "${pegasus_admin_password}" == "cerberus2026" ]]; then
  warn "Pegasus API is using default admin password. Set PEGASUS_ADMIN_PASSWORD and redeploy."
fi

if [[ "${enable_caddy}" == "1" ]]; then
  [[ -n "${caddy_domain}" ]] || die "CERBERUS_DOMAIN is required when CERBERUS_ENABLE_CADDY=1"
  info "Installing Caddy reverse proxy for HTTPS endpoint ${caddy_domain}"
  ${SUDO} apt-get update -qq
  ${SUDO} env DEBIAN_FRONTEND=noninteractive apt-get install -y caddy
  ${SUDO} tee /etc/caddy/Caddyfile >/dev/null <<CADDY
${caddy_domain} {
    encode gzip
    reverse_proxy 127.0.0.1:${api_port}
}
CADDY
  ${SUDO} systemctl enable --now caddy
  ${SUDO} systemctl reload caddy || ${SUDO} systemctl restart caddy
  ok "Caddy configured for ${caddy_domain} -> localhost:${api_port}"
fi

if ! command -v claude >/dev/null 2>&1; then
  warn "Claude CLI not found on VPS. Install it and run 'claude auth login' for claude-cli provider."
fi

ok "Remote deployment complete"
EOF

ok "VPS deployment finished"
