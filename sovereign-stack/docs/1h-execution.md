# 1-hour execution: top-level tasks

One-time execution of the main desk items. Completed in one pass.

## Scope (5 tasks)

| # | Task | Status |
|---|------|--------|
| 1 | VPS readiness: confirm repo path + SSH | Done. SSH works via `./run rx`. Repo not at `/root/aura-stack` yet; first-time clone step added to DEPLOYMENT.md. |
| 2 | Launch-remote (./run lr) | Blocked until repo cloned on VPS at VPS_REPO_PATH. Doc updated. |
| 3 | API: systemd unit for host payment API | Done. `payment-api.service.example` added; DEPLOYMENT.md § Payment API added. |
| 4 | Backups: postgres + n8n schedule | Done. DEPLOYMENT.md § Backups added (commands + schedule note). |
| 5 | Hardening checklist | Done. API, Backups, TLS items checked; checklist current. |

## Artifacts

- `sovereign-stack/payment-api.service.example` — systemd unit for payment API on port 8000.
- `sovereign-stack/DEPLOYMENT.md` — first-time VPS setup (clone), Payment API section, Backups section, hardening checklist updated.

## Next (when ready)

- Clone repo on VPS: `./run rx "git clone https://github.com/yanimeziani/aura-stack.git /root/aura-stack"`.
- Ensure sovereign-stack/.env and TLS cert/key on VPS, then `./run lr`.
