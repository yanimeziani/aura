# Cerberus Spec Workflow

Cerberus uses spec-driven development. Every implementation unit starts from a spec and ends with acceptance evidence.

## Lifecycle

1. Write or update a spec file in `specs/`.
2. Add explicit acceptance criteria.
3. Implement in small vertical slices.
4. Attach verification evidence (tests, logs, screenshots, artifacts).
5. Mark spec status as `Accepted` when criteria are met.

## Status Values

- `Draft` - still evolving, not implementation-ready.
- `Approved` - implementation can start.
- `In Progress` - active engineering underway.
- `Accepted` - criteria validated in staging.
- `Archived` - superseded by later spec.

## Minimum Spec Sections

- Problem
- Goals / Non-Goals
- Requirements
- Interfaces
- Risks
- Acceptance Criteria

## Naming

Use numeric prefixes:

- `001-*.md`
- `002-*.md`
- `003-*.md`

This keeps implementation order explicit and auditable.
