# Spec 001 - Cerberus Platform Charter

## Status

Draft

## Problem

The previous orchestration stack (OpenClaw) was heavier than desired and tightly coupled to Python orchestration patterns. We need a lean, Zig-based runtime that preserves operational discipline while reducing platform overhead.

## Goals

- Build Cerberus as a private Null Claw fork with internal branding and ownership.
- Keep the two-agent operating model (`devsecops`, `growth`).
- Preserve existing prompts, risk taxonomy, HITL gates, and MCP integration.
- Preserve Claude Pro (`claude` CLI OAuth) as the model execution path.
- Support deterministic, scriptable VPS deployment.

## Non-Goals

- Public SaaS packaging.
- Multi-tenant auth in v1.
- Replacing Claude Pro with a different provider in v1.

## Functional Requirements

1. Cerberus can execute queued tasks per agent and emit artifacts.
2. Cerberus enforces per-task and daily spend controls.
3. Cerberus supports HITL submission, polling, and approval blocking.
4. Cerberus supports MCP server configuration equivalent to the prior stack.
5. Cerberus preserves queue and artifact paths under `/data/cerberus`.

## Interface Requirements

- Agent input: structured JSON task envelope (id, agent_id, description, metadata).
- Agent output: markdown artifact + machine-readable status record.
- Tool protocol: explicit tool calls and completion signal.

## Operational Requirements

- Containers must run non-root by default.
- Startup must fail safe when Claude auth is missing.
- All logs structured and retained for 14+ days.

## Acceptance Criteria

- `devsecops` and `growth` prompts load without content changes.
- Existing MCP server definitions run with path updates only.
- Claude OAuth flow works via mounted host auth directory.
- One end-to-end task per agent succeeds on staging VPS.
