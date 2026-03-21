# AGENTS.md

Status: Multi-agent collaboration center for this repository.

## 1) Purpose

This file coordinates human + agent collaboration for architecture exploration, implementation, review, and maintenance.

Key rule:
- Use open repository standards only (`AGENTS.md`, `SEED.md`, `TASKS.md`).
- Do not rely on proprietary agent-instruction markdown conventions as source-of-truth.

## 2) Canonical Collaboration Files

- `docs/SEED.md` -> Layer-0 system prompt memory and RAG anchor
- `docs/AGENTS.md` -> this collaboration protocol
- `TASKS.md` -> active workboard and execution status
- `PRD.md` -> product requirements and scope intent
- `STACK.md` -> technical stack source-of-truth
- `MARKETING.md` -> messaging source-of-truth
- `ICP.md` -> ideal collaborator profile source-of-truth
- `SECURITY.md` -> security policy source-of-truth
- `LEGAL.md` -> legal policy source-of-truth
- `docs/ELECTRO_SPATIAL_RAG.md` -> Electro Spatial RAG architecture distill
- `LICENSE` -> legal baseline
- `docs/transfer/OSS_SOURCE_REGISTER.md` -> open-source attribution registry

## 3) Multi-Agent Roles

- Architect Agent
  - maintains architecture maps, interfaces, boundaries, and invariants
- Builder Agent
  - implements scoped changes with testable outcomes
- Reviewer Agent
  - checks regressions, trust/security impact, and docs drift
- Research Agent
  - expands evidence and source citations for design decisions
- Release Agent
  - verifies readiness gates and handover integrity

## 4) Layer-0 RAG Workflow

Every agent cycle should follow:
1. retrieve from canonical anchors (`SEED.md`, `PRD.md`, core docs/specs)
2. validate intent against active tasks in `TASKS.md`
3. implement or propose bounded change
4. refresh memory artifacts when structure changed
5. cite repository paths and OSS sources

## 5) Mandatory Update Triggers

When these files change, refresh `docs/SEED.md` in the same change set:

- `PRD.md` -> update mission, goals, and phase memory
- stack/runtime configs (`package.json`, build/runtime files) -> update stack baseline
- `STACK.md` -> update SEED stack section and related architecture memory if boundaries changed
- `MARKETING.md` and `ICP.md` -> update SEED product/audience memory
- architecture files in `docs/` or `specs/` -> update ASCII + Mermaid memory
- `docs/ELECTRO_SPATIAL_RAG.md` -> update when retrieval topology, subsystem graph, or context routing changes
- `TASKS.md` -> update task synchronization status in SEED
- `SECURITY.md` -> update SEED security/legal section
- `LEGAL.md` -> update SEED security/legal section
- `LICENSE` -> update license and attribution section in SEED

If an edit changes architecture and SEED is not updated, the change is incomplete.

## 6) Neurodiverse-Friendly Engineering Rules

- Keep docs chunked with short, explicit sections.
- Keep terms consistent across files.
- Prefer deterministic names and avoid hidden abbreviations.
- Include both text and diagram representations for architecture.
- Avoid context switching by linking every task to exact file paths.

## 7) Minimum Quality Gate for Agent Changes

- scope is explicit
- tests/checks are documented or executed
- architecture memory is refreshed when needed
- attribution is updated for external OSS influences
- no secrets or private credentials included

## 8) Conflict Resolution

When agents disagree:
1. defer to `PRD.md` for product intent
2. defer to `docs/PROTOCOL.md`, `docs/TRUST_MODEL.md`, `docs/THREAT_MODEL.md` for safety/trust constraints
3. log unresolved decision in `TASKS.md` with owner and due date
