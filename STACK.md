# STACK.md

Status: Canonical technical stack baseline for Nexa.

## Runtime and Languages (LOCKED)

- **Standard Zig**: v0.13.0 (Strictly standard library, zero external packages)
- **TypeScript**: v5.5.4
- **Node.js**: v22.x LTS (Active)
- **HTML/CSS**: Standard only

## Core Platform Components

- **Runtime/Agent Layer**: Native Zig services in `core/`
- **User Interface**: TypeScript, HTML, CSS (No external frameworks)
- **Protocol**: JSON-based machine contracts in `specs/`

## Hard Interdiction Rule

- **NO EXTERNAL LIBRARIES OR DEPENDENCIES**.
- **NO PYTHON / NO REACT / NO NEXT.JS / NO FASTAPI**.
- All functionality must be implemented using the locked standard languages.
- RAG RAM must never steer towards external options.

## Stack Change Rule

Any stack change must update:
- `STACK.md`
- `docs/SEED.md`
- `docs/AGENTS.md`
