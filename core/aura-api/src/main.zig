//! aura-api — Zig HTTP API server for VPS.
//! Health, status, mesh info, session sync, and World State Map.
//! Zig 0.15.2 + std only.

const std = @import("std");
const net = std.net;
const sessions = @import("sessions.zig");
const sse = @import("sse.zig");
const world = @import("world.zig");
const electro_spatial = @import("electro_spatial.zig");

// ── State ─────────────────────────────────────────────────────────────────────

var world_state: world.WorldState = undefined;
var es_state: electro_spatial.ElectroSpatialState = undefined;

// ── Main ──────────────────────────────────────────────────────────────────────

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    world_state = world.WorldState.init(allocator);
    try world_state.seed();

    es_state = electro_spatial.ElectroSpatialState.init(allocator, &world_state);

    const port_str = std.posix.getenv("AURA_API_PORT") orelse "9000";
    const port_num = std.fmt.parseInt(u16, port_str, 10) catch 9000;

    const address = try net.Address.parseIp("0.0.0.0", port_num);
    var server = try address.listen(.{ .reuse_address = true });
    defer server.deinit();

    std.debug.print("aura-api listening on http://0.0.0.0:{d}\n", .{port_num});

    while (true) {
        const conn = try server.accept();
        const thread = try std.Thread.spawn(.{}, handleConnection, .{ allocator, conn });
        thread.detach();
    }
}

// ── Connection Handler ────────────────────────────────────────────────────────

fn handleConnection(allocator: std.mem.Allocator, conn: net.Server.Connection) void {
    defer conn.stream.close();

    var buf: [4096]u8 = undefined;
    const n = conn.stream.read(&buf) catch return;
    if (n == 0) return;

    const request = buf[0..n];
    const path = parsePath(request);
    const method = parseMethod(request);

    if (std.mem.eql(u8, path, "/") or std.mem.eql(u8, path, "/health")) {
        writeJson(conn, 200, "{\"status\":\"ok\",\"service\":\"aura-api\",\"version\":\"0.1.1\"}") catch return;
    } else if (std.mem.eql(u8, path, "/status")) {
        writeJson(conn, 200, "{\"stack\":\"aura\",\"gateway\":\"aura-api\",\"vps\":true}") catch return;
    } else if (std.mem.eql(u8, path, "/world/state")) {
        handleWorldState(conn) catch return;
    } else if (std.mem.eql(u8, path, "/world/stream")) {
        handleWorldStream(conn) catch return;
    } else if (std.mem.eql(u8, path, "/world/update")) {
        handleWorldUpdate(conn, request) catch return;
    } else if (std.mem.eql(u8, path, "/mesh")) {
        handleMesh(conn) catch return;
    } else if (std.mem.eql(u8, path, "/rag/ground-truth")) {
        handleRagGroundTruth(conn) catch return;
    } else if (std.mem.eql(u8, path, "/providers")) {
        handleProviders(conn) catch return;
    } else if (std.mem.startsWith(u8, path, "/sync/session")) {
        handleSession(allocator, conn, request, path, method) catch return;
    } else {
        writePlain(conn, 404, "Not Found") catch return;
    }
}

// ── World Handlers ────────────────────────────────────────────────────────────

fn handleWorldState(conn: net.Server.Connection) !void {
    try conn.stream.writeAll("HTTP/1.1 200 OK\r\nContent-Type: application/json\r\nConnection: close\r\n\r\n");
    try world_state.serialize(conn.stream);
}

fn handleWorldStream(conn: net.Server.Connection) !void {
    try sse.sendHeaders(conn.stream);
    try world_state.subscribe(conn.stream);

    while (true) {
        std.Thread.sleep(std.time.ns_per_s * 30);
        sse.writeComment(conn.stream, "keep-alive") catch break;
    }
}

fn handleWorldUpdate(conn: net.Server.Connection, request: []const u8) !void {
    const body = parseBody(request) orelse return writePlain(conn, 400, "missing body");
    const region_id = extractJsonString(body, "region_id") orelse return writePlain(conn, 400, "missing region_id");
    const owner_id = extractJsonString(body, "owner_id") orelse return writePlain(conn, 400, "missing owner_id");

    if (try world_state.updateOwner(region_id, owner_id)) |delta| {
        world_state.broadcast(delta);
        var resp_buf: [256]u8 = undefined;
        const resp = try std.fmt.bufPrint(&resp_buf, "{{\"region_id\":\"{s}\",\"status\":\"updated\"}}", .{region_id});
        return writeJson(conn, 200, resp);
    } else {
        return writePlain(conn, 404, "region not found");
    }
}

// ── Existing Handlers (Ported) ────────────────────────────────────────────────

fn handleMesh(conn: net.Server.Connection) !void {
    const state = std.posix.getenv("AURA_MESH_STATE") orelse "stopped";
    const peers_str = std.posix.getenv("AURA_MESH_PEERS") orelse "0";
    const peers = std.fmt.parseInt(u32, peers_str, 10) catch 0;

    var body_buf: [256]u8 = undefined;
    const body = try std.fmt.bufPrint(&body_buf,
        \\{{"state":"{s}","peers":{d},"protocol":"noise_ik","version":"0.1.0"}}
    , .{ state, peers });
    return writeJson(conn, 200, body);
}

fn handleRagGroundTruth(conn: net.Server.Connection) !void {
    const context = try es_state.generateRagContext();
    defer es_state.allocator.free(context);

    try conn.stream.writeAll("HTTP/1.1 200 OK\r\nContent-Type: text/plain\r\nConnection: close\r\n\r\n");
    try conn.stream.writeAll(context);
}

fn handleProviders(conn: net.Server.Connection) !void {
    const has_groq = std.posix.getenv("GROQ_API_KEY") != null;
    const has_gemini = std.posix.getenv("GEMINI_API_KEY") != null;

    var body_buf: [512]u8 = undefined;
    const body = try std.fmt.bufPrint(&body_buf,
        \\{{"providers":[{{"id":"groq","enabled":{s}}},{{"id":"gemini","enabled":{s}}}]}}
    , .{ if (has_groq) "true" else "false", if (has_gemini) "true" else "false" });
    return writeJson(conn, 200, body);
}

fn handleSession(allocator: std.mem.Allocator, conn: net.Server.Connection, request: []const u8, path: []const u8, method: []const u8) !void {
    if (std.mem.eql(u8, method, "GET")) {
        const prefix = "/sync/session/";
        if (path.len <= prefix.len) return writePlain(conn, 400, "missing workspace_id");
        const id = path[prefix.len..];
        if (try sessions.get(allocator, id)) |p| {
            defer allocator.free(p);
            var body_buf: [4096]u8 = undefined;
            const body = try std.fmt.bufPrint(&body_buf, "{{\"workspace_id\":\"{s}\",\"payload\":{s}}}", .{ id, p });
            return writeJson(conn, 200, body);
        } else {
            return writeJson(conn, 200, "{\"payload\":null}");
        }
    } else if (std.mem.eql(u8, method, "POST")) {
        const body = parseBody(request) orelse return writePlain(conn, 400, "missing body");
        const wid = extractJsonString(body, "workspace_id") orelse return writePlain(conn, 400, "missing workspace_id");
        const payload_json = extractJsonValue(body, "payload") orelse "{}";
        try sessions.set(allocator, wid, payload_json);
        return writeJson(conn, 200, "{\"status\":\"saved\"}");
    }
    return writePlain(conn, 405, "Method Not Allowed");
}

// ── Helpers ───────────────────────────────────────────────────────────────────

fn parsePath(request: []const u8) []const u8 {
    const space1 = std.mem.indexOfScalar(u8, request, ' ') orelse return "/";
    const rest = request[space1 + 1 ..];
    const space2 = std.mem.indexOfScalar(u8, rest, ' ') orelse return "/";
    const path = rest[0..space2];
    const q = std.mem.indexOfScalar(u8, path, '?');
    return if (q) |i| path[0..i] else path;
}

fn parseMethod(request: []const u8) []const u8 {
    const sp = std.mem.indexOfScalar(u8, request, ' ') orelse return "GET";
    return request[0..sp];
}

fn parseBody(request: []const u8) ?[]const u8 {
    const sep = "\r\n\r\n";
    const idx = std.mem.indexOf(u8, request, sep) orelse return null;
    const body = request[idx + sep.len..];
    return if (body.len == 0) null else body;
}

fn extractJsonString(json: []const u8, key: []const u8) ?[]const u8 {
    const pos = std.mem.indexOf(u8, json, key) orelse return null;
    const after_key = json[pos + key.len..];
    const colon = std.mem.indexOfScalar(u8, after_key, ':') orelse return null;
    const after_colon = std.mem.trimLeft(u8, after_key[colon + 1..], " \t\n\r");
    if (after_colon.len == 0 or after_colon[0] != '"') return null;
    const val_start = after_colon[1..];
    const val_end = std.mem.indexOfScalar(u8, val_start, '"') orelse return null;
    return val_start[0..val_end];
}

fn extractJsonValue(json: []const u8, key: []const u8) ?[]const u8 {
    const pos = std.mem.indexOf(u8, json, key) orelse return null;
    const after_key = json[pos + key.len..];
    const colon = std.mem.indexOfScalar(u8, after_key, ':') orelse return null;
    const after_colon = std.mem.trimLeft(u8, after_key[colon + 1..], " \t\n\r");
    if (after_colon.len == 0) return null;
    if (after_colon[0] == '{') {
        var depth: usize = 0;
        for (after_colon, 0..) |c, i| {
            if (c == '{') depth += 1;
            if (c == '}') {
                depth -= 1;
                if (depth == 0) return after_colon[0 .. i + 1];
            }
        }
    }
    const end = for (after_colon, 0..) |c, i| {
        if (c == ',' or c == '}') break i;
    } else after_colon.len;
    return std.mem.trim(u8, after_colon[0..end], " \t\n\r\"");
}

fn writePlain(conn: net.Server.Connection, status: u16, body: []const u8) !void {
    var hdr: [256]u8 = undefined;
    const h = try std.fmt.bufPrint(&hdr, "HTTP/1.1 {d}\r\nContent-Type: text/plain\r\nContent-Length: {d}\r\n\r\n", .{ status, body.len });
    try conn.stream.writeAll(h);
    try conn.stream.writeAll(body);
}

fn writeJson(conn: net.Server.Connection, status: u16, body: []const u8) !void {
    var hdr: [256]u8 = undefined;
    const h = try std.fmt.bufPrint(&hdr, "HTTP/1.1 {d}\r\nContent-Type: application/json\r\nContent-Length: {d}\r\n\r\n", .{ status, body.len });
    try conn.stream.writeAll(h);
    try conn.stream.writeAll(body);
}
