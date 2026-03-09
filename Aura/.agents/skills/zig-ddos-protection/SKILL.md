---
name: zig-ddos-protection
description: Zig-based DDoS protection with dynamic filtering of incoming traffic and close monitoring of outgoing traffic. Use when implementing or extending edge protection, rate limiting, IP/request filtering, egress monitoring, or sovereign edge security in Zig (e.g. Aura Edge). Covers dynamic rules, connection limits, anomaly detection, and outbound traffic visibility.
compatibility: Aura locks to Zig 0.15.2 only (see docs/ZIG_VERSION.md, .zig-version). Optional libc for getpeername/socket details. Intended for Aura and Cursor/Claude Code.
metadata:
  author: Aura
  version: "1.0"
  scope: aura-edge
---

# Zig DDoS Protection — Dynamic Inbound Filtering & Outbound Monitoring

Use this skill when building or modifying Zig edge services that must **filter incoming traffic dynamically** and **monitor outgoing traffic closely**. The goal is Cloudflare-style protection with full visibility: block or throttle bad actors on the way in, and detect anomalies or abuse on the way out.

## When to activate

- Implementing or extending **Aura Edge** (`aura-edge/`) or any Zig TCP/HTTP edge.
- Adding **dynamic inbound filtering** (rate limits, IP reputation, request patterns, connection caps).
- Adding **egress monitoring** (outgoing request volume, destinations, payload size, anomaly alerts).
- Designing **sovereign edge** security: your box, your rules, your metrics.

## Core principles

1. **Inbound: dynamic filtering** — Rules and thresholds can change at runtime (config reload, admin API, or heuristic updates). No hardcoded-only limits.
2. **Outbound: close monitoring** — Every egress connection or request is counted, optionally logged or sampled, and checked against policy (allowlist, rate, size).
3. **Single binary, minimal deps** — Prefer Zig stdlib and a small set of well-defined structures; avoid pulling in heavy runtimes.
4. **Fail closed** — On allocator failure, config parse error, or unknown state, prefer deny/drop over allow.

---

## 1. Dynamic filtering of incoming traffic

### 1.1 What “dynamic” means

- **Rate limits** that can be updated without restart (e.g. per-IP, per-path, or global).
- **Block/allow lists** (IP, CIDR, or identifiers) that can be reloaded from file or in-memory store.
- **Request-level rules** — method, path, header patterns, body size — applied per request and configurable.
- **Connection limits** — max concurrent per IP or per server, with optional slow-start or backoff.

### 1.2 Implementation checklist (Zig)

- Use a **single allocator** for all protection state (e.g. `GeneralPurposeAllocator`) and bound growth (max entries, TTL, eviction).
- **Per-IP state**: key = client IP (or normalized form); value = counters + last reset time. Evict stale entries (e.g. no traffic for N seconds).
- **Time windows**: use `std.time.timestamp()` for reset; support multiple windows (e.g. 1m, 1h) if needed.
- **Threading**: if you use threads, protect shared state with mutex or use per-thread shards keyed by IP hash.
- **Extract real client IP** from the first hop (e.g. `X-Forwarded-For` or `CF-Connecting-IP` when behind a proxy); document which header you trust.

### 1.3 Response to violations

- **429 Too Many Requests** for rate limit exceeded; optional `Retry-After`.
- **403 Forbidden** for explicit block (IP or rule).
- **503 Service Unavailable** if the server is in overload (e.g. connection limit reached).
- Log refusals (at least: timestamp, client IP, reason, optional key) for tuning and forensics.

---

## 2. Close monitoring of outgoing traffic

### 2.1 Why monitor egress

- **Data exfiltration** — Unusual outbound volume or destinations.
- **Abuse of your edge** — Your server used as proxy or amplifier; outbound requests to unexpected hosts.
- **Capacity and cost** — Bandwidth and connection usage per backend or endpoint.
- **Compliance** — Evidence of what left the network and when.

### 2.2 What to track (minimal)

- **Per-destination** (host or IP:port): request count, byte count, last time.
- **Global egress**: total bytes and request count in a sliding or fixed window.
- **Thresholds**: alert or throttle when outbound rate or volume exceeds a configured cap.
- Optional: sample or log a fraction of outbound requests (URL, host, size, status).

### 2.3 Implementation checklist (Zig)

- **Intercept outbound calls** at a single layer (e.g. a wrapper around `std.net` connect or your HTTP client). Every outbound connection goes through this layer.
- **Counters**: use atomic or mutex-protected counters; avoid allocs on hot path if possible.
- **Config**: max egress rate (bytes/s or requests/s), allowed hosts or allowlist, max payload size per request.
- **Actions**: log, metric export, or hard block when over threshold; prefer configurable action.
- **Storage**: in-memory is enough for “close monitoring”; persist only if you need audit logs (e.g. append-only file or external sink).

---

## 3. Integration with Aura Edge

The Aura repo already has a Zig edge in `aura-edge/` with a basic **incoming** rate limit (see `src/main.zig`). When extending it:

- **Keep** the existing `ProtectionLayer` pattern; extend it with configurable limits and dynamic rules (see [references/architecture.md](references/architecture.md)).
- **Add** egress tracking in the same binary: wrap any code that opens outbound connections (e.g. to backends or APIs) and pass through a central `EgressMonitor`.
- **Config**: prefer one config file or env (e.g. `config.json` or env vars) for limits, blocklists, and egress caps; support reload.
- **Logging**: use `std.log` or a minimal logger; ensure refusals and egress alerts are visible (e.g. stderr or a log file).

See [references/architecture.md](references/architecture.md) for suggested modules and data structures.

---

## 4. Commands and testing

```bash
# Build
cd aura-edge && zig build

# Run (listens on 0.0.0.0:8080 by default)
zig build run

# Tests
zig build test
```

After adding dynamic filtering or egress monitoring, add tests for: allowed request under limit, refused request over limit, blocklist, and egress over threshold.

---

## 5. Edge cases

- **No client IP** (e.g. missing headers): treat as single anonymous client or use connection peer address; document behavior.
- **Clock skew**: rate windows use server clock; NTP or sync is recommended.
- **Restart**: in-memory state is lost; acceptable for first version; later add optional persistence or startup load.
- **Egress from multiple threads**: use atomics or a single dedicated egress thread with a channel to avoid races.

---

## Quick reference

| Concern | Inbound | Outbound |
|--------|---------|----------|
| Rate limit | Per IP/path, configurable | Per destination / global cap |
| Block/allow | IP/CIDR, reloadable | Host allowlist, optional blocklist |
| Metrics | Refusals, top IPs | Bytes/requests per destination, totals |
| Response | 429/403/503 + log | Log + optional throttle or block |

Use [references/architecture.md](references/architecture.md) for concrete Zig types and file layout.
