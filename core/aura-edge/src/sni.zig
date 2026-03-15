const std = @import("std");
const testing = std.testing;

pub const SniManager = struct {
    allocator: std.mem.Allocator,
    certs: std.StringHashMap([]const u8),

    pub fn init(allocator: std.mem.Allocator) SniManager {
        return .{
            .allocator = allocator,
            .certs = std.StringHashMap([]const u8).init(allocator),
        };
    }

    pub fn deinit(self: *SniManager) void {
        var iter = self.certs.iterator();
        while (iter.next()) |entry| {
            self.allocator.free(entry.key_ptr.*);
            self.allocator.free(entry.value_ptr.*);
        }
        self.certs.deinit();
    }

    pub fn addCertificate(self: *SniManager, hostname: []const u8, cert_data: []const u8) !void {
        const key = try self.allocator.dupe(u8, hostname);
        const value = try self.allocator.dupe(u8, cert_data);
        try self.certs.put(key, value);
    }

    pub fn getCertificate(self: SniManager, hostname: []const u8) ?[]const u8 {
        return self.certs.get(hostname);
    }
};

test "SniManager basic operations" {
    const allocator = testing.allocator;
    var manager = SniManager.init(allocator);
    defer manager.deinit();

    try manager.addCertificate("example.com", "CERT_FOR_EXAMPLE");
    try manager.addCertificate("test.org", "CERT_FOR_TEST");

    try testing.expectEqualStrings("CERT_FOR_EXAMPLE", manager.getCertificate("example.com").?);
    try testing.expectEqualStrings("CERT_FOR_TEST", manager.getCertificate("test.org").?);
    try testing.expect(manager.getCertificate("notfound.com") == null);
}
