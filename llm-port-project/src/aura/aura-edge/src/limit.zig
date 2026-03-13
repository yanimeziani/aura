const std = @import("std");
const testing = std.testing;

pub const RateLimiter = struct {
    allocator: std.mem.Allocator,
    max_requests_per_second: u32,
    max_concurrent_connections: u32,
    current_connections: u32 = 0,
    requests: std.AutoHashMap([4]u8, u64), // IP to last request timestamp

    pub fn init(allocator: std.mem.Allocator, max_requests: u32, max_conns: u32) RateLimiter {
        return .{
            .allocator = allocator,
            .max_requests_per_second = max_requests,
            .max_concurrent_connections = max_conns,
            .requests = std.AutoHashMap([4]u8, u64).init(allocator),
        };
    }

    pub fn deinit(self: *RateLimiter) void {
        self.requests.deinit();
    }

    pub fn acceptConnection(self: *RateLimiter) bool {
        if (self.current_connections >= self.max_concurrent_connections) return false;
        self.current_connections += 1;
        return true;
    }

    pub fn closeConnection(self: *RateLimiter) void {
        if (self.current_connections > 0) self.current_connections -= 1;
    }

    pub fn checkRate(self: *RateLimiter, ip: [4]u8, timestamp: u64) !bool {
        const last_req = self.requests.get(ip) orelse 0;
        if (timestamp < last_req + (std.time.ms_per_s / self.max_requests_per_second)) {
            return false;
        }
        try self.requests.put(ip, timestamp);
        return true;
    }
};

test "RateLimiter connection bounding" {
    const allocator = testing.allocator;
    var limiter = RateLimiter.init(allocator, 10, 2);
    defer limiter.deinit();

    try testing.expect(limiter.acceptConnection());
    try testing.expect(limiter.acceptConnection());
    try testing.expect(!limiter.acceptConnection());

    limiter.closeConnection();
    try testing.expect(limiter.acceptConnection());
}

test "RateLimiter rate limiting" {
    const allocator = testing.allocator;
    var limiter = RateLimiter.init(allocator, 1, 10);
    defer limiter.deinit();

    const ip = [4]u8{ 127, 0, 0, 1 };
    try testing.expect(try limiter.checkRate(ip, 1000));
    try testing.expect(!(try limiter.checkRate(ip, 1500))); // Still within same second
    try testing.expect(try limiter.checkRate(ip, 2500)); // Next second
}
