const std = @import("std");

/// Simple HTTP API for agent logs — zero external dependencies
/// Endpoints:
///   POST /logs — ingest log entry
///   GET /logs — query logs (with filters)
///   GET /health — health check
const DB_PATH = "/home/forge/data/logs.db";
const LISTEN_PORT = 8080;

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const stdout = std.io.getStdOut().writer();
    try stdout.print("Forge Logs API starting on port {d}...\n", .{LISTEN_PORT});

    // Simple TCP server
    const address = std.net.Address.parseIp4("0.0.0.0", LISTEN_PORT) catch unreachable;
    var server = try address.listen(.{
        .reuse_address = true,
    });
    defer server.deinit();

    try stdout.print("Listening on 0.0.0.0:{d}\n", .{LISTEN_PORT});

    while (true) {
        const conn = server.accept() catch |err| {
            try stdout.print("Accept error: {}\n", .{err});
            continue;
        };

        // Handle in same thread (simple, safe)
        handleConnection(allocator, conn) catch |err| {
            try stdout.print("Handler error: {}\n", .{err});
        };
    }
}

fn handleConnection(allocator: std.mem.Allocator, conn: std.net.Server.Connection) !void {
    defer conn.stream.close();

    var buf: [4096]u8 = undefined;
    const n = try conn.stream.read(&buf);
    if (n == 0) return;

    const request = buf[0..n];

    // Simple routing
    if (std.mem.startsWith(u8, request, "GET /health")) {
        try sendResponse(conn.stream, "200 OK", "{\"status\":\"ok\"}");
    } else if (std.mem.startsWith(u8, request, "POST /logs")) {
        // TODO: Parse body, insert to SQLite
        try sendResponse(conn.stream, "201 Created", "{\"id\":1}");
    } else if (std.mem.startsWith(u8, request, "GET /logs")) {
        // TODO: Query SQLite with filters
        try sendResponse(conn.stream, "200 OK", "{\"logs\":[]}");
    } else {
        try sendResponse(conn.stream, "404 Not Found", "{\"error\":\"not found\"}");
    }

    _ = allocator;
}

fn sendResponse(stream: std.net.Stream, status: []const u8, body: []const u8) !void {
    var writer = stream.writer();
    try writer.print("HTTP/1.1 {s}\r\n", .{status});
    try writer.print("Content-Type: application/json\r\n", .{});
    try writer.print("Content-Length: {d}\r\n", .{body.len});
    try writer.print("Connection: close\r\n", .{});
    try writer.print("\r\n", .{});
    try writer.writeAll(body);
}

test "response formatting" {
    // Test would need mock stream
}
