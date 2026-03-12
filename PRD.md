# PRD — Cerberus / Pegasus "Final Boss" Setup (Mobile → Debian → Debian VPS) for Dragun.app

**Version:** 1.0
**Owner:** Yani
**Product:** Dragun.app
**Runtime:** Android (Termux) + Debian Host + Debian VPS
**Primary LLM Driver:** Claude Code (interactive coding) + API-routed models (batch + cheap tasks)

---

## 1) Purpose and Vision

Build a 24/7 "mobile-to-cloud" command center where a Samsung Z Fold (Pegasus app) is the cockpit,
a Debian machine is the staging ground, and a Debian VPS is the always-on executor. Cerberus
is the lightweight runtime that hosts agents, while Pegasus is the control plane (Android app +
compat API) that provides dashboards, HITL approvals, and cost visibility. Together they manage
two always-available agents:

1. **DevSecOps Agent (BMAD v6):** keeps infra stable, secure, observable, cheap, and deployable anytime.
2. **Growth Hacking Coder Agent (BMAD v6):** builds and ships growth loops, scrapers, SEO pages, content automation, and experiments with minimal human input.

The system must be lean: minimal tokens, minimal cost, maximum automation, and clear
human-in-the-loop (HITL) checkpoints for risky actions.

---

## 2) Non-Goals

- Not building a general-purpose "AI OS" for everything (only Dragun.app scope).
- Not replacing human product direction (agents execute, you steer).
- Not promising full autonomy for billing/financial actions (always HITL).
- Not building a full UI-first mobile app; Pegasus Android app is the primary mobile interface.

---

## 3) Target Users

- **Primary:** Yani (Founder) operating from phone, sometimes with limited money/tokens.
- **Secondary:** "future VA agent" role (top-level coordinator), but initially you are the VA.

---

## 4) Operating Model (BMAD v6 Interpretation)

BMAD v6 here means: strict roles, strict boundaries, ruthless documentation, and deterministic
workflows.

**Core principles:**
- Always prefer cheap models for classification, summarization, extraction, linting, code review, and scaffolding.
- Use expensive models only for: architecture decisions, complex debugging, security-critical reasoning, and major refactors.
- Every agent action produces artifacts: diffs, logs, decisions, and next steps.
- HITL gates for deployments, data writes, spending money, and anything involving user PII.

---

## 5) System Architecture

### 5.1 Topology

| Layer | Device | Role |
|-------|--------|------|
| Device | Z Fold 5 (Pegasus app) | Control plane: commands, dashboard, gate approvals |
| Staging | Debian machine (SSH) | Dev containers, quick tests, local builds, preview deploys |
| Execution | Debian VPS | Cerberus runtime + agents 24/7 + CI-like pipelines + schedulers |

### 5.2 Components

1. **Claude Code (interactive dev)** — high-leverage coding sessions, complex changes, system design.
2. **Cerberus (runtime)** — lightweight Zig binary (<1 MB) that hosts agents, enforces gates, stores memory/artifacts, runs skills/tools.
3. **Pegasus (control plane)** — Android app + pegasus-compat API providing dashboards, HITL approvals, cost monitoring, and agent control.
4. **MCP/Tools Layer (token-saving)** — "tools first" for repo search, file diffing, linting, tests, web checks, doc generation.
5. **Observability** — logs, traces, cost telemetry, alerting.

---

## 6) Agent Roster (Lean)

### 6.1 Agent A — DevSecOps Agent (BMAD v6)

**Mission:** keep Dragun.app deployable and safe at all times.

**Responsibilities:**
- Infra: Docker, reverse proxy, secrets, environment management
- CI/CD: build, test, deploy pipelines
- Security: dependency scanning, SAST, secrets scanning, basic threat modeling
- Reliability: monitoring, alerting, backups, rollbacks, incident playbooks
- Cost discipline: enforce spend budgets, auto-switch to cheaper models, throttle workloads

**Inputs:** repo state, infra configs, deployment targets, logs, error traces, uptime requirements

**Outputs:** PRs, patches, infra diffs, runbooks, alerts, dashboards, postmortems

**HITL gates (must request approval):**
- prod deployment
- secret rotation
- infra changes that affect billing / network exposure
- deletion of resources or DB schema changes

### 6.2 Agent B — Growth Hacking Coder (BMAD v6)

**Mission:** ship growth loops and measurable acquisition mechanics.

**Responsibilities:**
- SEO pages + programmatic landing pages
- Scrapers/collectors for content or lead generation (within legal/ToS boundaries)
- Email automation drafts + sequences (you approve)
- A/B experiments scaffolding
- Analytics instrumentation + funnel tracking
- Content generation pipelines (scripts, prompts, post templates)

**Inputs:** growth goals, target personas, current funnel metrics, brand constraints

**Outputs:** PRs, growth experiments, scripts, scheduled jobs, dashboards, weekly reports

**HITL gates:**
- sending emails/SMS to real users
- anything touching paid ads spend
- anything involving user PII exports
- scraping targets that might violate ToS (agent must flag risk)

---

## 7) Workflow: Scheduling and Escalation

- **DevSecOps agent** is always-on for monitoring + reactive triage.
- **Growth agent** runs in bursts: nightly batch + on-demand experiments.

**Escalation:**
- If DevSecOps sees incident risk → pauses growth jobs.
- If growth jobs require infra changes → requests DevSecOps review.

---

## 8) Pegasus Mobile Requirements (Z Fold)

### 8.1 UX Requirements (App-first)

Single tap to:
- view agent dashboard (status, recent activity)
- open HITL approval queue
- view cost and spend overview

**Views:**
- "Approval Queue" — pending HITL actions with diff previews
- "Costs" — tokens/day, $/day, model usage split
- "Ops" — uptime, errors, last deploy, last backup, alerts
- "Terminal" — SSH session to VPS for ad-hoc commands

### 8.2 Reliability Requirements

- Works on flaky mobile network
- Pegasus app persists auth token and reconnects automatically
- SSH terminal available for fallback/ad-hoc access
- Idempotent scripts (re-run safe)

---

## 9) VPS Requirements

- Cerberus binary deployed via systemd (single static binary, no Docker required)
- Persistent storage: `/data/cerberus` (state, memory, audit logs), `/data/dragun` (repos, artifacts)
- Security baseline: firewall allowlist, fail2ban, key-only SSH, separate user
- Observability: structured logs + rotation, alert channel (email/telegram/discord webhook)

---

## 10) Repos and Branching

- `dragun-app` — main repo (source of truth)
- `cerberus/` — runtime, deploy scripts, specs, pegasus-compat API
- `pegasus/` — Pegasus Android app (Kotlin/Jetpack Compose)
- `openclaw-config` — **deprecated** (legacy infra configs, superseded by cerberus/)

**Branch policy:**
- agents push to `agent/*` branches
- all merges require you (or VA agent) to approve

---

## 11) Token and Cost Strategy (Hard Requirements)

| Model Tier | Use Cases |
|------------|-----------|
| Cheap | triage, summarization, extraction, doc updates, simple refactors, test writing |
| Mid-tier | medium complexity coding, bug fixes, feature scaffolds |
| Top-tier (Claude Code / best available) | architecture decisions, production incidents, security-sensitive tasks, complex refactors |

**Budget controls:**
- daily spend cap
- per-agent spend cap
- automatic downgrade when caps reached
- "panic mode" → disable growth agent, keep DevSecOps only

---

## 12) Skills / Tools (MCP-First)

Minimum toolset:
- repo search (ripgrep)
- diff viewer
- formatter + linter
- unit test runner
- e2e runner (optional later)
- dependency audit (npm audit / osv-scanner)
- secrets scanning (gitleaks)
- container build + vulnerability scan (trivy)
- uptime check + simple synthetic test
- changelog + PR generator

---

## 13) Auditability and Traceability

Every agent run stores:
- task prompt + context references
- tool calls executed
- diffs produced
- decision summary
- cost estimate
- HITL status (approved/blocked)

Retention: 30 days minimum locally, optionally push summaries to repo as `ops/logs/`.

---

## 14) Security and Compliance

- No secrets in prompts, logs, or repo — use env vars + secret store
- Redact PII in logs
- Growth agent must label tasks:
  - `SAFE` — no external impact
  - `REVIEW` — external comms or scraping risk
  - `BLOCKED` — violates ToS/law/PII policy

---

## 15) Success Metrics

**Ops:**
- MTTR decreases
- Deploy frequency increases with fewer rollbacks
- Error rate + incident frequency decrease

**Growth:**
- experiments shipped/week
- SEO pages shipped/week
- measurable traffic lift
- conversion lift (signup/lead)

**Cost:**
- tokens per merged PR
- $ spent per shipped feature/experiment

---

## 16) Milestones

| Milestone | Target | Deliverables |
|-----------|--------|-------------|
| M0 | Day 1 | Pegasus app setup, SSH flows, Cerberus on VPS, repo mounted |
| M1 | Week 1 | DevSecOps agent live: CI pipeline, secrets scan, deploy playbook, alerts |
| M2 | Week 2 | Growth agent live: analytics, first 2 experiments, weekly report automation |
| M3 | Week 3–4 | Cost caps stable, approval queue polished, runbooks + incident response solid |

---

## 17) Risks and Mitigations

| Risk | Mitigation |
|------|-----------|
| Model drift / bad patches | enforce tests + PR reviews + HITL for merges |
| Cost runaway | hard caps + downgrade + panic mode |
| Security leaks | secret scanning + strict redaction + no secrets in context |
| Scraping/legal risk | explicit risk labeling + mandatory approval |

---

## 18) Acceptance Criteria (Must Pass)

- From phone: one command opens cockpit and shows open tasks, alerts, and costs
- Agents can: create PR branches, run tests, propose merges
- DevSecOps agent: detects failing build and proposes fix; can rollback with approval
- Growth agent: ships a measurable experiment behind a feature flag
- System: enforces HITL gates for risky actions; logs every run with diffs + costs
