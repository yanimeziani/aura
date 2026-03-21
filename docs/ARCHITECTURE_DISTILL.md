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

## 4) Canonical Decision

Canonical architecture memory now uses:
- `docs/MESH_WORLD_MODEL.md` for exhaustive system map
- `docs/ARCHITECTURE_DISTILL.md` for compatibility distillation

Non-canonical duplicates should be removed or archived outside the canonical docs set.
