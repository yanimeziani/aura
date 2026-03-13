const std = @import("std");
const Allocator = std.mem.Allocator;

/// Diff hunk
pub const Hunk = struct {
    old_start: u32,
    old_count: u32,
    new_start: u32,
    new_count: u32,
    lines: []const Line,

    pub const Line = struct {
        kind: Kind,
        content: []const u8,

        pub const Kind = enum {
            context,
            addition,
            deletion,
        };
    };
};

/// File diff
pub const FileDiff = struct {
    id: []const u8,
    path: []const u8,
    old_path: ?[]const u8,
    status: Status,
    hunks: []const Hunk,
    stats: Stats,

    pub const Status = enum {
        added,
        modified,
        deleted,
        renamed,
    };

    pub const Stats = struct {
        additions: u32,
        deletions: u32,
    };
};

/// Change request for review
pub const ChangeRequest = struct {
    id: []const u8,
    title: []const u8,
    description: []const u8,
    agent_id: []const u8,
    files: []const FileDiff,
    status: Status,
    created_at: i64,
    reviewed_at: ?i64,

    pub const Status = enum {
        pending,
        approved,
        rejected,
        merged,
    };
};

/// Diff API server
pub const DiffServer = struct {
    allocator: Allocator,
    pending: std.ArrayList(ChangeRequest),
    port: u16,

    const Self = @This();

    pub fn init(allocator: Allocator, port: u16) Self {
        return .{
            .allocator = allocator,
            .pending = std.ArrayList(ChangeRequest).init(allocator),
            .port = port,
        };
    }

    pub fn deinit(self: *Self) void {
        self.pending.deinit();
    }

    pub fn submit(self: *Self, cr: ChangeRequest) !void {
        try self.pending.append(cr);
        // TODO: Push notification to mobile
    }

    pub fn approve(self: *Self, id: []const u8) !void {
        for (self.pending.items) |*cr| {
            if (std.mem.eql(u8, cr.id, id)) {
                cr.status = .approved;
                cr.reviewed_at = std.time.timestamp();
                return;
            }
        }
    }

    pub fn reject(self: *Self, id: []const u8) !void {
        for (self.pending.items) |*cr| {
            if (std.mem.eql(u8, cr.id, id)) {
                cr.status = .rejected;
                cr.reviewed_at = std.time.timestamp();
                return;
            }
        }
    }

    pub fn serve(self: *Self) !void {
        const address = std.net.Address.parseIp4("0.0.0.0", self.port) catch unreachable;
        var server = try address.listen(.{ .reuse_address = true });
        defer server.deinit();

        while (true) {
            const conn = server.accept() catch continue;
            self.handleRequest(conn) catch {};
        }
    }

    fn handleRequest(self: *Self, conn: std.net.Server.Connection) !void {
        defer conn.stream.close();

        var buf: [8192]u8 = undefined;
        const n = try conn.stream.read(&buf);
        if (n == 0) return;

        const request = buf[0..n];
        var writer = conn.stream.writer();

        if (std.mem.startsWith(u8, request, "GET /pending")) {
            // Return pending CRs as JSON
            try writer.writeAll("HTTP/1.1 200 OK\r\nContent-Type: application/json\r\n\r\n");
            try writer.writeAll("{\"pending\":");
            try writer.print("{d}", .{self.pending.items.len});
            try writer.writeAll("}");
        } else if (std.mem.startsWith(u8, request, "POST /approve/")) {
            try writer.writeAll("HTTP/1.1 200 OK\r\n\r\n{\"ok\":true}");
        } else if (std.mem.startsWith(u8, request, "POST /reject/")) {
            try writer.writeAll("HTTP/1.1 200 OK\r\n\r\n{\"ok\":true}");
        } else if (std.mem.startsWith(u8, request, "GET /health")) {
            try writer.writeAll("HTTP/1.1 200 OK\r\n\r\n{\"status\":\"ok\"}");
        } else {
            try writer.writeAll("HTTP/1.1 404 Not Found\r\n\r\n");
        }
    }
};
