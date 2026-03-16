# Automation Priority 50

This is the current highest-value list of full-auto tasks for Aura, grounded in the repo's existing CLI, deploy scripts, gateway APIs, operator UI dashboard, and CI workflows.

Status key:
- `Live`: already automated in the repo today.
- `Partial`: some automation exists, but the operator still has to bridge gaps manually.
- `Next`: the task is the next obvious automation target based on current docs and code.

## 1. Core operator commands

1. `Live` — `aura demo`: start gateway plus local operator UI for an local demo.
2. `Live` — `aura gateway`: start the FastAPI syncing gateway on the documented port.
3. `Live` — `aura deploy-mesh`: back up the VPS, sync docs, deploy gateway, dashboard, and landing.
4. `Live` — `aura backup`: run the dynamic backup and cleanup script locally.
5. `Live` — `AURA_REMOTE=1 aura backup`: trigger the same backup script on the VPS.
6. `Live` — `aura smoke-test`: verify gateway, dashboard, and landing externally.
7. `Live` — `aura docs-bundle`: generate the NotebookLM-safe documentation bundle.
8. `Live` — `aura status`: perform a lightweight local health check.
9. `Partial` — `aura vault`: bootstrap secrets and operator token, but the first run is still manual.
10. `Partial` — `aura vault sync`: propagate vault values into env targets after bootstrap.

## 2. CI and deployment pipeline

11. `Live` — GitHub Actions deploy mesh on `main` changes under `ops/**`, dashboard, or landing.
12. `Live` — GitHub Actions smoke-test immediately after deploy and fail the pipeline on breakage.
13. `Live` — `deploy-mesh.sh` performs a backup on the target VPS before changing runtime assets.
14. `Live` — `deploy-mesh.sh` syncs `docs/` and `docs/updates/` so `GET /docs/aura` stays current.
15. `Live` — `deploy-mesh.sh` syncs the gateway app to `/opt/aura/gateway/app.py`.
16. `Live` — `deploy-mesh.sh` syncs the nginx config to the VPS.
17. `Live` — `deploy-mesh.sh` validates nginx and reloads it before finishing.
18. `Live` — `deploy-mesh.sh` syncs the dashboard source and builds it on the VPS.
19. `Live` — `deploy-mesh.sh` restarts the dashboard service after the build.
20. `Live` — `deploy-mesh.sh` syncs the landing source and publishes the generated site.

## 3. Gateway automation surface

21. `Live` — `GET /health`: liveness probe for local and remote automation.
22. `Live` — `GET /health/services`: service availability probe across gateway-adjacent ports.
23. `Live` — `GET /providers`: provider discovery for operator UI and other clients.
24. `Live` — `GET /v1/models`: unified model discovery with mesh-first ordering.
25. `Live` — `POST /api/validate-token`: dashboard login validation against the vault token.
26. `Live` — `GET /docs/aura`: on-demand public/operator docs bundle built from curated docs plus `docs/updates/`.
27. `Live` — `POST /telemetry/visit`: automatically record locale/country landing traffic.
28. `Live` — `GET /telemetry/regions`: aggregate telemetry for operator UI region clusters.
29. `Live` — `POST /sync/session`: write shared context for IDE, TUI, and CLI continuity.
30. `Live` — `GET /sync/session/{workspace_id}`: restore shared workspace context.

## 4. HITL and continuity

31. `Live` — `DELETE /sync/session/{workspace_id}` with HITL confirmation for destructive session clears.
32. `Live` — `GET /api/hitl/actions`: discover the actions that require operator confirmation.
33. `Live` — `GET /sync/catch-up`: restore recent state after phone/background interruptions.
34. `Partial` — dashboard login is automated, but token rotation still forces manual re-entry across clients.
35. `Next` — one-tap “rotate token and apply” flow from operator UI using a gated gateway endpoint.
36. `Next` — one-tap “restart gateway/dashboard” operator action exposed through the gateway with HITL.

## 5. Dashboard and operator UX

37. `Live` — operator UI polls health and provider/model/region data without operator SSH.
38. `Partial` — Agent Terminal surfaces retry state, but SSE reconnect is not fully automatic.
39. `Next` — automatic SSE reconnect with exponential backoff after disconnect.
40. `Next` — retry with backoff for health, providers, models, and regions so transient faults do not flip the UI offline.
41. `Next` — “Run backup now” button in operator UI calling the server-side backup path.
42. `Next` — “Deploy mesh” button in operator UI triggering the GitHub Actions workflow dispatch path.
43. `Next` — “Backup destinations” panel in operator UI using the existing backup nodes API surface.
44. `Next` — consolidated “all logs” terminal view to reduce multi-tab scan overhead.

## 6. Scheduled and resilience automation

45. `Partial` — backups run automatically during deploy, but not yet on a schedule.
46. `Next` — daily systemd timer or cron for `backup-dynamic-then-delete.sh` on the VPS.
47. `Next` — backup retry and fallback across multiple backup nodes instead of a single best-choice attempt.
48. `Next` — automatic post-deploy rollback or halt when dashboard or landing build fails on the VPS.
49. `Next` — auto-remediation hooks for unhealthy services detected by gateway health probes.
50. `Next` — one-command or zero-command config sync for roster, prompts, and client state after changes.

## Operational reading

If only a few operator actions get prioritized next, the sequence should be:
1. operator UI-triggered backup.
2. operator UI-triggered deploy.
3. Scheduled VPS backups.
4. SSE and fetch retry resilience.
5. Token rotation without manual re-login across every client.
