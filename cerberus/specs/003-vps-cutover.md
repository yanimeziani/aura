# Spec 003 - VPS Cutover (OpenClaw -> Cerberus)

## Status

Draft

## Objective

Replace OpenClaw services on Debian VPS with Cerberus while preserving prompts, MCP config, policies, and agent behavior artifacts.

## Constraints

- Destructive wipe is optional, not default.
- Recovery path must exist before any destructive step.
- Secrets are never exported into plain migration bundles.

## Cutover Phases

1. **Snapshot**
   - Export non-secret OpenClaw assets (agents, prompts, MCP, policies, runbooks).
   - Capture runtime metadata (container list, compose config, health endpoints).
2. **Stage**
   - Prepare `/data/cerberus` directory structure.
   - Import preserved assets into Cerberus config tree.
   - Validate Claude auth mount and MCP server startup.
3. **Switch**
   - Stop OpenClaw stack.
   - Start Cerberus stack.
   - Run smoke tests (`/health`, auth login, one task per agent).
4. **Stabilize**
   - Observe 24h logs and cost behavior.
   - Keep rollback package available until sign-off.

## Optional Wipe Mode

If wipe is requested:

- Remove OpenClaw containers and networks.
- Archive `/data/openclaw` before removal.
- Keep SSH hardening and base OS controls.

## Acceptance Criteria

- Cerberus health endpoint stable for 30 minutes.
- Pegasus (or replacement client) can authenticate successfully.
- HITL queue functions (submit, approve, reject).
- DevSecOps and Growth tasks both produce artifacts.
