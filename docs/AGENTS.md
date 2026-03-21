# AGENTS.md

Status: Canonical collaboration protocol for all agents and providers in this repository.

## 1) Directive

Nexa uses a documentation-first, spec-RAG, versioned forge workflow for multi-agent and multi-provider execution.

Canonical memory is markdown only and anchored in this set:
- `docs/SEED.md`
- `docs/AGENTS.md`
- `docs/FORGE_24H_PLAN.md`
- `docs/MESH_WORLD_MODEL.md`
- `docs/RAG_CORPUS_MANIFEST.md`
- `LICENSE.md`
- `TASKS.md`

All agents must treat those files as the operational memory plane.
All markdown files under `docs/` are canonical corpus inputs as enumerated in `docs/RAG_CORPUS_MANIFEST.md`.

## 2) Non-Proprietary Instruction Rule

Open protocol rule:
- authoritative agent instructions must live in `docs/AGENTS.md`
- provider-specific instruction files are non-authoritative
- if a conflict appears, this file wins
- planning, execution, and post-run reports must be written back in markdown

## 3) Multi-Agent / Multi-Provider Model

Supported execution pattern:
- planner agent: turns objective into versioned plan with acceptance checks
- researcher agent: gathers evidence and source references
- builder agents: implement scoped tasks per spec packet
- reviewer agent: validates behavior, security, and drift
- release agent: verifies gates and readiness

Provider neutrality rule:
- tasks are expressed as capability contracts, not provider-specific prompts
- each task packet must declare inputs, outputs, constraints, and verification
- packet format is invariant across Gemini, OSS, and any future provider

## 4) Spec-RAG Forge Lifecycle (BMAD v6)

Each forge cycle follows the **BMAD v6** (Analysis, Plan, Solutioning, Implementation) order:
1.  **Analysis**: Ingest canonical memory (`SEED`, `AGENTS`, `FORGE_24H_PLAN`, active specs) to codify context and gaps.
2.  **Plan**: Select or create a versioned forge packet in `TASKS.md` with explicit acceptance checks.
3.  **Solutioning**: Define the architecture/data path for the smallest shippable outcome per spec packet.
4.  **Implementation**: Execute bounded work, run verification checks, and write outcomes/evidence back to markdown memory.

Any cycle without markdown memory writeback is considered out of protocol.

## 5) Algorithmic Loop Safeguard (Ralph Wiggum)

To prevent "everything is fine while the house is burning" loops, agents must apply the **Ralph Wiggum Safeguard**:
- **Continuous State Detection**: At every BMAD step, verify that current progress remains aligned with the objective.
- **Loop-Breaking Protocol**: If a state detection identifies a redundant or stagnant cycle (the "Ralph Wiggum" state), the agent must immediately report the drift and abort to the nearest stable HITL anchor.
- **No Infinite Markdown**: Do not create new markdown files to resolve loops; refine existing canonical anchors only.
- **Distill-by-Design**: Maintain a light memory plane via daily distillation in `docs/ARCHITECTURE_DISTILL.md`.

## 5) Task Packet Contract (Required)

Every planned run must include:
- objective and business/security importance
- scope paths and out-of-scope paths
- required specs/docs
- provider assignment and fallback provider
- execution budget (time/token/compute)
- checks and exit criteria
- rollback path and incident owner

## 6) Security and Trust Constraints

- no secrets in markdown, code, or logs
- no undocumented key use or hidden credentials
- all privileged or destructive actions require explicit HITL approval
- protocol and trust constraints are sourced from:
  - `docs/ARCHITECTURE_DISTILL.md`
  - `docs/MESH_WORLD_MODEL.md`
  - `specs/protocol.json`
  - `specs/trust.json`
  - `specs/recovery.json`

## 7) Quality Gate

Minimum gate for accepted agent output:
- requirements traceable to a task packet
- implementation and docs remain synchronized
- verification evidence is recorded
- architecture memory reflects structural changes
- legal and attribution obligations are preserved

## 8) Conflict Resolution and Veto Awareness

When agents disagree:
1. defer to `PRD.md` and `docs/SEED.md`
2. apply canonical protocol/trust/safety constraints from the remaining docs set
3. escalate unresolved conflicts to HITL with options and risk deltas

High-impact decisions should include explicit veto checkpoint references in `TASKS.md`.
