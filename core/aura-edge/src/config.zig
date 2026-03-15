const std = @import("std");

pub const Config = struct {
    inbound_rate_per_ip_per_min: u32 = 100,
    max_connections_per_ip: u32 = 50,
    global_connection_cap: u32 = 5000,
    egress_max_bytes_per_sec: u64 = 50 * 1024 * 1024, // 50MB/s default
    egress_max_requests_per_sec: u32 = 100,

    allocator: std.mem.Allocator,
    upstreams: std.StringHashMap([]const u8),
    blocklist: std.StringHashMap(void),

    pub fn init(allocator: std.mem.Allocator) Config {
        return .{
            .allocator = allocator,
            .upstreams = std.StringHashMap([]const u8).init(allocator),
            .blocklist = std.StringHashMap(void).init(allocator),
        };
    }

    pub fn deinit(self: *Config) void {
        var it = self.upstreams.iterator();
        while (it.next()) |entry| {
            self.allocator.free(entry.key_ptr.*);
            self.allocator.free(entry.value_ptr.*);
        }
        self.upstreams.deinit();

        var b_it = self.blocklist.iterator();
        while (b_it.next()) |entry| {
            self.allocator.free(entry.key_ptr.*);
        }
        self.blocklist.deinit();
    }

    pub fn addUpstream(self: *Config, host: []const u8, target: []const u8) !void {
        const h = try self.allocator.dupe(u8, host);
        errdefer self.allocator.free(h);
        const t = try self.allocator.dupe(u8, target);
        try self.upstreams.put(h, t);
    }

    pub fn addBlockedIp(self: *Config, ip: []const u8) !void {
        const i = try self.allocator.dupe(u8, ip);
        try self.blocklist.put(i, {});
    }
};
