const std = @import("std");
const net = std.net;

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const address = try net.Address.parseIp("127.0.0.1", 8085);
    var server = try address.listen(.{ .reuse_address = true });
    defer server.deinit();

    std.debug.print("Aura Taxes (QuickBooks clone) listening on {any}\n", .{server.listen_address});

    while (true) {
        const conn = try server.accept();
        handleConnection(allocator, conn) catch |err| {
            std.debug.print("Connection error: {any}\n", .{err});
        };
    }
}

fn handleConnection(allocator: std.mem.Allocator, conn: net.Server.Connection) !void {
    _ = allocator; // Will be used later for complex JSON parsing
    defer conn.stream.close();

    var buf: [4096]u8 = undefined;
    const n = conn.stream.read(&buf) catch return;
    if (n == 0) return;

    const request = buf[0..n];
    const path = parsePath(request);

    std.debug.print("Request: {s}\n", .{path});

    if (std.mem.eql(u8, path, "/api/health")) {
        const body = "{\"status\":\"ok\"}";
        try writeJson(conn, 200, body);
    } else {
        try writePlain(conn, 404, "Not Found");
    }
}

fn parsePath(request: []const u8) []const u8 {
    const space1 = std.mem.indexOfScalar(u8, request, ' ') orelse return "/";
    const rest = request[space1 + 1 ..];
    const space2 = std.mem.indexOfScalar(u8, rest, ' ') orelse return "/";
    const path = rest[0..space2];
    const q = std.mem.indexOfScalar(u8, path, '?');
    return if (q) |i| path[0..i] else path;
}

fn writePlain(conn: net.Server.Connection, status: u16, body: []const u8) !void {
    const status_line = statusLine(status);
    var hdr: [256]u8 = undefined;
    const h = try std.fmt.bufPrint(&hdr,
        "HTTP/1.1 {s}\r\nContent-Type: text/plain\r\nConnection: close\r\nContent-Length: {d}\r\n\r\n",
        .{ status_line, body.len });
    _ = try conn.stream.write(h);
    _ = try conn.stream.write(body);
}

fn writeJson(conn: net.Server.Connection, status: u16, body: []const u8) !void {
    const status_line = statusLine(status);
    var hdr: [256]u8 = undefined;
    const h = try std.fmt.bufPrint(&hdr,
        "HTTP/1.1 {s}\r\nContent-Type: application/json\r\nConnection: close\r\nContent-Length: {d}\r\n\r\n",
        .{ status_line, body.len });
    _ = try conn.stream.write(h);
    _ = try conn.stream.write(body);
}

fn statusLine(code: u16) []const u8 {
    return switch (code) {
        200 => "200 OK",
        400 => "400 Bad Request",
        404 => "404 Not Found",
        405 => "405 Method Not Allowed",
        500 => "500 Internal Server Error",
        else => "500 Internal Server Error",
    };
}
