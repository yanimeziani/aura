# Runbook: Deploy

**Owner:** DevSecOps Agent
**Scope:** Dragun.app — staging and production

---

## Pre-deploy checklist (agent verifies all before HITL request)

- [ ] Branch: `agent/devsecops/deploy-<sha>` created from PR branch
- [ ] Tests pass: `docker compose run --rm app npm test`
- [ ] Trivy scan: no CRITICAL findings
- [ ] Gitleaks scan: no secrets detected
- [ ] OSV scanner: no CRITICAL CVEs in dependencies
- [ ] `.env` diff reviewed: no new secrets without corresponding vault entry

## Staging deploy (no HITL required)

```bash
# On VPS, run as openclaw user
cd /data/dragun/repos/dragun-app
git fetch origin
git checkout <branch>

docker compose -f docker-compose.staging.yml pull
docker compose -f docker-compose.staging.yml up -d --remove-orphans

# Smoke test
curl -sf http://localhost:3001/health | jq .
```

## Production deploy (HITL required — agent issues HITL_REQUEST)

```bash
# Only after HITL approval received
cd /data/dragun/repos/dragun-app

# Tag the release
git tag -a "release-$(date +%Y%m%d-%H%M)" -m "Automated deploy by DevSecOps agent"

# Zero-downtime: pull new image, rolling restart
docker compose -f docker-compose.prod.yml pull
docker compose -f docker-compose.prod.yml up -d --remove-orphans --no-build

# Verify health (wait up to 60s)
for i in $(seq 1 12); do
  STATUS=$(curl -sf https://dragun.app/health | jq -r .status 2>/dev/null || echo "down")
  echo "[$i] health: $STATUS"
  [[ "$STATUS" == "ok" ]] && break
  sleep 5
done
```

## Post-deploy steps

1. Write artifact: `ops/logs/devsecops/deploy_<sha>.md` with:
   - commit SHA
   - timestamp
   - test results summary
   - scan results summary
   - who approved (HITL task ID)
2. Alert channel: `[DEPLOY] dragun.app deployed <sha> @ <timestamp>`
3. Monitor error rate for 10 minutes (see Observability)

## Rollback

If post-deploy health check fails → see `runbooks/rollback.md`
