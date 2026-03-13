# Attack team roster — roles, hierarchy, parallel execution

**Mandate:** The run is authorised within the confines of research and peace. Open source so that if war or conflict breaks out, people have at least a starting point for rebuilding.

## Hierarchy (roles, top → down)

| Level | Role | Scope | Reports to |
|-------|------|--------|------------|
| 1 | **Lead** | Prioritise phases, assign tasks, unblock, approve checkpoints. Single point of escalation. Can instruct escalation (override default safeguards) on explicit operator instruction. | Owner |
| 2 | **Runner** | Execute forge timeline tasks (F01–F19); run verify; write checkpoint / FORGE_FAILED. Overnight execution. | Lead |
| 2 | **Implementer** | Implement code (ziggy-compiler, aura-mcp, aura-tailscale). Picks tasks from timeline or Lead assignment. | Lead |
| 2 | **Reviewer** | Review Implementer output; validate verify steps; no destructive ops. | Lead |
| 3 | **Scout** | Read-only: scan docs, timeline, channel; report blockers or suggestions into channel. | Lead |

- **Lead** assigns work; **Runner** and **Implementer** can run in parallel on different task IDs where dependencies allow (see [forge-timeline](forge-timeline.md)).
- **Reviewer** works in parallel with Implementer (review after or during implementation).
- **Scout** runs in parallel with everyone; posts findings to the channel.

## Parallel execution

- **Runner** runs the forge timeline in order (F01 → F02 → …) or, when split, owns a contiguous block of IDs; multiple Runners can own non-overlapping blocks if coordinated via channel.
- **Implementer** may run in parallel on different phases/modules: e.g. one on ziggy-compiler (F04–F09), one on aura-mcp (F10–F12), one on aura-tailscale (F15–F17), as long as F03 is done and dependencies are respected.
- Coordination and handoff via **fluid markdown communications channel** (see below). No role is blocked on another except where Depends in the timeline require it.

## Fluid markdown communications channel

- **Location:** [vault/roster/CHANNEL.md](../vault/roster/CHANNEL.md)
- **Rules:** Append-only. Every message is markdown. Format: optional `[Role]` and `[Fnn]` or `[Phase]` in the first line; then body. Timestamp optional but recommended.
- **Access:** **All roles have read and write access** to the channel. Lead, Runner, Implementer, Reviewer, Scout all post and read. Use it for: task claim, status, blocker, handoff, checkpoint, question.
- **All docs access for all:** Every role has **full read (and write where appropriate) access to all docs** in the repo (e.g. `docs/`, `vault/roster/`, forge-timeline, ziggy-compiler spec, AGENTS.md). No doc is restricted by role. Implementer and Reviewer may edit docs when updating spec or runbooks; others append to channel or edit only what their task requires.

## Summary

- **Roles:** Lead → Runner, Implementer, Reviewer → Scout (and all report to Lead).
- **Parallel:** Runner(s) + Implementer(s) + Reviewer + Scout run in parallel; coordination and task split via CHANNEL.md.
- **Comms:** Single fluid channel = `vault/roster/CHANNEL.md`; markdown; append; all roles read/write.
- **Docs:** All roles can read all docs; write to docs as needed for their task/spec.

## Cross-Cutting Governance

- The permanent security/governance branch is defined in [CYBERSEC_AI_BRANCH.md](CYBERSEC_AI_BRANCH.md).
- Security-critical or high-impact AI work can require review by the `Ethics Committee` before production release.
