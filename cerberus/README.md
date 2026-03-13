# Cerberus

Cerberus is the Zig-based autonomous AI assistant runtime, derived from a private fork of Null Claw. Pegasus is the control plane and mission control UX.

This workspace is set up for spec-driven development (SDD). The project replaces the legacy OpenClaw stack.

## Architecture

- **Cerberus** — the Zig runtime (task execution, agent orchestration, MCP, cost/HITL enforcement).
- **Pegasus** — the control plane and mission control UX (dashboard, approvals, live monitoring, steer).
- Agent topology: `devsecops`, `growth` (plus `meziani-main` orchestrator).
- Claude Pro (`claude` CLI OAuth) as the LM provider path.
- VPS runtime with clean deployment and rollback safety.

## Current Scope

- Specs live in `specs/`.
- Migration scripts live in `scripts/`.
- Legacy OpenClaw assets were imported through scripted snapshots, not manual copy/paste.

## Initial Deliverables

1. Platform spec and acceptance criteria.
2. Agent contract spec (prompt + MCP + cost/HITL behavior).
3. VPS cutover spec and runbook.
4. Scripts to export legacy assets and stage Cerberus cutover.
5. NullClaw -> Cerberus bootstrap refactor and rebrand automation.

## NullClaw Refactor Bootstrap

Use the scripted flow to generate a rebranded Cerberus runtime tree from upstream NullClaw:

```bash
# Create or refresh runtime/cerberus-core from upstream snapshot
bash scripts/bootstrap_nullclaw_refactor.sh --refresh-upstream

# Verify naming + compatibility checks
bash scripts/verify_rebrand_integrity.sh
```

Output tree:

- `runtime/cerberus-core/` - rebranded runtime codebase
- `runtime/cerberus-core/UPSTREAM.md` - pinned upstream source metadata
- `runtime/cerberus-core/reports/branding-audit.txt` - residual token report

## Meziani + Dragun Roster Deploy

Deployment bundle:

- `deploy/meziani-dragun/`

Run local compile + deploy:

```bash
bash deploy/meziani-dragun/deploy_local.sh
```

Run VPS deployment (after setting SSH env vars):

```bash
bash deploy/meziani-dragun/deploy_vps.sh
```

Pegasus compatibility is installed by default during VPS deploy:

- Pegasus-compatible REST API is exposed via `cerberus-pegasus-api` (default port `8080`).
- API contract matches Pegasus Kotlin client endpoints (`/auth/*`, `/health`, `/agents`, `/hitl/*`, `/costs/*`, `/panic`, `/tasks/*`).
- Default login remains `yani / cerberus2026` unless overridden.

Useful deployment environment overrides:

```bash
# Pegasus API service + credentials
export CERBERUS_PEGASUS_API_PORT=8080
export CERBERUS_PEGASUS_API_SERVICE=cerberus-pegasus-api
export PEGASUS_ADMIN_USERNAME=yani
export PEGASUS_ADMIN_PASSWORD='change-me-now'

# Optional HTTPS frontdoor for Pegasus app
export CERBERUS_ENABLE_CADDY=1
export CERBERUS_DOMAIN=ops.meziani.org
```

## Notes

- No destructive action should run without explicit wipe confirmation.
- Secrets are never written to migration artifacts.
