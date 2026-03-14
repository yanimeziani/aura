# Spec 005 - Meziani + Dragun Roster Deployment

## Status

In Progress

## Objective

Compile Cerberus and deploy a production-ready internal roster:

- `meziani-main` virtual assistant (primary orchestrator)
- `dragun-devsecops` specialist (spec-driven infra/security)
- `dragun-growth` specialist (growth hacking + GenAI automation)

## Requirements

1. Cerberus binary builds with Zig 0.15.2.
2. Roster config is generated from maintainable prompt files.
3. Default provider path uses Claude Pro via `claude-cli`.
4. MCP stack mirrors prior capabilities (github/filesystem/fetch/memory/sequential-thinking).
5. Gateway starts cleanly and health endpoint returns `200`.
6. VPS deployment path exists (binary + config + systemd service).

## Implementation

- Local compile and deploy script:
  - `deploy/meziani-dragun/deploy_local.sh`
- VPS deploy script:
  - `deploy/meziani-dragun/deploy_vps.sh`
- Config generator:
  - `deploy/meziani-dragun/generate_roster_config.py`
- Prompt packs:
  - `deploy/meziani-dragun/prompts/*.md`

## Acceptance Evidence

- `zig build -Doptimize=ReleaseSmall` succeeds.
- `cerberus status` reports provider/model + cost/scheduler settings.
- Gateway startup logs show 3 configured agents.
- `curl http://127.0.0.1:3000/health` returns `{"status":"ok"}`.

## Open Items

- Validate Claude CLI login state on target VPS (`claude auth login` if needed).
- Configure channel accounts (Telegram/Web/etc.) before external routing cutover.
