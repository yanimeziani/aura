# Runbook: Cost Panic Mode

**Owner:** DevSecOps Agent (monitors) + both agents (comply)
**Trigger:** Automatic or manual
**HITL Required:** No — panic mode activates immediately, notifies Yani

---

## What is Panic Mode

A cost circuit breaker. When daily spend approaches or exceeds the global cap,
Cerberus automatically shifts to minimum-cost operations until the next day's
budget resets.

## Automatic Triggers

| Condition | Action |
|-----------|--------|
| Global daily spend > $4.50 (90% of $5 cap) | Warn + prep panic |
| Global daily spend > $5.00 (hard cap) | **Activate panic mode** |
| Agent-specific cap breached (growth > $2) | Pause growth agent only |
| Manual: `cerberus panic on` | Activate panic mode |

## What Panic Mode Does

1. **Pauses growth agent** completely — no new tasks, no batch runs
2. **DevSecOps agent**: cheap model only (haiku-class), no mid or top tier
3. **Exception**: P1 production incidents bypass panic mode — always use best model
4. **Notifies Yani** immediately via alert webhook
5. **Logs** activation with spend summary to `ops/logs/devsecops/panic_<date>.md`

## Activating Manually

```bash
# From Termux or VPS shell
cerberus panic on

# Check status
cerberus status --costs

# See which agent is using what
cerberus costs --breakdown
```

## What Stays Running in Panic Mode

- DevSecOps monitoring (cheap model)
- Health checks and uptime monitoring
- HITL queue (no cost)
- P1 incident response (cost exemption)

## What Stops in Panic Mode

- Growth agent (all tasks)
- Batch content generation
- Nightly growth reports
- SEO page batch generation
- Any new top-tier model calls

## Deactivating Panic Mode

Panic mode auto-resets at midnight UTC (daily budget resets).

Manual deactivation:
```bash
cerberus panic off   # requires Yani confirmation
```

Panic mode will NOT auto-deactivate mid-day even if a task that triggered it
completes. This prevents bouncing in/out of panic mode repeatedly.

## Panic Mode Artifact

Write to `ops/logs/devsecops/panic_<date>.md`:
```markdown
# Panic Mode — <date>

## Trigger
<condition that triggered it>

## Spend at activation
- Global: $X.XX / $5.00
- DevSecOps: $X.XX / $3.00
- Growth: $X.XX / $2.00

## Duration
Activated: <timestamp>
Deactivated: <timestamp> (or: pending next-day reset)

## Tasks paused
- <list of paused growth tasks>

## Actions taken during panic mode
- <list>
```

## Preventing Future Triggers

After each panic mode event, DevSecOps agent reviews:
1. Which task(s) consumed the most tokens
2. Whether model routing was correct (were cheap tasks using expensive models?)
3. Propose routing rule updates if needed
