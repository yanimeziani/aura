---
name: aura-safe-ops
description: Aura default operating mode: safe ops, escalation rules, and guardrails.
---

## Objective

Keep Aura work safe, repeatable, and “operator-led”.

## Rules (tailored to Aura)

- **Safe by default**: no destructive or irreversible operations.
- **Escalate only on explicit instruction**: if the operator explicitly asks for destructive/privileged actions, it’s permitted—otherwise do safe alternatives.
- **No secrets leakage**: never print or commit credentials; keep secrets in `vault/` and env vars.
- **Zig sovereignty**: Zig components must stay on **Zig 0.15.2** and avoid external Zig deps.

## Standard workflow

- **Discover**: read docs, inspect codepaths, identify minimal change.
- **Implement**: small diffs, prefer new files over risky edits.
- **Verify**: run the smallest meaningful check (build/run a CLI subcommand).
- **Document**: update `docs/` or drop notes into `vault/docs_inbox/docs/` and run `aura docs-maid sweep`.
