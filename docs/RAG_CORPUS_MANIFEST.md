# RAG_CORPUS_MANIFEST.md

Status: Rigid canonical manifest for all `docs/` memory artifacts.

## 1) Purpose

This file binds the entire `docs/` folder into the canonical RAG framework.

Hard rule:
- only files listed in this manifest are allowed in `docs/`
- no silent additions
- retrieval and planning must consult this manifest first

## 2) Canonical Docs Set

These are the only in-bounds markdown files in `docs/`:

- `docs/SEED.md`
- `docs/AGENTS.md`
- `docs/FORGE_24H_PLAN.md`
- `docs/MESH_WORLD_MODEL.md`
- `docs/RAG_CORPUS_MANIFEST.md`
- `docs/ARCHITECTURE_DISTILL.md`

## 3) Retrieval Contract

For every non-trivial task:
1. load `docs/SEED.md`, `docs/AGENTS.md`, and `docs/RAG_CORPUS_MANIFEST.md`
2. load `docs/FORGE_24H_PLAN.md` for execution cadence
3. load `docs/MESH_WORLD_MODEL.md` and `docs/ARCHITECTURE_DISTILL.md` for architecture context
4. cite consulted paths in plan/output
5. write back changes to canonical docs only

## 4) Drift Control

When a new markdown file is proposed under `docs/`:
- reject by default
- only allow with explicit architectural justification
- add it to this manifest in the same change

If this manifest is stale, the RAG framework is considered out of compliance.

## 5) Root Markdown Boundary

To keep the repository root architecturally clean, only these root markdown files are in-bounds:
- `README.md`
- `PRD.md`
- `TASKS.md`
- `STACK.md`
- `MARKETING.md`
- `ICP.md`
- `LEGAL.md`
- `SECURITY.md`
- `GOVERNANCE.md`
- `CONTRIBUTING.md`
- `CODE_OF_CONDUCT.md`
- `SUPPORT.md`
- `DISCLAIMER.md`
- `COLLABORATORS.md`
- `ULAVAL_ONBOARDING_SUMMARY.md`
- `LICENSE.md`
- `ARCHITECHTURE.md`

Any other root `.md` file is out-of-bounds and should be purged or relocated.
