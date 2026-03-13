# Zig DDoS Protection — Architecture Reference

Suggested layout and types for dynamic inbound filtering and outbound monitoring in Aura Edge.

## Module layout (aura-edge)

```
aura-edge/src/
  main.zig           # Entry, server loop, handleConnection
  root.zig            # Library surface (optional shared types)
  protection.zig      # Inbound: ProtectionLayer, rate limit, blocklist, dynamic config
  egress.zig          # Outbound: EgressMonitor, counters, thresholds, allowlist
  config.zig          # Load/reload config (limits, lists, egress caps)
```

## Inbound: protection.zig (conceptual)

- **ProtectionLayer**
  - `registry: std.StringHashMap(PerIpEntry)` — IP → { count, window_start, (optional) blocked }
  - `blocklist: std.StringHashMap(void)` or CIDR trie — set of blocked IPs/CIDRs
  - `limits: Limits` — max req/min per IP, max connections per IP, global connection cap
  - `mutex: std.Thread.Mutex` if shared across threads
- **PerIpEntry**: count, last_reset_ts, optional first_seen_ts for connection limiting
- **Dynamic update**: function to apply new Limits or new blocklist (replace or merge); evict stale IPs from registry periodically
- **Eviction**: on each request (or background), remove entries where `now - last_reset > window_sec` and count is 0, or use a cap on registry size with LRU-style eviction

## Outbound: egress.zig (conceptual)

- **EgressMonitor**
  - `counters: struct { total_bytes: Atomic(u64), total_requests: Atomic(u64), per_host: StringHashMap(HostCounters) }`
  - `limits: EgressLimits` — max bytes/s, max requests/s, max per-host, allowlist (optional)
  - `mutex: std.Thread.Mutex` for per_host map (or lock-free per-host atomics if you prefer)
- **HostCounters**: bytes, requests, last_ts (for rate)
- **Before connect**: `checkAllow(host: []const u8) bool` — allowlist/blocklist
- **After write/close**: `recordEgress(host: []const u8, bytes: u64) void` — update totals and per-host; if over threshold, log and optionally trigger action
- **Threshold check**: on each record, if global or per-host rate > limit, log alert and optionally refuse further outbound (fail closed)

## Config (config.zig)

- **Limits**: inbound_rate_per_ip_per_min, max_connections_per_ip, max_global_connections, blocklist_path (optional), egress_max_bytes_per_sec, egress_max_requests_per_sec, egress_allowlist (optional).
- Load from file (JSON or custom) or env; expose `reload()` to re-read file or accept in-memory update.
- Defaults: conservative (low rate, small connection cap) so that missing config does not open the door.

## Data flow

1. **Inbound**: Accept → get client IP → ProtectionLayer.isAllowed(ip) → if no, send 429/403 and log → if yes, handle request → (if backend call) EgressMonitor.recordEgress(...).
2. **Outbound**: Before connect → EgressMonitor.checkAllow(host) → if no, return error → connect → after write → EgressMonitor.recordEgress(host, bytes) → check thresholds → log/alert if over.

## Dependencies

- Zig std: `std.net`, `std.time`, `std.Thread`, `std.atomic`, `std.StringHashMap`, `std.fs`, `std.json` (if JSON config).
- No external C libs required for first version; optional libc only if you need getpeername or platform-specific socket options.
