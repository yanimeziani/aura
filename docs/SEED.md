# SEED.md

Status: Canonical Layer-0 seed memory for a strict, minimal docs corpus.

## 1) Operating Stance

Nexa is a protocol-first, security-critical distributed system. For high-level mission and guiding principles, refer to [PHILOSOPHY.md](../PHILOSOPHY.md).

Primary technical objectives:
- Build and operate a sovereign mesh with verified trust and resilience.
- Enable long-horizon agent execution with deterministic memory and specifications.
- Maintain explicit human oversight for privileged system actions.

This seed governs the following canonical files:
- `README.md`
- `PRD.md`
- `STACK.md`
- `MARKETING.md`
- `ICP.md`
- `SECURITY.md`
- `LEGAL.md`
- `ARCHITECTURE.md`
- `docs/AGENTS.md`
- `docs/FORGE_24H_PLAN.md`
- `docs/MESH_WORLD_MODEL.md`
- `docs/ARCHITECTURE_DISTILL.md`
- `docs/RAG_CORPUS_MANIFEST.md`
- `docs/UNIFIED_ACCESS.md`
- `docs/MONTESSORI_FRONTEND_SKILLS.md`
- `LICENSE.md`

## 2) Inclusive access invariant

All human-facing surfaces must satisfy the unified contract in [UNIFIED_ACCESS.md](./UNIFIED_ACCESS.md): accessibility, neurodiversity-friendly patterns, and age-friendly defaults are one standard, not three optional add-ons.

## 3) Layer-0 Spec-RAG Contract (Aura Mesh)

This project operates on defined execution loops with strict dependency management.
- **Repository**: [https://github.com/mezianiai/nexa](https://github.com/mezianiai/nexa)
- **Environment Invariant**: The workspace must remain portable and replicable via standard configuration.
- **Stack Constraints**: Standard Zig, TypeScript, Node.js, HTML, and CSS.
- **Retrieval Integrity**: Grounding is anchored in markdown and machine-readable specifications.
- **Memory Management**: Canonical memory is limited to anchors defined in `docs/RAG_CORPUS_MANIFEST.md`.
- **System Distillation**: The memory plane is periodically compressed in `docs/ARCHITECTURE_DISTILL.md`.

## 4) Architecture Memory (ASCII)

```text
NEXA LAYER-0 MEMORY PLANE
|
+-- Governance and Operating Memory
|   +-- docs/SEED.md
|   +-- docs/AGENTS.md
|   +-- docs/UNIFIED_ACCESS.md
|   +-- docs/MONTESSORI_FRONTEND_SKILLS.md
|   +-- docs/FORGE_24H_PLAN.md
|   +-- docs/MESH_WORLD_MODEL.md
|   +-- TASKS.md
|   +-- ARCHITECTURE.md (Mermaid)
|
+-- Product and Protocol Truth
|   +-- PRD.md
|   +-- docs/ARCHITECTURE_DISTILL.md
|   +-- specs/protocol.json
|   +-- specs/trust.json
|   +-- specs/recovery.json
|   +-- specs/grid_vital_lock.json
|   +-- specs/quebec_req_public_identity.json
|
+-- Runtime and Delivery
|   +-- apps/ (Operator/Public Surfaces)
|   +-- core/ (Runtime and Control Plane)
|   +-- ops/ (Deployment and Automation)
|   +-- tools/ (CLI and Support Scripts)
|
+-- Legal and Public Interface
    +-- LICENSE
    +-- LICENSE.md
    +-- LEGAL.md
    +-- MARKETING.md
    +-- ICP.md
```

## 5) Execution Cadence

Execution cycles are defined in `docs/FORGE_24H_PLAN.md`.
- Every cycle must produce a plan and a memory refresh in markdown.
- Cycles must remain provider-agnostic.

## 6) Coding Standards

Significant work is managed via versioned packets:
- Packet ID format: `forge-YYYYMMDD-HH-<slug>`.
- Packets include scope, routing, constraints, and rollback procedures.
- Outcomes record pass/fail status and drift notes.

## 7) Security and Trust Baseline

- Trust and policy constraints are mandatory inputs for all operations.
- Privileged actions require human-in-the-loop (HITL) authorization.
- Sensitive data must remain outside of markdown and source code.
- Identity and authentication favor hardware-backed controls.
- Post-quantum transition planning is integrated into the protocol lifecycle.

## 8) Sync Protocol

A SEED sync is required when any of the following change:
- Architecture boundaries or deployment paths.
- Trust, security, or legal assumptions.
- Core stack or runtime dependencies.
- Planning structure or provider strategy.

## 9) Attribution and Compliance

- Legal posture is defined in `LEGAL.md` and `LICENSE` files.
- Undocumented dependencies or unverified code use is prohibited.

## 10) Maintenance

On each substantial merge or protocol update:
1. Refresh `docs/FORGE_24H_PLAN.md` if cycle logic changed.
2. Refresh `docs/MESH_WORLD_MODEL.md` if system relations changed.
3. Verify specification links and retrieval anchors.
4. Refresh `docs/UNIFIED_ACCESS.md` if human-facing UX or copy standards changed.
5. Verify legal, security, and trust consistency.
6. Record drift and actions in `TASKS.md`.
