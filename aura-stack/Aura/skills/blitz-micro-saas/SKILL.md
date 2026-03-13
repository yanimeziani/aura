---
name: blitz-micro-saas
description: Micro-SaaS blueprint: smallest lovable workflow, pricing, retention, and ops.
---

## Objective

Build micro-SaaS that is **small, paid, and maintained** with automation.

## Architecture baseline

- One core workflow end-to-end.
- One datastore.
- One auth path.
- One billing path.

## Scope rules

- If it doesn’t change activation or retention this week, cut it.
- Ship “manual behind the scenes” before full automation.

## Pricing

- Start simple: 1 plan.
- Add tiers only after you see distinct willingness-to-pay segments.

## Retention

- Onboarding: 3 steps max to value.
- Weekly value email / digest.
- Usage-based triggers (nudge when stuck; celebrate when success).

## Ops

- Logs, basic metrics, error alerts.
- Backups before migrations.
