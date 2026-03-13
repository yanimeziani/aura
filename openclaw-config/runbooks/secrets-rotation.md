# Runbook: Secrets Rotation

**Owner:** DevSecOps Agent
**HITL Required:** Always — CRITICAL gate
**Frequency:** On exposure detection, or quarterly proactive rotation

---

## Triggers

- Gitleaks detects a potential secret in a diff
- Secret accidentally committed to repo (even if "deleted" from history)
- Team member offboarding
- Scheduled quarterly rotation
- Third-party service breach notification

## Pre-rotation (agent prepares, Yani approves)

1. Inventory all affected secrets:
   ```
   - ANTHROPIC_API_KEY
   - GITHUB_TOKEN
   - ALERT_WEBHOOK_URL
   - DATABASE_URL (if applicable)
   - Any other .env entries
   ```

2. For each secret, identify:
   - Where it's stored (VPS .env, CI secrets, etc.)
   - Which services use it
   - Downtime impact of rotation

3. Issue HITL_REQUEST with full inventory and rotation plan.

## Rotation procedure (after HITL approval)

### Anthropic API key

```bash
# 1. Generate new key at console.anthropic.com
# 2. Update VPS .env (do NOT log the key value)
ssh openclaw@vps "nano /data/openclaw/docker/.env"
# Edit ANTHROPIC_API_KEY=<new key>

# 3. Restart services
ssh openclaw@vps "cd /data/openclaw/docker && docker compose restart openclaw agent-devsecops agent-growth"

# 4. Verify
ssh openclaw@vps "docker logs openclaw --tail=20 | grep -i 'api\|auth\|key'"

# 5. Revoke old key at console.anthropic.com (HITL: remind Yani to do this manually)
```

### GitHub token

```bash
# 1. Generate new token at github.com/settings/tokens
# 2. Update VPS .env: GITHUB_TOKEN=<new>
# 3. Test: git ls-remote using new token
# 4. Revoke old token on GitHub (manual)
```

## Post-rotation

1. Run gitleaks on full repo to confirm no lingering exposure:
   ```bash
   docker run --rm -v /data/dragun/repos/dragun-app:/repo \
     zricethezav/gitleaks detect --source /repo
   ```
2. Write artifact: `ops/logs/devsecops/secrets_rotation_<date>.md` (NO secret values — list only key names rotated)
3. Alert: `[SECRETS] Rotation complete — N keys rotated`

## Emergency: Secret Exposed in Public Repo

**This is P1. Act immediately.**

1. Alert Yani: call, don't wait for queue
2. Revoke the secret at the provider **immediately** (GitHub, Anthropic, etc.)
3. Generate replacement
4. Audit git history: `git log --all -S "<partial_secret>" --oneline`
5. If truly public, assume compromised — rotate everything in same .env
6. Do NOT attempt to rewrite git history on shared branches without explicit approval
7. File incident report
