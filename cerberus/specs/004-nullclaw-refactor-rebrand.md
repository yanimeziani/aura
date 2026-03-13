# Spec 004 - NullClaw Refactor and Full Rebrand

## Status

In Progress

## Problem

Cerberus needs to inherit NullClaw engineering quality and performance while fully rebranding identity and command surface for internal use.

## Goals

- Bootstrap Cerberus from upstream NullClaw in a repeatable way.
- Rebrand all user-facing NullClaw tokens to Cerberus.
- Keep build/test structure intact to avoid runtime regressions.
- Provide compatibility shim for legacy `nullclaw` command usage during transition.

## Requirements

1. Upstream source snapshot is pinned (repo/ref/commit metadata).
2. Rebrand pass is automated (not manual edits).
3. Build metadata renames binary to `cerberus`.
4. Integrity checks report residual legacy tokens.
5. Backward command shim exists at `scripts/compat/nullclaw`.

## Non-Goals

- Immediate semantic refactor of all architecture modules.
- Replacing upstream test suite with custom tests in this phase.
- API redesign in this phase.

## Acceptance Criteria

- `runtime/cerberus-core` generated successfully by bootstrap script.
- `build.zig` executable name is `cerberus`.
- `build.zig.zon` package name is `.cerberus`.
- Compatibility shim is executable.
- Branding audit file is generated and reviewed.
