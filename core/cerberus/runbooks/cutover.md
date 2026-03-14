# Cerberus Cutover Runbook

## 0) Preconditions

- SSH key access to VPS confirmed.
- OpenClaw stack currently healthy enough to export config assets.
- Cerberus private repo exists and is reachable from VPS.

## 1) Export Preservation Bundle

Run on VPS:

```bash
bash /path/to/cerberus/scripts/export_openclaw_context.sh
```

Expected outputs:

- `/data/cerberus/bootstrap/cerberus-context-<ts>/`
- `/data/cerberus/bootstrap/cerberus-context-<ts>.tar.gz`

## 2) Prepare Cerberus Runtime Directories

Run on VPS:

```bash
sudo bash /path/to/cerberus/scripts/prepare_cerberus_vps.sh
```

Optional wipe mode (only after backup verification):

```bash
sudo CERBERUS_CONFIRM_WIPE=YES bash /path/to/cerberus/scripts/prepare_cerberus_vps.sh --wipe-legacy
```

## 3) Clone Cerberus Repo

```bash
sudo -u cerberus git clone git@github.com:<your-org>/cerberus.git /data/cerberus/config
```

## 4) Import Preserved Agent Assets

- Copy prompts, policies, and MCP config from latest snapshot into Cerberus config tree.
- Validate paths reference `/data/cerberus`.

## 5) Claude Pro Runtime Validation

- Confirm host has authenticated Claude CLI state.
- Confirm container runtime can read mounted auth directory.
- Confirm Cerberus runtime sets `CLAUDE_SKIP_AUTO_UPDATE=1`.

## 6) Smoke Tests

- Health endpoint returns `200`.
- Auth login works.
- Submit one `devsecops` task and one `growth` task.
- HITL submit/approve/reject flow works.
- Artifact files appear under `/data/cerberus/artifacts`.

## 7) Post-Cutover Observation

- Monitor 24h logs.
- Verify cost cap and panic behavior.
- Keep OpenClaw backup tarball until explicit sign-off.
