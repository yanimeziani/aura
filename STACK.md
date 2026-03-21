# STACK.md

Status: Canonical technical stack baseline for Nexa.

## Runtime and Languages

- Zig
- Python
- TypeScript
- JavaScript
- Bash

## Core Platform Components

- Web/app layer: Next.js, React
- Gateway/API layer: FastAPI
- Runtime/agent layer: Zig services in `core/`
- Automation/deploy layer: shell scripts and ops tooling in `ops/`

## Tooling Baseline

- Node.js workspace management (`package.json`, lockfiles)
- Make-based release and verification entrypoints
- Spec-first architecture with machine-readable contracts in `specs/`

## Stack Change Rule

Any stack change must update:
- `STACK.md`
- `docs/SEED.md`
- relevant implementation docs in `docs/`
