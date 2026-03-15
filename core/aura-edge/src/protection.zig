const std = @import("std");
const Config = @import("config.zig").Config;

pub const ProtectionLayer = struct {
    pub const PerIpEntry = struct {
        count: u32,
        last_reset: i64,
        connections: u32 = 0,
    };

    allocator: std.mem.Allocator,
    registry: std.StringHashMap(PerIpEntry),
    mutex: std.Thread.Mutex,
    config: *const Config,
    global_connections: u32 = 0,

    pub fn init(allocator: std.mem.Allocator, config: *const Config) ProtectionLayer {
        return .{
            .allocator = allocator,
            .registry = std.StringHashMap(PerIpEntry).init(allocator),
            .mutex = std.Thread.Mutex{},
            .config = config,
        };
    }

    pub fn deinit(self: *ProtectionLayer) void {
        var it = self.registry.iterator();
        while (it.next()) |entry| {
            self.allocator.free(entry.key_ptr.*);
        }
        self.registry.deinit();
    }

    pub fn checkConnection(self: *ProtectionLayer, ip: []const u8) !bool {
        self.mutex.lock();
        defer self.mutex.unlock();

        if (self.config.blocklist.contains(ip)) return false;

        if (self.global_connections >= self.config.global_connection_cap) return false;

        const now = std.time.timestamp();
        var entry = self.registry.get(ip) orelse PerIpEntry{ .count = 0, .last_reset = now };

        if (entry.connections >= self.config.max_connections_per_ip) return false;

        if (now - entry.last_reset > 60) {
            entry.count = 0;
            entry.last_reset = now;
        }

        entry.count += 1;
        entry.connections += 1;

        if (entry.count > self.config.inbound_rate_per_ip_per_min) {
            entry.connections -= 1; // Revert connection since it's rejected
            try self.putEntry(ip, entry);
            return false;
        }

        self.global_connections += 1;
        try self.putEntry(ip, entry);
        return true;
    }

    pub fn closeConnection(self: *ProtectionLayer, ip: []const u8) void {
        self.mutex.lock();
        defer self.mutex.unlock();

        if (self.global_connections > 0) self.global_connections -= 1;

        if (self.registry.getPtr(ip)) |entry| {
            if (entry.connections > 0) entry.connections -= 1;
        }
    }

    fn putEntry(self: *ProtectionLayer, ip: []const u8, entry: PerIpEntry) !void {
        if (!self.registry.contains(ip)) {
            const ip_dupe = try self.allocator.dupe(u8, ip);
            try self.registry.put(ip_dupe, entry);
        } else {
            try self.registry.put(ip, entry);
        }
    }
};
