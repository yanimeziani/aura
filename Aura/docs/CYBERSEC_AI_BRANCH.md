# Cybersec + AI Branch

**Purpose:** establish a permanent Aura branch for cyber security, AI safety, model governance, and deployment ethics across Aura, Dragun, gateway, vault, and future products.

## Mission

The `Cybersec + AI Branch` exists to do four things:

1. Prevent security failures before release.
2. Reduce model misuse and unsafe automation.
3. Review high-impact systems before production exposure.
4. Keep a formal ethics and incident record inside the repo.

This branch is not advisory-only. It has review authority on security-critical and high-impact AI systems.

## Scope

The branch covers:

- application security
- infrastructure security
- secrets and key handling
- AI safety and misuse controls
- data governance and privacy
- red-team exercises
- release gating for sensitive systems
- incident response and postmortems

## Structure

| Unit | Role | Output |
|---|---|---|
| Security Engineering | Hardening, auth, secrets, attack-surface review | findings, remediations, release gates |
| AI Safety + Evaluation | Model behavior review, jailbreak resistance, misuse testing | eval reports, guardrail requirements |
| Privacy + Data Governance | Data classification, retention, exposure review | data policies, access rules |
| Red Team | Adversarial testing of apps, agents, and infra | attack reports, exploit reproductions |
| Ethics Committee | Governance on high-impact deployments | approve, block, or constrain launches |

## Ethics Committee

### Mandate

The `Ethics Committee` exists to review systems that can materially affect:

- money
- legal risk
- safety
- privacy
- vulnerable users
- automated decision-making
- persuasion, collection, or enforcement flows

### Standing membership

| Seat | Responsibility |
|---|---|
| Chair | Final review coordination and decision record |
| Security Lead | Security and abuse risk assessment |
| AI Safety Lead | Model risk, hallucination, manipulation, and misuse review |
| Privacy Lead | Data handling, retention, access, and disclosure review |
| Product/Ops Lead | Operational necessity, fallback, and rollback readiness |
| Owner Representative | Final owner alignment on accepted risk |

### Decision states

The committee can issue:

- `approved`
- `approved with constraints`
- `deferred pending fixes`
- `blocked`

No sensitive production launch should skip a recorded committee state.

## What requires committee review

Review is required for:

- debtor-facing AI negotiation flows
- autonomous financial actions
- new credential or vault systems
- surveillance-like monitoring features
- cross-tenant data access patterns
- high-risk messaging or persuasion automation
- production deployments with unresolved high-severity security findings

## Required artifacts

Every reviewed launch should produce:

- threat model
- abuse case list
- privacy/data exposure summary
- rollback plan
- human override path
- incident owner
- signed decision record

These artifacts belong under `docs/` and `vault/roster/CHANNEL.md` when active work is underway.

## Branch operating model

### Before build

- define risk class
- identify affected systems
- declare required reviewers

### Before deploy

- security findings reviewed
- AI behavior reviewed
- secrets/data handling reviewed
- rollback path confirmed

### After deploy

- monitor incidents
- record deviations
- publish postmortem if needed

## Initial Aura application

This branch immediately applies to:

- `dragun-app` debtor and merchant AI flows
- `gateway/` model and session routing
- `vault/` secrets, mission control, and log-derived audio/radio surfaces
- `aura-edge` and `aura-mcp` exposed interfaces

## Repo integration

- hierarchy reference: `docs/HIERARCHY.md`
- roster reference: `docs/roster.md`
- command/process reference: `docs/AGENTS.md`

This document is the charter for the branch.
