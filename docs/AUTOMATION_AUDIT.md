# Aura architecture: automation audit

**Goal:** No operation should require more than three taps on screen; no routine task should depend on manual execution. Everything should be automatable, maintainable, and resilient over the network.

---

## 1. Actions that exceed three taps or are multi-step

| Flow | Current taps/steps | Issue |
|------|--------------------|--------|
| **Login** | Open app → Enter token → Submit | 3 taps (at limit). Token re-entry after rotation is manual on every device. |
| **View Leads** | Quick Actions → View Leads | 2 taps. OK. |
| **Export Logs** | Quick Actions → Export Logs (opens new tab) | 2 taps. OK. |
| **Planetary Globe** | Quick Actions → Planetary Outreach → (optional) Refresh | 2–3 taps. OK. |
| **Switch log tab** | Agent Terminal → tap another tab | 1 tap per switch. Seven tabs = many taps to scan. | Consider a single “all logs” view or default to most-used. |
| **Deploy mesh** | Run `./ops/scripts/deploy-mesh.sh` from laptop (or push to main for CI) | Not in UI; manual run or git push. |
| **Run backup** | SSH to VPS, run backup script, or rely on deploy | Manual / only during deploy. |
| **Rotate vault token** | Run vault_manager rotate-token → restart gateway → re-enter token on phone/dashboard | Multi-step, multi-device. |
| **Restart gateway/dashboard** | SSH + systemctl restart | Manual. |
| **Sync config** | Run `ops/scripts/sync-client.sh` from laptop | Manual. |
| **See where backups go** | No UI; call API or read backup-nodes.json | Not visible in operator UI. |

---

## 2. Tasks executed manually on a regular basis

| Task | Frequency | Current automation | Gap |
|------|-----------|---------------------|-----|
| **Deploy mesh** | On code change | GitHub Actions on push to main (ops/dashboard/landing paths) or workflow_dispatch | No one-tap from dashboard; manual trigger or push. |
| **Backup dynamic files** | On deploy only | Runs inside deploy-mesh.sh | No scheduled backup; no “backup now” from UI. |
| **Health check** | Continuous | Dashboard polls every 30s (health), 60s (providers, models, regions) | No auto-remediation; only display. |
| **Vault token rotation** | When needed | Fully manual: script + restart + re-login everywhere | No single “rotate and apply” path. |
| **Gateway/dashboard restart** | After config or token change | systemctl on VPS | No API or UI trigger. |
| **Config sync (roster, prompts)** | When config changes | `ops/scripts/sync-client.sh` | Manual run. |
| **Smoke test** | After deploy | GitHub Actions runs smoke-test-mesh.sh | OK. No re-run from UI. |
| **Backup routing** | Per backup | Script picks largest node; no schedule | Backups only on deploy unless script run manually. |

---

## 3. Resilience gaps (network / failure)

| Area | Current behaviour | Gap |
|------|-------------------|-----|
| **Dashboard API calls** | Single attempt; catch → show offline/empty | No retry with backoff; one blip marks everything offline. |
| **Agent Terminal SSE** | onerror sets “retrying” text; reconnect only on tab change or visibility catch-up | No automatic SSE reconnect after disconnect. |
| **Gateway** | No self-restart on crash | Depends on systemd; no in-process watchdog. |
| **Backup rsync** | Single attempt to “largest” node | No retry or fallback to next node. |
| **Login** | Single validateToken request | No retry; “GATEWAY_UNREACHABLE” on first failure. |

---

## 4. Target state (automated, maintainable, resilient)

- **≤3 taps:** Every operator action completable in ≤3 taps from operator UI (or equivalent).
- **Routine tasks:** Deploy, backup, health, token rotation have a one-tap or zero-tap path (API + optional UI), and scheduled backup where appropriate.
- **Resilience:** Retries with backoff for API calls; SSE auto-reconnect; backup tries next node on failure; gateway restarts via systemd (documented).

Concrete measures:

1. **Dashboard resilience:** Retry fetch for health, providers, models, regions (e.g. 3 attempts with backoff). Agent Terminal: reconnect SSE after disconnect with exponential backoff (e.g. 2s, 4s, 8s, cap 60s).
2. **One-tap from operator UI:** “Run backup now” (calls gateway API that runs backup script on server). “Deploy mesh” (gateway calls GitHub Actions workflow_dispatch). “Where do backups go?” (existing GET /api/backup/nodes shown in UI).
3. **Scheduled backup:** Cron or systemd timer on VPS to run backup-dynamic-then-delete.sh daily (or configurable), with backup routed to largest node.
4. **Token rotation:** Optional gateway endpoint POST /api/vault/rotate-token (vault auth) that rotates token, syncs envs, and returns new token so one client can update; dashboard can offer “Rotate token” and store new token (still requires gateway restart via systemd or future API).
5. **Documentation:** Keep this audit updated as flows change; document cron/timer and env vars in deployment guide.

---

## 5. File / component map (for maintainability)

| Concern | Location |
|---------|----------|
| Deploy mesh | `ops/scripts/deploy-mesh.sh`, `.github/workflows/deploy-mesh.yml` |
| Backup + route to largest node | `ops/scripts/backup-dynamic-then-delete.sh`, `vault/backup-nodes.json` |
| Gateway APIs | `ops/gateway/app.py` |
| Operator UI | `apps/aura-dashboard/src/` |
| Vault + token rotation | `vault/vault_manager.py` |
| Catch-up (phone back) | `GET /sync/catch-up`, dashboard visibility handler |
| Backup nodes API | `GET /api/backup/nodes` |
