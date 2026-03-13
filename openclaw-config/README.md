# openclaw-config [DEPRECATED]

> **This project has been superseded by Cerberus + Pegasus.**
>
> All policies, runbooks, and governance configs have been migrated to:
> - **Policies:** `/cerberus/policies/` (cost-caps, HITL gates, model routing, risk labels)
> - **Runbooks:** `/cerberus/runbooks/` (deploy, rollback, incident response, secrets rotation, panic mode)
> - **API/Orchestrator:** `/cerberus/deploy/pegasus-compat/` (Pegasus API replaces the OpenClaw orchestrator)
> - **Control Plane:** `/pegasus/` (Android app replaces Termux TUI cockpit)
>
> **Do not add new features here.** This directory is kept for reference only.

---

## Migration Guide

### What moved where

| openclaw-config | New location | Notes |
|-----------------|-------------|-------|
| `policies/*.yaml` | `cerberus/policies/*.yaml` | Rebranded from OpenClaw to Cerberus/Pegasus |
| `runbooks/*.md` | `cerberus/runbooks/*.md` | Commands updated from `openclaw` to `cerberus` |
| `docker/orchestrator/main.py` | `cerberus/deploy/pegasus-compat/app.py` | Full REST/WS API for Pegasus |
| `docker/docker-compose.yml` | `cerberus/runtime/cerberus-core/docker-compose.yml` | Cerberus-native Docker config |
| `scripts/termux/cockpit.sh` | Replaced by Pegasus Android app | `pegasus/` |
| `bin/openclaw` | `cerberus` CLI binary (Zig) | Native CLI replaces bash wrapper |
| `agents/*/config.yaml` | `cerberus/configs/*.json` | Agent configs in Cerberus-native format |

### Key changes

1. **CLI:** `openclaw approve <id>` is now `cerberus approve <id>` or approve via Pegasus app HITL screen
2. **API:** Token prefix changed from `oc_` to `crb_`
3. **Default password:** Changed from `openclaw2026` to `cerberus2026`
4. **Data path:** `/data/openclaw` is now `/data/cerberus`
5. **Control plane:** Termux TUI replaced by Pegasus Android app with Material 3 UI
