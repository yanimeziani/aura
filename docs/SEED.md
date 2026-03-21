# SEED.md

Status: Canonical Layer-0 seed memory for a strict, minimal docs corpus.

## 1) Mission and Operating Stance

Nexa is run as a protocol-first, security-critical collaboration system.

Primary mission:
- build and operate a sovereign mesh with world-class trust, resilience, and execution velocity
- enable long-horizon agent runs with deterministic memory, specs, and writeback
- keep human governance and veto authority explicit for high-impact actions

This seed is the memory umbrella for:
- `PRD.md`
- `STACK.md`
- `MARKETING.md`
- `ICP.md`
- `SECURITY.md`
- `LEGAL.md`
- `docs/AGENTS.md`
- `docs/FORGE_24H_PLAN.md`
- `docs/MESH_WORLD_MODEL.md`
- `docs/ARCHITECTURE_DISTILL.md`
- `docs/RAG_CORPUS_MANIFEST.md`
- `LICENSE.md`
- `ARCHITECHTURE.md`

## 2) Layer-0 Spec-RAG Contract (Monarch Engine)

This project operates on **BMAD v6** loops protected by the **Ralph Wiggum Safeguard** and **HARD INTERDICTION** on external dependencies.
- **Repository**: [https://github.com/mezianiai/nexa](https://github.com/mezianiai/nexa)
- **Invariant: REPLICABILITY**: Never work on a non-replicable environment. The workspace must remain portable via [https://github.com/MezianiAI/.dotfiles](https://github.com/MezianiAI/.dotfiles).
- **Stack Constraints (LOCKED)**: Strictly **Standard Zig 0.13.0 (no external deps), TypeScript 5.5.4, Node.js 22 LTS, HTML, CSS**.
- **RAG RAM Integrity**: Retrieval is anchored in markdown anchors and machine specs; RAM must never steer towards external options.
- **No Infinite Markdown**: Canonical memory is strictly limited to anchors in `docs/RAG_CORPUS_MANIFEST.md`.
- **Daily Distill**: Memory plane is compressed daily in `docs/ARCHITECTURE_DISTILL.md`.


Canonical retrieval anchors:
- `README.md`
- `docs/SEED.md`
- `docs/AGENTS.md`
- `docs/FORGE_24H_PLAN.md`
- `docs/MESH_WORLD_MODEL.md`
- `docs/ARCHITECTURE_DISTILL.md`
- `docs/RAG_CORPUS_MANIFEST.md`
- `PRD.md`
- `STACK.md`
- `MARKETING.md`
- `ICP.md`
- `SECURITY.md`
- `LEGAL.md`
- `specs/protocol.json`
- `specs/trust.json`
- `specs/recovery.json`
- `LICENSE.md`
- `ARCHITECHTURE.md`
- `LICENSE`

Corpus rule:
- only the canonical files listed in `docs/RAG_CORPUS_MANIFEST.md` are allowed in `docs/`
- any other docs markdown is out-of-bounds and must be removed

## 3) Architecture Memory (ASCII)

```text
NEXA LAYER-0 MEMORY PLANE
|
+-- Governance and Operating Memory
|   +-- docs/SEED.md
|   +-- docs/AGENTS.md
|   +-- docs/FORGE_24H_PLAN.md
|   +-- docs/MESH_WORLD_MODEL.md
|   +-- TASKS.md
|   +-- ARCHITECHTURE.md (Mermaid)
|
+-- Product and Protocol Truth
|   +-- PRD.md
|   +-- docs/ARCHITECTURE_DISTILL.md
|   +-- specs/protocol.json
|   +-- specs/trust.json
|   +-- specs/recovery.json
|
+-- Runtime and Delivery
|   +-- apps/ (operator/public surfaces)
|   +-- core/ (runtime and native control plane)
|   +-- ops/ (deployment, recovery, automation)
|   +-- tools/ (cli and support scripts)
|
+-- Legal and Public Interface
    +-- LICENSE
    +-- LICENSE.md
    +-- LEGAL.md
    +-- MARKETING.md
    +-- ICP.md
```

## 4) 24-Hour Forge Rhythm

Execution cadence is defined in `docs/FORGE_24H_PLAN.md`.

Invariant:
- every 24-hour cycle must produce a plan, evidence, and memory refresh in markdown
- each cycle must be provider-agnostic and runnable with fallback providers

## 5) Versioned Forge Coding Standard

All significant work runs through versioned packets:
- packet id format: `forge-YYYYMMDD-HH-<slug>`
- packet includes scope, provider routing, constraints, checks, rollback
- packet outcome records pass/fail and drift notes
- packet references changed files and follow-up tasks

Packets live in `TASKS.md` or linked markdown docs.

## 6) Security and Trust Baseline

- trust model and policy constraints are mandatory inputs, not optional context
- privileged actions must pass HITL governance controls
- secret handling must remain outside markdown/code unless encrypted and policy-approved
- all identity/auth decisions must favor hardware-backed, phishing-resistant controls
- post-quantum transition planning is part of protocol lifecycle

Authoritative files:
- `SECURITY.md`
- `docs/ARCHITECTURE_DISTILL.md`
- `specs/trust.json`
- `specs/recovery.json`

## 7) Change-Trigger Protocol (Mandatory)

A SEED sync is required whenever any of these change:
- architecture boundaries, runtime topology, or deployment path
- trust/security/legal assumptions
- core stack/runtime dependencies
- collaboration policy, planning structure, or provider strategy
- world-model mapping domains (legal/social/political/economic/physical/PR)

If architecture changed and `docs/MESH_WORLD_MODEL.md` was not updated, the change is incomplete.

## 8) Source and Attribution Rule

- legal posture comes from:
  - `LEGAL.md`
  - `LICENSE`
  - `LICENSE.md`
- undocumented copying or hidden dependency borrowing is not allowed

## 9) Seed Maintenance Ritual

On each substantial merge or protocol update:
1. refresh `docs/FORGE_24H_PLAN.md` if cycle logic changed
2. refresh `docs/MESH_WORLD_MODEL.md` if structure/power/relations changed
3. verify spec links and retrieval anchors
4. verify legal/security/trust consistency
5. record drift and next actions in `TASKS.md`
