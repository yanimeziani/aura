# Aura Skills (tailored belt)

This repo supports a **skills belt** inspired by curated Claude Skills lists (e.g. “awesome-claude-skills”), but **tailored to Aura**:

- Safe ops and explicit escalation
- Sovereign Zig stack constraints (0.15.2, no external Zig deps)
- In-repo MCP and tool surfaces
- One CLI entrypoint (`aura`)

## Where skills live

- `skills/` — repo-local skills (versioned with Aura)
- `aura skill ...` — list/show/run helper

## Commands

```bash
aura skill list
aura skill show aura-safe-ops
aura skill run blitz-micro-launch
```

## Curation policy

- Prefer **instruction-only** skills first (lowest risk).
- Only add executable scripts when needed, and keep them auditable + minimal.
- No network exfiltration patterns, no secret scraping, no “download and run” behaviors.

## Blitzkrieg business belt (micro launches)

- `blitz-micro-launch` — 48h micro-launch loop + runnable plan scaffold
- `blitz-growth-wolf-teeth` — growth hacking primitives + KPI tree
- `blitz-micro-saas` — micro-SaaS scoping/pricing/retention/ops
- `blitz-offer-forge` — offer + copy skeletons
- `blitz-automation-orchestrator` — full-auto patterns (stub/systemd/checkpoints)
