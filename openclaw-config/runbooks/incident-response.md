# Runbook: Incident Response

**Owner:** DevSecOps Agent
**HITL Required:** P1 = immediate; P2 = within 15min; P3 = async

---

## Severity Levels

| Level | Definition | SLA |
|-------|-----------|-----|
| P1 | Production down, data loss risk, or security breach | Page Yani immediately |
| P2 | Degraded performance, partial outage, elevated error rate | Alert within 5min |
| P3 | Non-critical, single component issue, monitoring alert | Async, fix within 24h |

## P1 Immediate Actions (agent auto-runs)

```bash
# 1. Snapshot current state
docker logs dragun-app --tail=100 > /tmp/incident_$(date +%s)_app.log
docker logs caddy --tail=50 > /tmp/incident_$(date +%s)_caddy.log
docker ps -a > /tmp/incident_$(date +%s)_containers.log

# 2. Pause growth agent
openclaw agent pause growth --reason "P1 incident active"

# 3. Alert Yani immediately (do not wait for HITL queue)
curl -s "$ALERT_WEBHOOK_URL" -d "text=[P1 INCIDENT] dragun.app — $(date). Logs collected. Growth agent paused."
```

## Diagnosis Checklist

```bash
# Container health
docker compose ps

# App logs (errors in last 5min)
docker logs dragun-app --since 5m | grep -i "error\|fatal\|panic\|exception"

# Caddy/proxy
docker logs caddy --since 5m | grep -v "INFO"

# Disk space
df -h /data

# Memory
free -m

# CPU
top -bn1 | head -20

# Last deploy SHA
git -C /data/dragun/repos/dragun-app log --oneline -5
```

## Incident Report Template

Create: `ops/logs/devsecops/incident_<timestamp>.md`

```markdown
# Incident Report — <timestamp>

## Summary
<one paragraph: what happened, impact, duration>

## Timeline
- HH:MM — symptom first detected
- HH:MM — agent alerted Yani
- HH:MM — root cause identified
- HH:MM — mitigation applied
- HH:MM — recovery confirmed

## Root Cause
<category: infra | app | dependency | external>
<detailed explanation>

## Impact
- Users affected: <N or unknown>
- Duration: <X minutes>
- Data affected: <yes/no — describe>

## Mitigation Applied
<what was done>

## Preventive Measures
<what changes to make to prevent recurrence>

## HITL Actions
<list of approvals requested and granted/rejected>

## Cost of Incident
~$<X> in extra API/infra spend
```

## Post-Incident

1. Resume growth agent: `openclaw agent resume growth`
2. Add preventive measures to DevSecOps backlog
3. Update this runbook if gaps found
