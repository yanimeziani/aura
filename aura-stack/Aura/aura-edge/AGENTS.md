# Aura Edge — Agent Guidelines

Zig **0.15.2** edge server for the Aura stack: DDoS-style protection with **dynamic inbound filtering** and **outbound monitoring**. Repo Zig version: see `docs/ZIG_VERSION.md`, `.zig-version`.

## Skill

Use the **zig-ddos-protection** Agent Skill when working on this codebase:

- **Path**: `Aura/.agents/skills/zig-ddos-protection/`
- **Covers**: Dynamic filtering of incoming traffic (rate limits, blocklists, connection caps), close monitoring of outgoing traffic (counters, thresholds, allowlists), and integration with this binary.

Activate the skill for tasks such as: adding configurable rate limits, IP blocklists, egress tracking, or refactoring protection/egress into separate modules.

## Current state

- `src/main.zig`: HTTP server on `0.0.0.0:8080` with a simple per-IP rate limit (fixed 100/min).
- **TODO (skill-guided)**: Dynamic config, blocklist, connection limits; egress layer and monitoring; tests for limits and egress.

## Commands

```bash
zig build        # build
zig build run    # run server
zig build test   # tests
```

## References

- Skill reference: [.agents/skills/zig-ddos-protection/references/architecture.md](../.agents/skills/zig-ddos-protection/references/architecture.md)
