# Runbook: Rollback

**Owner:** DevSecOps Agent
**Scope:** Dragun.app production
**HITL Required:** Yes (production rollback)

---

## When to trigger

- Health check fails after deploy (>3 consecutive failures)
- Error rate spikes >5x baseline within 10min of deploy
- P1 incident directly caused by recent deploy
- Manual trigger from Yani: `cerberus task rollback --sha <previous_sha>`

## Pre-rollback (agent auto-runs)

1. Identify last known-good SHA:
   ```bash
   cd /data/dragun/repos/dragun-app
   git log --oneline -10   # find last stable tag or SHA
   ```
2. Confirm backup availability (see backup section)
3. Issue HITL_REQUEST with:
   - current SHA
   - rollback target SHA
   - reason
   - estimated downtime

## Rollback steps (after HITL approval)

```bash
cd /data/dragun/repos/dragun-app

# Option A: image rollback (preferred — zero downtime if image exists)
PREV_SHA="<previous_sha>"
docker compose -f docker-compose.prod.yml stop app
docker tag dragun-app:$PREV_SHA dragun-app:current
docker compose -f docker-compose.prod.yml up -d app

# Option B: git rollback + rebuild (if image not cached)
git checkout $PREV_SHA
docker compose -f docker-compose.prod.yml build app
docker compose -f docker-compose.prod.yml up -d --remove-orphans app
```

## Post-rollback

```bash
# Verify health
curl -sf https://dragun.app/health | jq .

# Check error rate in logs
docker logs dragun-app --tail=50 | grep -c ERROR
```

1. Write artifact: `ops/logs/devsecops/rollback_<timestamp>.md` with:
   - rolled back from / to SHA
   - trigger reason
   - HITL approval ID
   - time to recover
2. Alert: `[ROLLBACK] dragun.app rolled back to <sha>`
3. Open incident report (see `runbooks/incident-response.md`)

## If rollback also fails

1. Immediately alert Yani (P1)
2. Take app offline if data integrity at risk
3. Do not attempt further automated changes
4. Wait for manual intervention
