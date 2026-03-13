# DevSecOps Agent — Task Template Reference
# Use these as the structured input format when submitting tasks via OpenClaw.

---

## deploy

```yaml
task_type: deploy
branch: agent/devsecops/deploy-<sha>
target: staging | production
commit_sha: <sha>
test_command: "docker compose run --rm app npm test"
```

---

## incident

```yaml
task_type: incident
severity: P1 | P2 | P3
symptom: "<describe what's broken>"
last_deploy_sha: "<sha>"
logs_available: true | false
```

---

## security_scan

```yaml
task_type: security_scan
scope: repo | image | dependencies | secrets | all
repo_path: /data/dragun/repos/dragun-app
image_ref: dragun-app:latest  # for image scans
```

---

## cost_audit

```yaml
task_type: cost_audit
period: daily | weekly
include_per_model: true
include_per_agent: true
```

---

## infra_change

```yaml
task_type: infra_change
description: "<what and why>"
files_affected:
  - docker/docker-compose.yml
  - scripts/vps/bootstrap.sh
blast_radius: staging | production
reversible: true | false
```

---

## routine_check

```yaml
task_type: routine_check
checks:
  - uptime
  - disk_space
  - container_health
  - backup_verify
  - cert_expiry
```
