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

    var url: ?[]const u8 = null;
    var distill_mode = false;
    var sync_mode = false;

    for (args[1..]) |arg| {
        if (std.mem.eql(u8, arg, "-d") or std.mem.eql(u8, arg, "--distill")) {
            distill_mode = true;
        } else if (std.mem.eql(u8, arg, "-s") or std.mem.eql(u8, arg, "--sync")) {
            sync_mode = true;
        } else if (url == null) {
            url = arg;
        }
    }

    if (url == null) {
        std.debug.print("aura-lynx — Zig text browser\n", .{});
        std.debug.print("Usage: aura-lynx <URL> [options]\n", .{});
        std.debug.print("Options:\n", .{});
        std.debug.print("  -d, --distill    Summarize content using Nexa Gateway\n", .{});
        std.debug.print("  -s, --sync       Sync distilled output to docs_inbox\n", .{});
        std.debug.print("Example: aura-lynx http://example.com --distill --sync\n", .{});
        return;
    }

    const body = fetch: {
        const parsed = try parseUrl(allocator, url.?);
        defer allocator.free(parsed.host);
        defer allocator.free(parsed.path);

        const body = try httpGet(allocator, parsed.host, parsed.port, parsed.path);
        break :fetch body;
    };
    defer allocator.free(body);

    const text = try htmlToText(allocator, body);
    defer allocator.free(text);

    if (distill_mode) {
        const distilled = distill(allocator, text) catch |err| {
            std.debug.print("\n[distill failed: {}]\n", .{err});
            return err;
        };
        defer allocator.free(distilled);
        std.debug.print("\n=== DISTILLED CONTENT ===\n{s}\n", .{distilled});

        if (sync_mode) {
            const timestamp = std.time.timestamp();
            const filename = std.fmt.allocPrint(allocator, "core/vault/docs_inbox/distilled_{d}.md", .{timestamp}) catch "distilled.md";
            defer allocator.free(filename);
            
            if (std.fs.cwd().createFile(filename, .{})) |file| {
                defer file.close();
                file.writeAll(distilled) catch {};
                std.debug.print("\n[Synced distilled content to {s}]\n", .{filename});
            } else |err| {
                std.debug.print("\n[Failed to sync to docs_inbox: {}]\n", .{err});
            }
        }
    } else {
        std.debug.print("\n{s}\n", .{text});
    }
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

/// Strip HTML to plain text; extract links. Skip style/script/nav/footer.
fn htmlToText(allocator: std.mem.Allocator, html: []const u8) ![]const u8 {
    var out = std.array_list.Managed(u8).init(allocator);
    defer out.deinit();

    var i: usize = 0;
    while (i < html.len) {
        if (html[i] == '<') {
            const end = std.mem.indexOfPos(u8, html, i, ">") orelse html.len;
            const tag = html[i..end];

            // Heuristic to skip unneeded tags
            if (std.ascii.startsWithIgnoreCase(tag, "<style") or
                std.ascii.startsWithIgnoreCase(tag, "<script") or
                std.ascii.startsWithIgnoreCase(tag, "<nav") or
                std.ascii.startsWithIgnoreCase(tag, "<footer"))
            {
                const close_tag = if (std.ascii.startsWithIgnoreCase(tag, "<style")) "</style>" else if (std.ascii.startsWithIgnoreCase(tag, "<script")) "</script>" else if (std.ascii.startsWithIgnoreCase(tag, "<nav")) "</nav>" else "</footer>";

                if (std.mem.indexOf(u8, html[end..], close_tag)) |close_pos| {
                    i = end + close_pos + close_tag.len;
                    continue;
                }
            }

            if (std.ascii.startsWithIgnoreCase(tag, "<a ")) {
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

fn distill(allocator: std.mem.Allocator, text: []const u8) ![]const u8 {
    const host = "127.0.0.1";
    const port = 8765;
    const path = "/v1/chat/completions";

    var stream = net.tcpConnectToHost(allocator, host, port) catch |err| {
        std.debug.print("Connect to gateway failed: {}\n", .{err});
        return err;
    };
    defer stream.close();

    const prompt = try std.fmt.allocPrint(allocator, "Distill the following web content into a concise summary focusing on key facts and insights:\n\n{s}", .{text[0..@min(text.len, 4000)]});
    defer allocator.free(prompt);

    const payload_template =
        \\{{
        \\  "model": "default",
        \\  "messages": [
        \\    {{ "role": "user", "content": {s} }}
        \\  ],
        \\  "temperature": 0.5
        \\}}
    ;

    // Simple JSON string escaping (minimal for the prompt)
    var escaped_prompt = std.array_list.Managed(u8).init(allocator);
    defer escaped_prompt.deinit();
    try escaped_prompt.appendSlice("\"");
    for (prompt) |c| {
        if (c == '\"') {
            try escaped_prompt.appendSlice("\\\"");
        } else if (c == '\\') {
            try escaped_prompt.appendSlice("\\\\");
        } else if (c == '\n') {
            try escaped_prompt.appendSlice("\\n");
        } else if (c == '\r') {
            try escaped_prompt.appendSlice("\\r");
        } else if (c >= 32) {
            try escaped_prompt.append(c);
        }
    }
    try escaped_prompt.appendSlice("\"");

    const json_payload = try std.fmt.allocPrint(allocator, payload_template, .{escaped_prompt.items});
    defer allocator.free(json_payload);

    var req_buf = std.array_list.Managed(u8).init(allocator);
    defer req_buf.deinit();
    try std.fmt.format(req_buf.writer(), "POST {s} HTTP/1.1\r\nHost: {s}\r\nContent-Type: application/json\r\nContent-Length: {}\r\nConnection: close\r\n\r\n{s}", .{ path, host, json_payload.len, json_payload });

    _ = try stream.write(req_buf.items);

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
    const res_body = full[header_end..];

    // Simple JSON value extraction for the summary
    const start_token = "\"content\":";
    if (std.mem.indexOf(u8, res_body, start_token)) |pos| {
        var start = pos + start_token.len;
        while (start < res_body.len and (res_body[start] == ' ' or res_body[start] == '\"')) : (start += 1) {}
        const end = std.mem.indexOfPos(u8, res_body, start, "\"") orelse res_body.len;
        
        // Unescape \n and \r
        var result = std.array_list.Managed(u8).init(allocator);
        var j = start;
        while (j < end) {
            if (res_body[j] == '\\' and j + 1 < end) {
                if (res_body[j+1] == 'n') { try result.append('\n'); j += 2; continue; }
                if (res_body[j+1] == 'r') { try result.append('\r'); j += 2; continue; }
                if (res_body[j+1] == '\"') { try result.append('\"'); j += 2; continue; }
                if (res_body[j+1] == '\\') { try result.append('\\'); j += 2; continue; }
            }
            try result.append(res_body[j]);
            j += 1;
        }
        return result.toOwnedSlice();
    }

    return try allocator.dupe(u8, "[No summary found in response]");
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

test "htmlToText: strips style and script tags" {
    const a = std.testing.allocator;
    const text = try htmlToText(a, "<html><style>body{color:red}</style><body>Hello <script>alert(1)</script>world</body></html>");
    defer a.free(text);
    try std.testing.expect(std.mem.indexOf(u8, text, "Hello") != null);
    try std.testing.expect(std.mem.indexOf(u8, text, "world") != null);
    try std.testing.expect(std.mem.indexOf(u8, text, "body{color:red}") == null);
    try std.testing.expect(std.mem.indexOf(u8, text, "alert(1)") == null);
}
