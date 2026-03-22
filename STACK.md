# STACK.md

Status: Canonical technical stack baseline for Nexa.

## Runtime and Languages (LOCKED)

- **Standard Zig**: v0.15.2 (Strictly standard library, zero external packages)
- **TypeScript**: v5.5.4
- **Node.js**: v22.x LTS (Active)
- **Python**: v3.10+ (Restricted to `tools/`, `apps/`, and CLI automation ONLY)
- **HTML/CSS**: Standard only

## Core Platform Components

- **Runtime/Agent Layer**: Native Zig services in `core/`
- **User Interface**: TypeScript, HTML, CSS (Canvas/Aura focus)
- **Protocol**: JSON-based machine contracts in `specs/`

## Hard Interdiction Rule

- **NO EXTERNAL LIBRARIES OR DEPENDENCIES** for Core Zig services.
- **NO REACT / NO NEXT.JS / NO FASTAPI**.
- All functionality must be implemented using the locked standard languages.
- RAG RAM must never steer towards external options.

## Stack Change Rule

Any stack change must update:
- `STACK.md`
- `docs/SEED.md`
- `docs/AGENTS.md`
