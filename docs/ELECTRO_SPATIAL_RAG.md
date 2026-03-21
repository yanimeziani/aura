# ELECTRO_SPATIAL_RAG.md

Status: Canonical Electro Spatial RAG architecture memory for agent context.

## 1) Definition

Electro Spatial RAG is the repository's architecture-aware retrieval model:
- electro = active signal routing between intent, context, and evidence
- spatial = repository topology as first-class memory (docs, specs, code surfaces)
- rag = retrieval-first grounding before generation or edits

It provides a solid-state architecture distill that agents can repeatedly load with low ambiguity.

## 2) Core Objectives

- keep agent context synchronized with evolving architecture
- enforce source-grounded retrieval from canonical anchors
- make system state visible through Mermaid and text maps
- reduce drift between docs, specs, and implementation

## 3) Solid-State Distill (Mermaid)

```mermaid
flowchart LR
  subgraph Intent["Intent Plane"]
    UQ["User Query"]
    TG["Task Goal"]
    CTX["Change Type Classifier"]
  end

  subgraph Memory["Memory Plane"]
    SD["docs/SEED.md"]
    PRD["PRD.md"]
    STK["STACK.md"]
    MKT["MARKETING.md"]
    ICP["ICP.md"]
    SEC["SECURITY.md"]
    LEG["LEGAL.md"]
    TAS["TASKS.md"]
  end

  subgraph Spatial["Spatial Plane"]
    DOCS["docs/*"]
    SPECS["specs/*.json"]
    CORE["core/*"]
    APPS["apps/*"]
    OPS["ops/*"]
    TOOLS["tools/*"]
    VAULT["vault/* (non-public operational state)"]
  end

  subgraph Retrieval["Retrieval Plane"]
    IDX["Anchor Index"]
    R1["Spec Retrieval"]
    R2["Architecture Retrieval"]
    R3["Code Surface Retrieval"]
    CITE["Citation/Attribution Check"]
  end

  subgraph Synthesis["Synthesis Plane"]
    PLAN["Edit Plan"]
    PATCH["Code/Doc Changes"]
    SYNC["SEED Sync Trigger Engine"]
    QA["Quality + Security Gate"]
  end

  UQ --> TG --> CTX
  CTX --> IDX
  SD --> IDX
  PRD --> IDX
  STK --> IDX
  MKT --> IDX
  ICP --> IDX
  SEC --> IDX
  LEG --> IDX
  TAS --> IDX

  IDX --> R1
  IDX --> R2
  IDX --> R3

  DOCS --> R2
  SPECS --> R1
  CORE --> R3
  APPS --> R3
  OPS --> R3
  TOOLS --> R3
  VAULT -. restricted .-> R3

  R1 --> CITE
  R2 --> CITE
  R3 --> CITE
  CITE --> PLAN --> PATCH --> SYNC --> QA
  QA --> SD
```

## 4) Retrieval Priority Order

1. `docs/SEED.md` (global memory and synchronization policy)
2. `PRD.md` and system intent docs
3. security/legal anchors (`SECURITY.md`, `LEGAL.md`, `LICENSE`)
4. architecture and protocol docs in `docs/`
5. machine-readable contracts in `specs/`
6. code surfaces (`core/`, `apps/`, `ops/`, `tools/`)

## 5) Evolution Rules

Electro Spatial RAG must evolve with the codebase.

Update this file when:
- architecture boundaries change
- canonical anchors change
- retrieval order or trust constraints change
- new subsystem families are added or removed

In the same change set, also update:
- `docs/SEED.md`
- `docs/AGENTS.md`
- `TASKS.md` (if execution process changed)

## 6) Agent Context Contract

Before edits:
- classify change type (architecture, stack, security, legal, product, messaging, ICP, operations)
- load relevant anchors
- collect repository evidence

After edits:
- verify citations and attribution paths
- refresh Mermaid/text architecture memory when structure changed
- validate SEED synchronization rules

## 7) Anti-Drift Controls

- no architecture claims without repository path evidence
- no speculative subsystem ownership without docs/spec references
- no completion state when SEED sync is missing for triggered categories
