# Cerberus <-> Pegasus Integration

This document describes how Cerberus (Zig runtime) and Pegasus (Android app + this API) work together.

## Architecture

```
Pegasus (Android) --> Pegasus API (FastAPI) --> Cerberus Runtime (Zig)
                          |
                          +-- File-based state: agent_state, costs, hitl-queue, task-queue, trails
```

## Current Data Flow

- **Pegasus (Android)** talks exclusively to the **Pegasus API** (this FastAPI app). It does not call the Cerberus gateway directly.
- **Pegasus API** reads/writes files under `CERBERUS_BASE_DIR` (default `/data/cerberus`): config, `artifacts/agent_state.json`, `artifacts/costs.jsonl`, `hitl-queue/`, `task-queue/`, `artifacts/trails/`, etc.
- **Cerberus runtime** runs independently. Integration between the runtime and this API is via shared filesystem and (future) direct HTTP calls.

## What Works Today

- Login, health check, agent list with primary agent ordering
- Start/stop agents (writes to task-queue and updates agent_state)
- SSE stream with periodic heartbeats (app shows "Connected")
- HITL queue (submit, list, approve, reject)
- Cost tracking with per-agent caps and automatic panic trigger
- Panic mode (manual trigger, automatic threshold, clear)
- Task submission from chat and message UI
- Event replay and WebSocket streaming via EventHub
- Primary agent configurable via `PEGASUS_PRIMARY_AGENT_ID`

## What Requires Cerberus Runtime Integration

1. **Cerberus -> Pegasus API heartbeats**
   - Cerberus does not yet call `POST /agents/{id}/heartbeat` or `POST /events/ingest`
   - Agent status in Pegasus only updates on user Start/Stop actions
   - **Fix:** Cerberus daemon loop or sidecar that periodically pushes heartbeats and observer events

2. **Task queue consumption**
   - "Start agent" writes to `task-queue/{agent_id}.jsonl` but Cerberus does not read this queue
   - **Fix:** Script, systemd unit, or Cerberus gateway wrapper that polls task-queue and starts agents

3. **Event pipeline**
   - Tool calls, LLM requests, and errors from Cerberus do not appear in the event stream yet
   - **Fix:** Push Cerberus observer events to `POST /events/ingest`

## Environment Variables

| Variable | Default | Purpose |
|----------|---------|---------|
| `PEGASUS_ADMIN_USERNAME` | `yani` | Admin username for login |
| `PEGASUS_ADMIN_PASSWORD` | `cerberus2026` | Admin password (change in production) |
| `PEGASUS_ADMIN_ROLE` | `admin` | Default role for admin user |
| `PEGASUS_PRIMARY_AGENT_ID` | `meziani-main` | Primary agent shown first in Pegasus |
| `PEGASUS_STREAM_HEARTBEAT_SEC` | `2.0` | SSE heartbeat interval (seconds) |
| `PEGASUS_EVENTS_BUFFER_LIMIT` | `4000` | In-memory event buffer size |
| `PEGASUS_EVENTS_REPLAY_DEFAULT_LIMIT` | `200` | Default replay batch size |
| `PEGASUS_EVENTS_REPLAY_MAX_LIMIT` | `1000` | Maximum replay batch size |
| `PEGASUS_EVENTS_WS_POLL_SECS` | `0.5` | WebSocket poll interval |
| `PEGASUS_TRAIL_RETENTION_DAYS` | `30` | Event trail file retention |
| `CERBERUS_BASE_DIR` | `/data/cerberus` | Root data directory |
| `CERBERUS_CONFIG_FILE` | `{BASE_DIR}/.cerberus/config.json` | Agent config for deriving agent list |
| `DAILY_SPEND_CAP_USD` | `8.00` | Global daily spend cap |
| `DAILY_CAP_DEVSECOPS_USD` | `3.00` | DevSecOps agent daily cap |
| `DAILY_CAP_GROWTH_USD` | `2.00` | Growth agent daily cap |
| `DAILY_CAP_MEZIANI_MAIN_USD` | `3.00` | Main agent daily cap |
| `PANIC_THRESHOLD_USD` | `7.50` | Auto-panic cost threshold |
