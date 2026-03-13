const std = @import("std");
const Config = @import("config.zig").Config;

pub const EgressMonitor = struct {
    pub const HostCounters = struct {
        bytes: u64 = 0,
        requests: u64 = 0,
        last_ts: i64 = 0,
    };

    allocator: std.mem.Allocator,
    config: *const Config,
    total_bytes: std.atomic.Value(u64),
    total_requests: std.atomic.Value(u64),
    
    per_host: std.StringHashMap(HostCounters),
    mutex: std.Thread.Mutex,

    pub fn init(allocator: std.mem.Allocator, config: *const Config) EgressMonitor {
        return .{
            .allocator = allocator,
            .config = config,
            .total_bytes = std.atomic.Value(u64).init(0),
            .total_requests = std.atomic.Value(u64).init(0),
            .per_host = std.StringHashMap(HostCounters).init(allocator),
            .mutex = std.Thread.Mutex{},
        };
    }

    pub fn deinit(self: *EgressMonitor) void {
        var it = self.per_host.iterator();
        while (it.next()) |entry| {
            self.allocator.free(entry.key_ptr.*);
        }
        self.per_host.deinit();
    }

    pub fn recordEgress(self: *EgressMonitor, host: []const u8, bytes: u64) !void {
        _ = self.total_bytes.fetchAdd(bytes, .monotonic);
        _ = self.total_requests.fetchAdd(1, .monotonic);

        self.mutex.lock();
        defer self.mutex.unlock();

        const now = std.time.timestamp();
        var counters = self.per_host.get(host) orelse HostCounters{ .last_ts = now };

        // Simple 1-second reset window for per-host rate limiting
        if (now - counters.last_ts > 1) {
            counters.bytes = 0;
            counters.requests = 0;
            counters.last_ts = now;
        }

        counters.bytes += bytes;
        counters.requests += 1;

        if (!self.per_host.contains(host)) {
            const host_dupe = try self.allocator.dupe(u8, host);
            try self.per_host.put(host_dupe, counters);
        } else {
            try self.per_host.put(host, counters);
        }

        // Check limits
        if (counters.bytes > self.config.egress_max_bytes_per_sec or counters.requests > self.config.egress_max_requests_per_sec) {
            std.debug.print("⚠️ Egress limit exceeded for host: {s}\n", .{host});
            // Here we could return an error to drop the connection
            // return error.EgressLimitExceeded;
        }
    }
};
