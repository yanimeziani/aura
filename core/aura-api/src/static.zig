//! Static file server logic — aura-api.
const std = @import("std");
const fs = std.fs;
const net = std.net;

pub fn serveFile(conn: net.Server.Connection, root_dir: []const u8, path: []const u8) !void {
    var fixed_path = path;
    if (std.mem.eql(u8, path, "/")) {
        fixed_path = "/index.html";
    }

    // Security: prevent directory traversal
    if (std.mem.indexOf(u8, fixed_path, "..") != null) {
        return error.InvalidPath;
    }

    // Construct absolute path
    var full_path_buf: [1024]u8 = undefined;
    const full_path = try std.fmt.bufPrint(&full_path_buf, "{s}{s}", .{ root_dir, fixed_path });

    const file = fs.openFileAbsolute(full_path, .{}) catch |err| {
        if (err == error.FileNotFound) {
            // Fallback for SPA: serve index.html if file not found
            if (!std.mem.eql(u8, fixed_path, "/index.html")) {
                return serveFile(conn, root_dir, "/index.html");
            }
            return writePlain(conn, 404, "File Not Found");
        }
        return err;
    };
    defer file.close();

    const stat = try file.stat();
    const mime = getMimeType(fixed_path);

    var hdr_buf: [256]u8 = undefined;
    const hdr = try std.fmt.bufPrint(&hdr_buf, "HTTP/1.1 200 OK\r\nContent-Type: {s}\r\nContent-Length: {d}\r\nConnection: close\r\n\r\n", .{ mime, stat.size });
    try conn.stream.writeAll(hdr);

    // Send file content in chunks
    var send_buf: [8192]u8 = undefined;
    while (true) {
        const bytes_read = try file.read(&send_buf);
        if (bytes_read == 0) break;
        try conn.stream.writeAll(send_buf[0..bytes_read]);
    }
}

fn getMimeType(path: []const u8) []const u8 {
    if (std.mem.endsWith(u8, path, ".html")) return "text/html";
    if (std.mem.endsWith(u8, path, ".css")) return "text/css";
    if (std.mem.endsWith(u8, path, ".js")) return "application/javascript";
    if (std.mem.endsWith(u8, path, ".json")) return "application/json";
    if (std.mem.endsWith(u8, path, ".png")) return "image/png";
    if (std.mem.endsWith(u8, path, ".svg")) return "image/svg+xml";
    if (std.mem.endsWith(u8, path, ".webmanifest")) return "application/manifest+json";
    return "application/octet-stream";
}

fn writePlain(conn: net.Server.Connection, status: u16, body: []const u8) !void {
    var hdr: [256]u8 = undefined;
    const h = try std.fmt.bufPrint(&hdr, "HTTP/1.1 {d}\r\nContent-Type: text/plain\r\nContent-Length: {d}\r\n\r\n", .{ status, body.len });
    try conn.stream.writeAll(h);
    try conn.stream.writeAll(body);
}
