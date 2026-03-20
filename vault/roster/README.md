# Roster communications channel

## Purpose

Single **fluid markdown communications channel** for the attack team: coordination, task claim, status, blockers, handoff. All roles post and read.

## Channel file

- **Path:** `vault/roster/CHANNEL.md`
- **Format:** Append-only. Each post is markdown. Suggested first line: `[Role] [Fnn] optional subject` or `[Role] optional subject`, then body. Add timestamp if useful (e.g. `2025-03-09 14:00`).
- **Access:** All roles (Lead, Runner, Implementer, Reviewer, Scout) have full read/write. No restriction.

## Example post

```markdown
---
[Implementer] [F05] ziggy-compiler main.zig stub done. Verify: zig build && ./zig-out/bin/ziggyc --version
---
```

Use the channel to run in parallel: claim tasks, report done, ask for review, post blockers, announce overnight run or checkpoint.
