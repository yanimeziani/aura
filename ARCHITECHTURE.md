# Project Architecture

Status: Canonical real-time architecture map for Nexa.

## System Overview (Mermaid)

```mermaid
graph TD
    subgraph Governance ["Governance & Memory Plane"]
        SEED["docs/SEED.md"]
        AGENTS["docs/AGENTS.md"]
        FORGE["docs/FORGE_24H_PLAN.md"]
        WORLD["docs/MESH_WORLD_MODEL.md"]
        TASKS["TASKS.md"]
    end

    subgraph Product ["Product & Protocol Truth"]
        PRD["PRD.md"]
        DISTILL["docs/ARCHITECTURE_DISTILL.md"]
        SPECS["specs/ (JSON Contracts)"]
        RESEARCH["research/ (Prototypes/Papers)"]
    end

    subgraph Runtime ["Runtime & Delivery"]
        APPS["apps/ (Operator/Public)"]
        CORE["core/ (Runtime & Native)"]
        OPS["ops/ (Automation/Recovery)"]
        TOOLS["tools/ (CLI/Support)"]
        VAULT["vault/ (Encrypted Secrets)"]
    end

    subgraph Legal ["Legal & Public Interface"]
        LICENSE["LICENSE.md"]
        LEGAL["LEGAL.md"]
        MARKETING["MARKETING.md"]
        ICP["ICP.md"]
    end

    SEED --> AGENTS
    SEED --> FORGE
    SEED --> WORLD
    SEED --> PRD
    PRD --> DISTILL
    DISTILL --> SPECS
    RESEARCH --> DISTILL
    CORE --> APPS
    CORE --> OPS
    TOOLS --> CORE
    VAULT --> CORE
    VAULT --> OPS
    LEGAL --> LICENSE
    ICP --> MARKETING
```

## Architectural Layers

1.  **Identity and Trust**: Managed via `specs/trust.json`.
2.  **Transport and Routing**: Defined in `specs/protocol.json`.
3.  **State and Recovery**: `specs/recovery.json` and `ops/`.
4.  **Execution and Coordination**: `core/` runtime and forge packets.
5.  **Applied Sovereignty Domains**: `docs/MESH_WORLD_MODEL.md`.
6.  **Operator Interfaces**: `apps/` and `tools/`.

## Agentic Operations

Nexa operates as a protocol-first system where agents follow the **Layer-0 Spec-RAG Contract** defined in `docs/SEED.md`.
- **Planning**: Forge packets in `TASKS.md` or dedicated forge docs.
- **Execution**: Context-aware runs mapping to explicit packet criteria.
- **Memory**: Synchronized writeback to markdown canonical anchors.
