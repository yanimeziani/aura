# ARCHITECTURE_DISTILL.md

Status: Distilled architecture memory for the canonical minimal docs corpus.

## 1) Source Inputs

This distill is derived from:
- current repository structure (`apps`, `core`, `ops`, `tools`, `specs`, `vault`)
- canonical memory files in `docs/`
- root policy/product anchors (`PRD.md`, `SECURITY.md`, `LEGAL.md`)

## 2) Distilled Architecture Model

Nexa currently remains compatible with a six-layer protocol model:
1. identity and trust
2. transport and routing
3. state and recovery
4. execution and coordination
5. applied sovereignty domains
6. operator interfaces

This maps cleanly onto the canonical memory framework:
- strategic memory and planning in `docs/SEED.md` and `docs/FORGE_24H_PLAN.md`
- agent rules in `docs/AGENTS.md`
- world and governance mapping in `docs/MESH_WORLD_MODEL.md`
- machine contracts in `specs/*.json`

## 3) Compatibility Checks

### Architecture to RAG compatibility

- protocol-first orientation is preserved
- trust and HITL constraints remain explicit
- recovery and continuity requirements remain first-order constraints
- multi-provider execution is now normalized via versioned forge packets

### Potential mismatch zones

- legacy narrative docs with stale branding or one-off project framing
- duplicate architecture visual files not aligned with current world model
- large export artifacts that are not maintainable as canonical memory

## 4) Daily Distill (2026-03-21)

The architecture has been unified under the **Monarch Engine Protocol**:
- **Consolidation**: Root and `docs/` anchors have been prioritized for all RAG retrieval.
- **Protocol Adoption**: BMAD v6 (Analysis-Plan-Solution-Implementation) is now the required agent workflow.
- **Loop Breaking**: The Ralph Wiggum Safeguard is enforced to prevent stagnant or infinite markdown generation.
- **Lightness**: Memory plane is strictly limited to canonical anchors defined in `docs/RAG_CORPUS_MANIFEST.md`.
- **Identity**: Centralized SSH (ED25519) for global GitHub ID and SanDisk "Smart Partitions" for tripartite key structure.
- **Stack Lockdown**: Hard interdiction on external deps. Stack locked to **Zig 0.13.0, TypeScript 5.5.4, and Node.js 22 LTS**.
- **Supply Chain Purge**: Permanently removed all Node.js/Next.js apps and Python services with external pip dependencies to enforce a zero-CVE, sovereign technical baseline.

## 5) Canonical Decision

Canonical architecture memory now uses:
- `docs/MESH_WORLD_MODEL.md` for exhaustive system map
- `docs/ARCHITECTURE_DISTILL.md` for compatibility distillation

Non-canonical duplicates should be removed or archived outside the canonical docs set.
