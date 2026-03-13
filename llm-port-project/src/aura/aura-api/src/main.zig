//! aura-api — Zig HTTP API server for VPS.
//! Health, status, mesh info, session sync. No external deps; Zig 0.15.2 + std only.
//!
//! Routes:
//!   GET    /                          → health
//!   GET    /health                    → health
//!   GET    /status                    → stack overview
//!   GET    /mesh                      → mesh status
//!   GET    /providers                 → AI provider list (from vault/env)
//!   GET    /sync/session/{id}         → get session payload
//!   POST   /sync/session              → set session (body: {"workspace_id":…,"payload":…})
//!   DELETE /sync/session/{id}         → delete session

const std = @import("std");
const net = std.net;
const sessions = @import("sessions.zig");

// ── Config ────────────────────────────────────────────────────────────────────

const AURA_ROOT = "/home/yani/Aura";
const MESH_STATUS_FILE = AURA_ROOT ++ "/var/aura-mesh/status.json";

// ── Main ──────────────────────────────────────────────────────────────────────

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const port_str = std.posix.getenv("AURA_API_PORT") orelse "9000";
    const port_num = std.fmt.parseInt(u16, port_str, 10) catch 9000;

    const address = try net.Address.parseIp("0.0.0.0", port_num);
    var server = try address.listen(.{ .reuse_address = true });
    defer server.deinit();

    std.debug.print("aura-api listening on http://0.0.0.0:{d}\n", .{port_num});

    while (true) {
        const conn = try server.accept();
        handleConnection(allocator, conn) catch |err| {
            std.debug.print("Connection error: {}\n", .{err});
        };
    }
}

// ── Request handler ───────────────────────────────────────────────────────────

fn handleConnection(allocator: std.mem.Allocator, conn: net.Server.Connection) !void {
    defer conn.stream.close();

    var buf: [4096]u8 = undefined;
    const n = conn.stream.read(&buf) catch return;
    if (n == 0) return;

    const request = buf[0..n];
    const path = parsePath(request);

    if (std.mem.eql(u8, path, "/") or std.mem.eql(u8, path, "/health")) {
        return writeJson(conn, 200,
            \\{"status":"ok","service":"aura-api","version":"0.1.0"}
        );
    }

    if (std.mem.eql(u8, path, "/status")) {
        return writeJson(conn, 200,
            \\{"stack":"aura","gateway":"aura-api","vps":true,"handshake":"noise_ik_ready","edge":{"status":"online","tls":"acme_stub"}}
        );
    }

    if (std.mem.eql(u8, path, "/mesh")) {
        return handleMesh(allocator, conn);
    }

    if (std.mem.eql(u8, path, "/providers")) {
        return handleProviders(allocator, conn);
    }

    if (std.mem.startsWith(u8, path, "/sync/session")) {
        return handleSession(allocator, conn, request, path);
    }

    return writePlain(conn, 404, "Not Found");
}

// ── /mesh ─────────────────────────────────────────────────────────────────────

fn handleMesh(allocator: std.mem.Allocator, conn: net.Server.Connection) !void {
    // Try reading var/aura-mesh/status.json; fall back to env/defaults.
    if (readMeshStatusFile(allocator)) |body| {
        defer allocator.free(body);
        return writeJson(conn, 200, body);
    } else |_| {}

    // Env override: AURA_MESH_STATE=up|down
    const state = std.posix.getenv("AURA_MESH_STATE") orelse "stopped";
    const peers_str = std.posix.getenv("AURA_MESH_PEERS") orelse "0";
    const peers = std.fmt.parseInt(u32, peers_str, 10) catch 0;

    var body_buf: [256]u8 = undefined;
    const body = try std.fmt.bufPrint(&body_buf,
        \\{{"state":"{s}","peers":{d},"protocol":"noise_ik","handshake":"blake2s_chacha20poly1305","version":"0.1.0"}}
    , .{ state, peers });

    return writeJson(conn, 200, body);
}

fn readMeshStatusFile(allocator: std.mem.Allocator) ![]const u8 {
    const file = try std.fs.openFileAbsolute(MESH_STATUS_FILE, .{});
    defer file.close();
    return file.readToEndAlloc(allocator, 4096);
}

// ── /providers ────────────────────────────────────────────────────────────────

fn handleProviders(allocator: std.mem.Allocator, conn: net.Server.Connection) !void {
    // Read vault/aura-vault.json to check which keys are present.
    const vault_path = AURA_ROOT ++ "/vault/aura-vault.json";
    const has_groq = keyExistsInVault(allocator, vault_path, "GROQ_API_KEY") or
        (std.posix.getenv("GROQ_API_KEY") != null);
    const has_gemini = keyExistsInVault(allocator, vault_path, "GEMINI_API_KEY") or
        (std.posix.getenv("GEMINI_API_KEY") != null);

    var body_buf: [512]u8 = undefined;
    const body = try std.fmt.bufPrint(&body_buf,
        \\{{"providers":[{{"id":"groq","enabled":{s},"openai_compatible":true}},{{"id":"gemini","enabled":{s},"openai_compatible":false}}]}}
    , .{
        if (has_groq) "true" else "false",
        if (has_gemini) "true" else "false",
    });

    return writeJson(conn, 200, body);
}

/// Returns true if `key` appears as a JSON key in the vault file.
fn keyExistsInVault(allocator: std.mem.Allocator, vault_path: []const u8, key: []const u8) bool {
    const file = std.fs.openFileAbsolute(vault_path, .{}) catch return false;
    defer file.close();
    const content = file.readToEndAlloc(allocator, 64 * 1024) catch return false;
    defer allocator.free(content);
    // Simple check: key appears in content and has a non-empty value.
    // Full JSON parse would be heavier; for a boolean probe this is sufficient.
    const needle = key;
    const pos = std.mem.indexOf(u8, content, needle) orelse return false;
    // Look for a non-null, non-empty string value after the key.
    const after = content[pos + needle.len ..];
    // Skip ": " and check the value isn't "" or null
    const colon = std.mem.indexOfScalar(u8, after, ':') orelse return false;
    const val_start = std.mem.trimLeft(u8, after[colon + 1 ..], " \t\n\r\"");
    if (val_start.len == 0) return false;
    if (std.mem.startsWith(u8, val_start, "null")) return false;
    if (std.mem.startsWith(u8, val_start, "\"\"")) return false;
    return true;
}

// ── /sync/session ─────────────────────────────────────────────────────────────

fn handleSession(allocator: std.mem.Allocator, conn: net.Server.Connection, request: []const u8, path: []const u8) !void {
    const method = parseMethod(request);

    // GET /sync/session/{id}
    if (std.mem.eql(u8, method, "GET")) {
        const prefix = "/sync/session/";
        if (!std.mem.startsWith(u8, path, prefix) or path.len <= prefix.len)
            return writePlain(conn, 400, "missing workspace_id");
        const id = path[prefix.len..];
        var payload = sessions.get(allocator, id) catch null;
        if (payload == null) {
            payload = sessions.syncFromGateway(allocator, id) catch null;
        }
        if (payload) |p| {
            defer allocator.free(p);
            var body_buf: [4096]u8 = undefined;
            const body = try std.fmt.bufPrint(&body_buf,
                \\{{"workspace_id":"{s}","payload":{s}}}
            , .{ id, p });
            return writeJson(conn, 200, body);
        } else {
            var body_buf: [256]u8 = undefined;
            const body = try std.fmt.bufPrint(&body_buf,
                \\{{"workspace_id":"{s}","payload":null}}
            , .{id});
            return writeJson(conn, 200, body);
        }
    }

    // POST /sync/session  (body: {"workspace_id":"…","payload":{…}})
    if (std.mem.eql(u8, method, "POST")) {
        const body = parseBody(request) orelse return writePlain(conn, 400, "missing body");
        // Extract workspace_id from JSON (simple scan — avoid full parse overhead).
        const wid = extractJsonString(body, "workspace_id") orelse
            return writePlain(conn, 400, "missing workspace_id");
        // Extract payload value (everything after "payload":).
        const payload_json = extractJsonValue(body, "payload") orelse "{}";
        sessions.set(allocator, wid, payload_json) catch |err| {
            std.debug.print("session set error: {}\n", .{err});
            return writePlain(conn, 500, "store error");
        };
        var resp_buf: [256]u8 = undefined;
        const resp = try std.fmt.bufPrint(&resp_buf,
            \\{{"workspace_id":"{s}","status":"saved"}}
        , .{wid});
        return writeJson(conn, 200, resp);
    }

    // DELETE /sync/session/{id}
    if (std.mem.eql(u8, method, "DELETE")) {
        const prefix = "/sync/session/";
        if (!std.mem.startsWith(u8, path, prefix) or path.len <= prefix.len)
            return writePlain(conn, 400, "missing workspace_id");
        const id = path[prefix.len..];
        const deleted = sessions.delete(allocator, id) catch false;
        var resp_buf: [256]u8 = undefined;
        const resp = try std.fmt.bufPrint(&resp_buf,
            \\{{"workspace_id":"{s}","deleted":{s}}}
        , .{ id, if (deleted) "true" else "false" });
        return writeJson(conn, 200, resp);
    }

    return writePlain(conn, 405, "Method Not Allowed");
}

/// Extract a JSON string value for a given key (naive scan, single-level only).
fn extractJsonString(json: []const u8, key: []const u8) ?[]const u8 {
    const needle = key;
    const pos = std.mem.indexOf(u8, json, needle) orelse return null;
    const after_key = json[pos + needle.len..];
    const colon = std.mem.indexOfScalar(u8, after_key, ':') orelse return null;
    const after_colon = std.mem.trimLeft(u8, after_key[colon + 1..], " \t\n\r");
    if (after_colon.len == 0 or after_colon[0] != '"') return null;
    const val_start = after_colon[1..];
    const val_end = std.mem.indexOfScalar(u8, val_start, '"') orelse return null;
    return val_start[0..val_end];
}

/// Extract a JSON value (object or any) for a given key as a raw slice.
fn extractJsonValue(json: []const u8, key: []const u8) ?[]const u8 {
    const needle = key;
    const pos = std.mem.indexOf(u8, json, needle) orelse return null;
    const after_key = json[pos + needle.len..];
    const colon = std.mem.indexOfScalar(u8, after_key, ':') orelse return null;
    const after_colon = std.mem.trimLeft(u8, after_key[colon + 1..], " \t\n\r");
    if (after_colon.len == 0) return null;
    // If starts with '{' find matching '}'.
    if (after_colon[0] == '{') {
        var depth: usize = 0;
        for (after_colon, 0..) |c, i| {
            if (c == '{') depth += 1;
            if (c == '}') {
                depth -= 1;
                if (depth == 0) return after_colon[0 .. i + 1];
            }
        }
        return after_colon;
    }
    // Otherwise take until comma or '}'.
    const end = for (after_colon, 0..) |c, i| {
        if (c == ',' or c == '}') break i;
    } else after_colon.len;
    return std.mem.trim(u8, after_colon[0..end], " \t\n\r\"");
}

// ── HTTP helpers ──────────────────────────────────────────────────────────────

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
