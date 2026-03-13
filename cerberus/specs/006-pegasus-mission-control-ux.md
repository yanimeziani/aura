# Spec 006 - Pegasus Mission Control UX for Cerberus VPS

## Status

Proposed

## Objective

Preserve Pegasus's current simplicity while adding a multi-pane operations experience for live agent monitoring, tool/thinking trails, logs, and steer controls, fully aligned with the Cerberus VPS runtime.

## Problem

Current Pegasus UX is clear and lightweight (dashboard, HITL queue, costs, terminal), but it is mostly poll-based and screen-by-screen. Operators need a single real-time view to:

- monitor agent behavior as it happens,
- understand execution context (tools, decisions, risk),
- steer work without losing safety controls,
- handle incidents quickly (cost spikes, blocked actions, panic mode).

## Product Direction

Use a two-mode UX:

1. **Simple Mode (default):** today’s Pegasus flow remains intact.
2. **Mission Control Mode (advanced):** multi-pane live operations view for power users.

This keeps onboarding easy and avoids forcing advanced controls on every user.

## Design Principles

1. **Calm by default** - critical alerts only; noise stays collapsed.
2. **Progressive disclosure** - summary first, deep logs/details on demand.
3. **Explainability over verbosity** - operator sees "what happened + why it matters."
4. **Safe steering** - all high-risk controls route through existing HITL/policy gates.
5. **Recoverability** - reconnect, replay, and audit trail are first-class.

## Primary Users

- **Operator (daily control):** watches runs, submits tasks, nudges direction.
- **Reviewer (HITL authority):** approves/rejects risky actions with context.
- **Incident commander (on-call):** reacts to failures/cost anomalies, toggles panic mode.

## Information Architecture

Top-level navigation:

1. **Overview** (existing dashboard)
2. **Mission Control** (new multi-pane real-time)
3. **Approvals** (existing HITL + richer detail)
4. **Costs & Policy** (existing costs + live guardrails)
5. **Terminal / Infra** (existing SSH + service status)
6. **Settings** (existing)

Core entities:

- **Agent** (`meziani-main`, `dragun-devsecops`, `dragun-growth`)
- **Session** (conversation/run context)
- **Task** (queued/executing/completed)
- **Trail Event** (tool/approval/cost/log/message)
- **Control Action** (steer/pause/resume/panic)

## Mission Control Layout

Reference desktop layout:

```
┌─────────────────────────────────────────────────────────────────────────────┐
│ Top Bar: env, relay status, panic state, cost burn rate, quick actions     │
├───────────────┬──────────────────────────────────┬──────────────────────────┤
│ Pane A        │ Pane B                           │ Pane C                   │
│ Agent Roster  │ Live Trail Timeline              │ Event Inspector          │
│ + Sessions    │ (messages/tools/approvals/logs)  │ + Raw Log / Diff / JSON  │
├───────────────┴──────────────────────────────────┴──────────────────────────┤
│ Pane D: Steer Console (nudge/constraints/interrupt/policy override request) │
└─────────────────────────────────────────────────────────────────────────────┘
```

### Pane A - Agent Roster and Session Tree

Shows:

- agent status (`running`, `idle`, `waiting_hitl`, `error`)
- current task summary
- last event time and health indicator
- queue depth and active approvals
- per-agent cost status

Actions:

- submit task
- focus/filter timeline by agent/session
- quick controls: pause agent, resume agent, open approvals, open terminal

### Pane B - Live Trail Timeline

A chronological stream with typed cards:

- `assistant_chunk` / `assistant_final`
- tool execution start/result
- approval requested/resolved
- policy block/warning
- cost updates and threshold crossings
- system errors and reconnect events

Display rules:

- auto-follow latest by default
- sticky "critical" cards pin to top
- compact mode collapses repetitive chunks/log lines
- filter chips: `messages`, `tools`, `approvals`, `cost`, `policy`, `errors`

### Pane C - Event Inspector

Selection-driven detail panel:

- event metadata (`agent_id`, `session_id`, `request_id`, `task_id`, timestamps)
- tool arguments/result (with secret redaction)
- diff preview and risk notes for approval events
- raw JSON payload toggle
- linked artifacts and correlated prior events

### Pane D - Steer Console

Unified control surface:

- **Nudge:** "continue but prioritize X"
- **Constraint:** "do not use shell/file_write for this run"
- **Redirect:** "switch objective to Y"
- **Interrupt:** pause/resume/abort current task
- **Escalate:** trigger panic mode or require extra approvals

All actions produce immutable audit events and visible acknowledgements.

## "Thinking" Visibility Model

Mission Control should expose execution intent without leaking unsafe/raw chain-of-thought.

- Show **decision breadcrumbs** (planned action, chosen tool, result summary).
- Show **reason labels** derived from policy/risk/tool outcomes.
- Keep full internal reasoning hidden unless explicitly allowed by policy and provider.

This keeps explainability high while respecting model and security constraints.

## Cerberus VPS Compatibility (Current State)

The conception intentionally builds on what already exists:

- Existing Pegasus REST compatibility:
  - `/auth/login`, `/auth/logout`
  - `/health`
  - `/agents`
  - `/hitl/*`
  - `/costs/*`
  - `/panic`
  - `/tasks/*`
- Existing WebChannel v1 for real-time chat path:
  - `pairing_request`, `pairing_result`
  - `user_message`
  - `assistant_chunk`, `assistant_final`
  - `error`
- Existing diagnostics/observability in Cerberus core:
  - tool call events
  - LLM request/response events
  - file/log observer backends

## Required Backend Additions for Full Mission Control

### 1) Event Multiplexer Service (inside pegasus-compat)

Add a real-time multiplexer that merges:

- WebChannel outbound events (`assistant_*`, errors)
- Cerberus observer events (tool/LLM lifecycle)
- HITL queue transitions (`pending` -> `approved`/`rejected`)
- cost records from `costs.jsonl`
- panic state transitions
- agent heartbeat changes

Output:

- `WS /events/ws` (primary stream)
- `GET /events/replay?cursor=...` (reconnect/recovery)

### 2) Canonical Event Envelope

Use one normalized schema across all panes:

```json
{
  "id": "evt_...",
  "ts": "2026-03-03T12:34:56.000Z",
  "kind": "tool.result",
  "severity": "info",
  "agent_id": "dragun-devsecops",
  "session_id": "web:default:direct:abc",
  "task_id": "task_123",
  "request_id": "req_7",
  "trace_id": "trc_...",
  "summary": "shell completed (exit 0)",
  "data": {},
  "redaction_level": "safe"
}
```

### 3) Steer Control API

Add explicit steer endpoints:

- `POST /steer`
- `POST /sessions/{session_id}/control`
- `POST /agents/{agent_id}/control`

Payload shape:

```json
{
  "mode": "nudge|constraint|redirect|pause|resume|abort|panic",
  "scope": "session|agent|global",
  "target_id": "optional",
  "instruction": "text",
  "ttl_s": 900,
  "reason": "operator note"
}
```

Responses should emit:

- `steer.accepted`
- `steer.applied`
- `steer.rejected` (with policy reason)

### 4) Trail Persistence

Store append-only event JSONL under `/data/cerberus/artifacts/trails/` with retention policy.

Needed for:

- replay after disconnect,
- investigation/postmortem,
- compliance/audit.

## UX Flows

### Flow A - Live Monitoring

1. Open Mission Control.
2. Select agent/session in Pane A.
3. Observe stream in Pane B with auto-follow.
4. Click events to inspect details in Pane C.

### Flow B - Approval Handling

1. `approval_request` card appears in timeline.
2. Pane C shows diff preview + risk labels + blast radius.
3. Reviewer approves/rejects.
4. Resolution event updates timeline and agent status immediately.

### Flow C - Steer In-Flight

1. Operator notices drift (cost/tool loop/risky behavior).
2. Sends steer action in Pane D.
3. UI receives acknowledgment and applied/rejected outcome.
4. Timeline marks "before/after steer" boundary for clarity.

### Flow D - Incident and Panic

1. Cost threshold or policy violation triggers critical event.
2. Global panic action available in top bar and Pane D.
3. Panic state broadcasts to all panes.
4. Recovery flow includes reason, owner, and clear-panic confirmation.

## Responsive Behavior

- **Desktop/Web:** full 4-pane Mission Control.
- **Tablet/Fold open:** 3 panes (Inspector as slide-over).
- **Phone/Fold closed:** tabbed stack (Roster -> Timeline -> Inspector -> Steer).

## Visual Language

Reuse Pegasus theme primitives:

- primary blue for navigation/live context,
- green for success/healthy,
- amber for warnings/HITL wait,
- red for errors/panic.

Card hierarchy:

- concise title + timestamp + agent badge,
- one-line summary,
- expandable details.

## Security and Governance

- Keep pairing/token auth modes from WebChannel v1.
- Enforce role-based control permissions (observe vs steer vs panic).
- Redact secrets in tool args/results by default.
- Log every steer and approval action as signed audit event when enabled.

## Performance Targets

- Event delivery p95: < 500 ms from backend to UI.
- UI stream render budget: 60 fps with virtualization.
- Reconnect recovery: < 2 s with cursor resume.
- Timeline memory cap with automatic archival window.

## Rollout Plan

### Phase 1 - Read-Only Real-Time

- Add event multiplexer + normalized stream.
- Build Pane A/B/C without steer controls.
- Keep existing dashboard/HITL/cost screens untouched.

### Phase 2 - Safe Steering

- Add steer APIs + Pane D actions.
- Enforce policy/HITL checks on risky controls.
- Add control acknowledgements and audit events.

### Phase 3 - Replay and Forensics

- Add event replay UI and session bookmarks.
- Add incident timeline exports.
- Add operator performance and MTTR dashboards.

## Acceptance Criteria

1. Mission Control shows real-time events for all active agents.
2. Operators can inspect tool calls, approvals, and errors without screen switching.
3. Steer actions are auditable and policy-gated.
4. Panic state is globally visible and actionable in under 1 second.
5. Existing Pegasus simple flows remain functional and unchanged by default.

## Open Questions

1. Should steer actions mutate persistent agent config or be session-scoped only?
2. Which roles are allowed to trigger global panic from mobile clients?
3. Do we need encrypted end-to-end payloads (`relay_e2e_required=true`) for Mission Control by default?
4. What retention period is required for trail replay in production (14/30/90 days)?
