---
name: blitz-automation-orchestrator
description: Full-auto orchestration: cron/stub/systemd, queues, and “overnight run” patterns.
---

## Objective

Run Aura like an automated business: tasks execute while you sleep.

## Patterns

- **Stub everything**: run long loops via `aura stub -- <cmd>`.
- **Idempotent jobs**: re-runnable without duplicating outcomes.
- **Append-only logs**: write to `vault/*.log` or `out/*.log`.
- **Checkpoints**: write last successful step to `vault/`.

## Suggested loops

- Docs: `aura docs-maid`
- Internet/ops: `aura opensea status` (connectivity check)
- Micro-launch: generate plan, push artifacts, post, measure, iterate

## Safety

- No destructive ops without explicit operator instruction.
- Never auto-sign transactions or spend money by default.
