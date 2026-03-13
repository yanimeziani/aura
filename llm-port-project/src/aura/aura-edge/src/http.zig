//! HTTP/1.1 parsing — aura-edge. Zig 0.15.2 + std only.
//! Minimal parser for request line and headers.

const std = @import("std");

pub const Request = struct {
    method:  []const u8,
    path:    []const u8,
    version: []const u8,
    headers: std.StringHashMap([]const u8),

    /// Parse a single HTTP request from a reader.
    pub fn parse(allocator: std.mem.Allocator, reader: anytype) !Request {
        var line_buf: [1024]u8 = undefined;
        
        // 1. Request Line: METHOD PATH VERSION
        const first_line = (try reader.readUntilDelimiterOrEof(&line_buf, '\n')) orelse return error.EndOfStream;
        const line = std.mem.trim(u8, first_line, "\r");
        
        var it = std.mem.splitScalar(u8, line, ' ');
        const method  = try allocator.dupe(u8, it.next() orelse return error.InvalidRequest);
        errdefer allocator.free(method);
        const path    = try allocator.dupe(u8, it.next() orelse return error.InvalidRequest);
        errdefer allocator.free(path);
        const version = try allocator.dupe(u8, it.next() orelse return error.InvalidRequest);
        errdefer allocator.free(version);

        // 2. Headers
        var headers = std.StringHashMap([]const u8).init(allocator);
        errdefer {
            var hit = headers.iterator();
            while (hit.next()) |entry| {
                allocator.free(entry.key_ptr.*);
                allocator.free(entry.value_ptr.*);
            }
            headers.deinit();
        }

        while (true) {
            const hline_raw = (try reader.readUntilDelimiterOrEof(&line_buf, '\n')) orelse break;
            const hline = std.mem.trim(u8, hline_raw, "\r");
            if (hline.len == 0) break;

            var hit = std.mem.splitSequence(u8, hline, ": ");
            const key_raw = hit.next() orelse continue;
            const val_raw = hit.rest();
            
            const key = try allocator.dupe(u8, key_raw);
            const val = try allocator.dupe(u8, val_raw);
            try headers.put(key, val);
        }

        return Request{
            .method  = method,
            .path    = path,
            .version = version,
            .headers = headers,
        };
    }

    pub fn deinit(self: *Request, allocator: std.mem.Allocator) void {
        allocator.free(self.method);
        allocator.free(self.path);
        allocator.free(self.version);
        var it = self.headers.iterator();
        while (it.next()) |entry| {
            allocator.free(entry.key_ptr.*);
            allocator.free(entry.value_ptr.*);
        }
        self.headers.deinit();
    }
};

test "HTTP parser: basic request" {
    const allocator = std.testing.allocator;
    const raw = "GET /status HTTP/1.1\r\nHost: localhost\r\nConnection: close\r\n\r\n";
    var fbs = std.io.fixedBufferStream(raw);
    
    var req = try Request.parse(allocator, fbs.reader());
    defer req.deinit(allocator);

    try std.testing.expectEqualStrings("GET", req.method);
    try std.testing.expectEqualStrings("/status", req.path);
    try std.testing.expectEqualStrings("HTTP/1.1", req.version);
    try std.testing.expectEqualStrings("localhost", req.headers.get("Host").?);
}
