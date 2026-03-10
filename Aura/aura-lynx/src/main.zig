//! aura-lynx — Zig text browser (Lynx-like). Mobile + KDE.
//! No external deps; Zig 0.15.2 + std only.
//! HTTP only (https via TLS in a later phase).

const std = @import("std");
const net = std.net;

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const args = try std.process.argsAlloc(allocator);
    defer std.process.argsFree(allocator, args);

    if (args.len < 2) {
        std.debug.print("aura-lynx — Zig text browser\n", .{});
        std.debug.print("Usage: aura-lynx <URL>\n", .{});
        std.debug.print("Example: aura-lynx http://example.com\n", .{});
        return;
    }

    const url = args[1];
    const body = fetch: {
        const parsed = try parseUrl(allocator, url);
        defer allocator.free(parsed.host);
        defer allocator.free(parsed.path);

        const body = try httpGet(allocator, parsed.host, parsed.port, parsed.path);
        break :fetch body;
    };
    defer allocator.free(body);

    const text = try htmlToText(allocator, body);
    defer allocator.free(text);

    std.debug.print("\n{s}\n", .{text});
}

const ParsedUrl = struct {
    host: []const u8,
    port: u16,
    path: []const u8,
};

fn parseUrl(allocator: std.mem.Allocator, url: []const u8) !ParsedUrl {
    if (!std.mem.startsWith(u8, url, "http://")) {
        std.debug.print("Only http:// URLs supported (https in later phase)\n", .{});
        return error.UnsupportedScheme;
    }
    var rest = url["http://".len..];
    const slash = std.mem.indexOf(u8, rest, "/");
    const host_part = if (slash) |s| rest[0..s] else rest;
    const path = if (slash) |s| try allocator.dupe(u8, rest[s..]) else try allocator.dupe(u8, "/");

    const colon = std.mem.indexOf(u8, host_part, ":");
    const host = if (colon) |c|
        try allocator.dupe(u8, host_part[0..c])
    else
        try allocator.dupe(u8, host_part);
    const port: u16 = if (colon) |c|
        std.fmt.parseInt(u16, host_part[c + 1 ..], 10) catch 80
    else
        80;

    return .{ .host = host, .port = port, .path = path };
}

fn httpGet(allocator: std.mem.Allocator, host: []const u8, port: u16, path: []const u8) ![]const u8 {
    var stream = net.tcpConnectToHost(allocator, host, port) catch |err| {
        std.debug.print("Connect failed: {}\n", .{err});
        return err;
    };
    defer stream.close();

    var req_buf: [512]u8 = undefined;
    const req_len = std.fmt.bufPrint(&req_buf, "GET {s} HTTP/1.1\r\nHost: {s}\r\nConnection: close\r\n\r\n", .{ path, host }) catch return error.BufferTooSmall;
    _ = try stream.write(req_len);

    var list = std.array_list.Managed(u8).init(allocator);
    defer list.deinit();
    var buf: [4096]u8 = undefined;
    while (true) {
        const n = stream.read(&buf) catch break;
        if (n == 0) break;
        try list.appendSlice(buf[0..n]);
    }

    const full = list.items;
    const header_end = if (std.mem.indexOf(u8, full, "\r\n\r\n")) |p| p + 4 else (std.mem.indexOf(u8, full, "\n\n") orelse full.len) + 2;
    const body = try allocator.dupe(u8, full[header_end..]);
    return body;
}

// ── Tests ─────────────────────────────────────────────────────────────────────

test "parseUrl: basic http URL" {
    const a = std.testing.allocator;
    const p = try parseUrl(a, "http://example.com/path");
    defer a.free(p.host);
    defer a.free(p.path);
    try std.testing.expectEqualStrings("example.com", p.host);
    try std.testing.expectEqualStrings("/path", p.path);
    try std.testing.expectEqual(@as(u16, 80), p.port);
}

test "parseUrl: URL with custom port" {
    const a = std.testing.allocator;
    const p = try parseUrl(a, "http://localhost:8080/");
    defer a.free(p.host);
    defer a.free(p.path);
    try std.testing.expectEqualStrings("localhost", p.host);
    try std.testing.expectEqual(@as(u16, 8080), p.port);
    try std.testing.expectEqualStrings("/", p.path);
}

test "parseUrl: rejects non-http scheme" {
    const a = std.testing.allocator;
    const err = parseUrl(a, "https://example.com");
    try std.testing.expectError(error.UnsupportedScheme, err);
}

test "htmlToText: strips tags" {
    const a = std.testing.allocator;
    const text = try htmlToText(a, "<p>Hello <b>world</b></p>");
    defer a.free(text);
    try std.testing.expect(std.mem.indexOf(u8, text, "Hello") != null);
    try std.testing.expect(std.mem.indexOf(u8, text, "world") != null);
    try std.testing.expect(std.mem.indexOf(u8, text, "<b>") == null);
}

test "htmlToText: decodes HTML entities" {
    const a = std.testing.allocator;
    const text = try htmlToText(a, "&lt;script&gt;&amp;");
    defer a.free(text);
    try std.testing.expect(std.mem.indexOf(u8, text, "<") != null);
    try std.testing.expect(std.mem.indexOf(u8, text, ">") != null);
    try std.testing.expect(std.mem.indexOf(u8, text, "&") != null);
}

test "htmlToText: extracts href links" {
    const a = std.testing.allocator;
    const text = try htmlToText(a, "<a href=\"http://example.com\">click</a>");
    defer a.free(text);
    try std.testing.expect(std.mem.indexOf(u8, text, "http://example.com") != null);
}

/// Strip HTML to plain text; extract links.
fn htmlToText(allocator: std.mem.Allocator, html: []const u8) ![]const u8 {
    var out = std.array_list.Managed(u8).init(allocator);
    defer out.deinit();

    var i: usize = 0;
    while (i < html.len) {
        if (html[i] == '<') {
            const end = std.mem.indexOfPos(u8, html, i, ">") orelse html.len;
            const tag = html[i..end];
            if (std.mem.startsWith(u8, tag, "<a ") or std.mem.startsWith(u8, tag, "<A ")) {
                if (std.mem.indexOf(u8, tag, "href=")) |href_start| {
                    const link_start = href_start + 6;
                    const link_end = std.mem.indexOfPos(u8, tag, link_start, "\"") orelse tag.len;
                    if (link_end > link_start) {
                        try out.appendSlice("[");
                        try out.appendSlice(tag[link_start..link_end]);
                        try out.appendSlice("] ");
                    }
                }
            } else if (std.mem.eql(u8, tag, "<br>") or std.mem.eql(u8, tag, "<br/>") or std.mem.eql(u8, tag, "<p>") or std.mem.eql(u8, tag, "</p>")) {
                try out.appendSlice("\n");
            }
            i = end + 1;
            continue;
        }
        if (html[i] == '&') {
            if (std.mem.startsWith(u8, html[i..], "&lt;")) {
                try out.appendSlice("<");
                i += 4;
                continue;
            }
            if (std.mem.startsWith(u8, html[i..], "&gt;")) {
                try out.appendSlice(">");
                i += 4;
                continue;
            }
            if (std.mem.startsWith(u8, html[i..], "&amp;")) {
                try out.appendSlice("&");
                i += 5;
                continue;
            }
            if (std.mem.startsWith(u8, html[i..], "&nbsp;")) {
                try out.appendSlice(" ");
                i += 6;
                continue;
            }
        }
        if (html[i] == '\n' or html[i] == '\r') {
            try out.appendSlice("\n");
            if (html[i] == '\r' and i + 1 < html.len and html[i + 1] == '\n') i += 1;
        } else if (html[i] > ' ') {
            try out.append(html[i]);
        } else if (html[i] == ' ' and out.items.len > 0 and out.items[out.items.len - 1] != ' ' and out.items[out.items.len - 1] != '\n') {
            try out.append(' ');
        }
        i += 1;
    }

    return out.toOwnedSlice();
}
