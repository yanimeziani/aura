# Manual Deploy to VPS and Phone Mesh

This runbook is the manual path for a Nexa deployment where:

- the VPS is the always-on mesh anchor,
- the phone is a reconnecting client,
- session state survives app sleep, reconnects, and service restarts,
- deploys remain compatible with `ops/scripts/deploy-mesh.sh`.

The target layout in this repo is:

- gateway on the VPS at `127.0.0.1:8765`
- optional `aura-api` on the VPS at `127.0.0.1:9000`
- public HTTP ingress through nginx with `/gw/*` proxied to the gateway
- shared session state stored on disk under `/opt/aura`

## 1. VPS baseline

Use Debian or Ubuntu with:

```bash
apt-get update
apt-get install -y nginx python3 python3-venv python3-pip rsync curl git
```

Create the runtime root:

```bash
mkdir -p /opt/aura/{gateway,docs,data,logs,scripts,var/aura-api/sessions,var/aura-mesh,vault,.nexa}
chmod 700 /opt/aura/vault
chmod 700 /opt/aura/var/aura-api/sessions
```

If you want the mesh status endpoint to report live state, create:

```bash
cat > /opt/aura/var/aura-mesh/status.json <<'EOF'
{"state":"up","peers":1,"protocol":"noise_ik","handshake":"blake2s_chacha20poly1305","version":"0.1.0"}
EOF
```

## 2. Sync the repo payload to the VPS

From the repo root on your workstation:

```bash
export VPS_IP=your-vps-ip
export VPS_USER=root
export NEXA_REMOTE_ROOT=/opt/aura
rsync -az --delete ops/gateway/ ${VPS_USER}@${VPS_IP}:/opt/aura/gateway/
rsync -az --delete docs/ ${VPS_USER}@${VPS_IP}:/opt/aura/docs/
scp nexa_runtime.py aura_runtime.py ${VPS_USER}@${VPS_IP}:/opt/aura/
scp ops/nginx/nginx.conf ${VPS_USER}@${VPS_IP}:/etc/nginx/nginx.conf
```

If you want the automated path after the first setup, the repo now supports:

```bash
VPS_IP=your-vps-ip ./ops/scripts/deploy-mesh.sh
```

## 3. Install the Python gateway as a persistent service

On the VPS:

```bash
python3 -m venv /opt/aura/.venv
/opt/aura/.venv/bin/pip install --upgrade pip
/opt/aura/.venv/bin/pip install -r /opt/aura/gateway/requirements.txt
```

Create `/etc/systemd/system/aura-gateway.service`:

```ini
[Unit]
Description=Nexa Syncing Gateway
After=network.target

[Service]
Type=simple
WorkingDirectory=/opt/aura
Environment=NEXA_ROOT=/opt/aura
Environment=AURA_ROOT=/opt/aura
Environment=AURA_GATEWAY_PORT=8765
Environment=NEXA_GATEWAY_SESSIONS=/opt/aura/.nexa/gateway_sessions.json
ExecStart=/opt/aura/.venv/bin/python -m uvicorn gateway.app:app --app-dir /opt/aura/gateway --host 0.0.0.0 --port 8765
Restart=always
RestartSec=2

[Install]
WantedBy=multi-user.target
```

Enable it:

```bash
systemctl daemon-reload
systemctl enable --now aura-gateway
systemctl status aura-gateway
```

## 4. Install `aura-api` for file-backed mesh and session persistence

This is the VPS-native API that reads and writes persistent mesh/session data under `/opt/aura`.

```bash
cd /opt/aura
git clone <repo-url> repo || true
cd /opt/aura/repo/core/aura-api
zig build -Doptimize=ReleaseSafe
install -Dm755 zig-out/bin/aura-api /usr/local/bin/aura-api
```

Create `/etc/systemd/system/aura-api.service`:

```ini
[Unit]
Description=Aura API
After=network.target

[Service]
Type=simple
Environment=NEXA_ROOT=/opt/aura
Environment=AURA_ROOT=/opt/aura
Environment=AURA_API_PORT=9000
Environment=NEXA_API_SESSIONS_DIR=/opt/aura/var/aura-api/sessions
Environment=NEXA_MESH_STATUS_FILE=/opt/aura/var/aura-mesh/status.json
Environment=NEXA_VAULT_FILE=/opt/aura/vault/aura-vault.json
ExecStart=/usr/local/bin/aura-api
Restart=always
RestartSec=2

[Install]
WantedBy=multi-user.target
```

Enable it:

```bash
systemctl daemon-reload
systemctl enable --now aura-api
systemctl status aura-api
```

## 5. Put secrets and durable state in the right places

The gateway and `aura-api` are only persistent if state is stored outside the repo checkout.

Use these files:

- vault: `/opt/aura/vault/aura-vault.json`
- gateway session store: `/opt/aura/.nexa/gateway_sessions.json`
- aura-api session directory: `/opt/aura/var/aura-api/sessions/`
- mesh status file: `/opt/aura/var/aura-mesh/status.json`

Minimal vault example:

```json
{
  "AURA_OPERATOR_TOKEN": "replace-me",
  "GROQ_API_KEY": "",
  "GEMINI_API_KEY": ""
}
```

Lock it down:

```bash
chmod 600 /opt/aura/vault/aura-vault.json
chmod 600 /opt/aura/.nexa/gateway_sessions.json 2>/dev/null || true
```

## 6. HTTP ingress

The checked-in nginx config already expects:

- gateway at `127.0.0.1:8765`
- web interface at `127.0.0.1:3003`
- optional Pegasus API at `127.0.0.1:8080`

Validate and reload:

```bash
nginx -t
systemctl reload nginx
```

At minimum, these paths should work:

- `https://your-domain/gw/health`
- `https://your-domain/gw/sync/session/aura`
- `https://your-domain/gw/sync/catch-up?workspace_id=aura`

## 7. Phone sync model

The phone should behave as a stateless client node:

- store only the operator token and current `workspace_id`
- write session updates to `POST /gw/sync/session`
- restore state after sleep/background via `GET /gw/sync/catch-up`
- reconnect live logs or SSE after catch-up succeeds

Minimal session write:

```bash
curl -X POST https://your-domain/gw/sync/session \
  -H 'Content-Type: application/json' \
  -d '{"workspace_id":"aura","payload":{"screen":"ops","draft":"resume deploy","ts":1742083200}}'
```

Restore after the phone wakes up:

```bash
curl https://your-domain/gw/sync/session/aura
curl -H "Authorization: Bearer YOUR_OPERATOR_TOKEN" \
  "https://your-domain/gw/sync/catch-up?workspace_id=aura&n=100"
```

The intended client sequence is:

1. Phone wakes or app resumes.
2. Call `/gw/sync/catch-up`.
3. Restore the last saved session and recent VPS logs.
4. Reattach live streams.

## 8. Persistence contract

For the phone to stay synced and persistent in the mesh, keep these rules:

- Never store canonical session state only on the phone.
- Never store canonical session state only in memory.
- Put `NEXA_ROOT=/opt/aura` on every VPS service.
- Keep `/opt/aura` on persistent disk, not `/tmp` and not inside a transient checkout.
- If you rotate services, restart them without deleting `/opt/aura/.nexa` or `/opt/aura/var`.

## 9. Verification

Run these on the VPS:

```bash
curl -s http://127.0.0.1:8765/health
curl -s http://127.0.0.1:8765/sync/session/aura
curl -s http://127.0.0.1:9000/mesh
curl -s http://127.0.0.1:9000/sync/session/aura
```

Run this from outside:

```bash
MESH_VPS_IP=your-vps-ip VPS_DOMAIN=your-domain ./ops/scripts/smoke-test-mesh.sh
```

Then test persistence:

1. `POST /gw/sync/session` with a known payload.
2. Restart `aura-gateway`.
3. `GET /gw/sync/session/{workspace_id}` and confirm the payload survived.
4. Put the phone app in the background, reopen it, call `/gw/sync/catch-up`, and confirm the UI restores without manual repair.
