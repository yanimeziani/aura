---
name: blitz-micro-launch
description: Blitzkrieg micro-launch system: idea → offer → landing → distribution → feedback loop in 48h.
---

## Objective

Ship **micro launches** fast (48h cadence) with automated marketing + measurement.

## Constraints (Aura-tailored)

- **Sovereign-first**: run the stack on your infra; minimize third-party dependencies.
- **Safe ops**: no destructive ops; produce artifacts into `vault/docs_inbox/` and `out/`.
- **Automation**: prefer cron/scripts/n8n over manual steps.

## 48h loop (template)

### 0) Niche selection (30 min)
- Pick 1 niche + 1 pain + 1 buyer type.
- Define “moment of urgency” (what triggers purchase now).

### 1) Offer (60 min)
- One-line promise, one ICP, one outcome.
- Package: micro-digital product or micro-SaaS (smallest lovable).
- Price ladder: \( \$19 \rightarrow \$49 \rightarrow \$199 \) (example).

### 2) Build (4–10h)
- Build the **smallest** working artifact.
- No feature creep. One core workflow.

### 3) Landing + checkout (2h)
- Landing page with: pain → proof → offer → CTA.
- Collect email even if checkout isn’t ready (waitlist).

### 4) Distribution (2–6h)
- 3 channels max; pick where buyers already are.
- Post once/day + DM batch + one “artifact” (demo, checklist, calculator).

### 5) Measure + iterate (daily)
- Track: views → clicks → signups → paid.
- One change/day max (keep signal clean).

## Artifacts to produce (Aura)

- `vault/docs_inbox/docs/launch_<date>.md` — plan + copy + checklist
- `vault/docs_inbox/docs/offer_<date>.md` — offer sheet
- `vault/docs_inbox/docs/funnel_<date>.md` — funnel + KPIs
