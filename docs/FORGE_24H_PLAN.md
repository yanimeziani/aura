# FORGE_24H_PLAN.md

Status: Canonical 24-hour execution framework for multi-agent, multi-provider runs.

## 1) Goal

Run long-horizon delivery cycles with deterministic planning, provider-agnostic execution, and mandatory markdown writeback.

## 2) Daily Cycle Template (UTC)

### Block A (00:00-01:00) - Intake and Planning

- refresh retrieval from `docs/SEED.md`, `docs/AGENTS.md`, `TASKS.md`, and active specs
- define top priorities and risk posture for the next 24h
- create or update forge packets with versioned ids
- assign providers per packet with fallback routing

### Block B (01:00-08:00) - Deep Build Run

- execute high-value implementation packets
- preserve bounded scope and log evidence checkpoints
- run mandatory checks per packet
- write progress updates to markdown artifacts

### Block C (08:00-10:00) - Review and Security Pass

- perform review packets (behavior, trust, security, regression risk)
- record findings and required fixes
- reopen failed packets with explicit remediation

### Block D (10:00-18:00) - Expansion and Integration

- execute integration packets across apps/core/ops/specs
- validate protocol and deployment coherence
- publish architecture and memory updates as needed

### Block E (18:00-21:00) - Hardening and Recovery Drills

- run recovery/rollback rehearsals for changed surfaces
- validate dependency hygiene and key handling posture
- verify observability and incident response readiness

### Block F (21:00-24:00) - Closeout and Handoff

- produce end-of-day packet status report
- update `TASKS.md` with completed/in-progress/blocked state
- sync `docs/SEED.md` and `docs/MESH_WORLD_MODEL.md` for structural changes
- stage next-day priorities and unknowns

## 3) Forge Packet Schema (Required)

Each packet must contain:
- `id`
- `objective`
- `importance`
- `scope_in`
- `scope_out`
- `provider_primary`
- `provider_fallback`
- `constraints`
- `verification`
- `rollback`
- `status`
- `evidence`

## 4) Provider Routing Policy

- routing is based on capability fit, not brand preference
- all packets must have fallback providers for continuity
- packet format and acceptance criteria remain constant across providers
- provider handoff cannot alter required checks

## 5) Long-Run Execution Rules

- no silent scope expansion
- no unversioned packet execution for significant tasks
- no completion claim without evidence link in markdown
- unresolved conflicts must be escalated with options and risk delta

## 6) End-of-Day Deliverables (Mandatory)

- updated `TASKS.md`
- updated packet outcomes
- refreshed `docs/SEED.md` (if memory anchors changed)
- refreshed `docs/MESH_WORLD_MODEL.md` (if architecture/systems relations changed)
- concise incident/risk note for next cycle
