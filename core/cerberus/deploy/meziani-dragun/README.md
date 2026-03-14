# Meziani + Dragun Roster Deployment

This bundle deploys a Cerberus roster with:

- `meziani-main` - primary virtual assistant
- `dragun-devsecops` - spec-driven DevSecOps specialist
- `dragun-growth` - growth hacking and GenAI automation specialist

## Files

- `prompts/` - roster system prompts
- `generate_roster_config.py` - renders `config.roster.json` from prompts
- `deploy_local.sh` - installs binary + config on current machine
- `deploy_vps.sh` - installs binary + config + systemd service on remote Debian VPS

## Local Deploy

```bash
cd /root/cerberus
bash deploy/meziani-dragun/deploy_local.sh
```

## VPS Deploy

Set required env vars and run:

```bash
export CERBERUS_SSH_HOST="your-vps-host"
export CERBERUS_SSH_USER="root"
export CERBERUS_SSH_PORT="22"
export CERBERUS_SSH_KEY_PATH="/path/to/private_key"
bash /root/cerberus/deploy/meziani-dragun/deploy_vps.sh
```

Optional:

- `CERBERUS_INSTALL_DIR` (default `/data/cerberus`)
- `CERBERUS_GATEWAY_PORT` (default `3000`)
- `DRAGUN_PATH` (default `/data/dragun`)
- `CERBERUS_SYSTEMD_SERVICE` (default `cerberus-gateway`)

### Legacy OpenClaw Removal + Cerberus Replacement

Set:

- `CERBERUS_REMOVE_OPENCLAW=1` to back up and remove OpenClaw data/containers/services.
- `CERBERUS_REMOVE_OPENCLAW_USER=1` to also remove the `openclaw` Linux user (optional).

Example:

```bash
export CERBERUS_SSH_HOST="your-vps-host"
export CERBERUS_SSH_USER="root"
export CERBERUS_SSH_KEY_PATH="/path/to/private_key"
export CERBERUS_REMOVE_OPENCLAW=1
bash /root/cerberus/deploy/meziani-dragun/deploy_vps.sh
```

## Notes

- Claude Pro runtime path uses `claude-cli` provider and expects `claude` CLI auth to be present on host.
- MCP GitHub server expects `GITHUB_TOKEN` environment variable on the runtime host.
