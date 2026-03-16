//! Session store — aura-api. Zig 0.15.2 + std only.
//! One file per workspace_id: var/aura-api/sessions/{id}.json
//! Atomic writes: write to .tmp then rename (0600).

const std = @import("std");

const DEFAULT_AURA_ROOT = "/opt/aura";
const LEGACY_SESSIONS_DIR = "/home/yani/Aura/var/aura-api/sessions";

// ── Public API ────────────────────────────────────────────────────────────────

/// Get session payload for workspace_id. Returns caller-owned JSON string or null.
pub fn get(allocator: std.mem.Allocator, workspace_id: []const u8) !?[]u8 {
    const path = try sessionPath(allocator, workspace_id);
    defer allocator.free(path);

    const file = std.fs.openFileAbsolute(path, .{}) catch |e| switch (e) {
        error.FileNotFound => return null,
        else => return e,
    };
    defer file.close();
    const data = try file.readToEndAlloc(allocator, 1024 * 1024);
    return data;
}

/// Set session payload (raw JSON) for workspace_id. Writes atomically.
pub fn set(allocator: std.mem.Allocator, workspace_id: []const u8, payload_json: []const u8) !void {
    try ensureDir();
    const path = try sessionPath(allocator, workspace_id);
    defer allocator.free(path);
    const tmp  = try tmpPath(allocator, workspace_id);
    defer allocator.free(tmp);

    {
        const f = try std.fs.createFileAbsolute(tmp, .{ .truncate = true });
        defer f.close();
        try f.writeAll(payload_json);
        try f.chmod(0o600);
    }
    try std.fs.renameAbsolute(tmp, path);
}

/// Delete session. Returns true if it existed.
pub fn delete(allocator: std.mem.Allocator, workspace_id: []const u8) !bool {
    const path = try sessionPath(allocator, workspace_id);
    defer allocator.free(path);
    std.fs.deleteFileAbsolute(path) catch |e| switch (e) {
        error.FileNotFound => return false,
        else => return e,
    };
    return true;
}

/// Attempt to pull session data from the legacy gateway if not found locally.
/// Returns caller-owned JSON string if found, or null.
pub fn syncFromGateway(allocator: std.mem.Allocator, workspace_id: []const u8) !?[]u8 {
    const gateway_base = std.posix.getenv("AURA_GATEWAY_URL") orelse return null;
    
    var client = std.http.Client{ .allocator = allocator };
    defer client.deinit();

    var uri_buf: [1024]u8 = undefined;
    const uri_str = try std.fmt.bufPrint(&uri_buf, "{s}/sync/session/{s}", .{ gateway_base, workspace_id });
    const uri = try std.Uri.parse(uri_str);

    var req = try client.request(.GET, uri, .{});
    defer req.deinit();

    try req.sendBodiless();

    var redirect_buffer: [4096]u8 = undefined;
    var response = try req.receiveHead(&redirect_buffer);

    if (response.head.status != .ok) return null;

    var transfer_buffer: [4096]u8 = undefined;
    const reader = response.reader(&transfer_buffer);
    return try reader.allocRemaining(allocator, .unlimited);
}

// ── Internal ──────────────────────────────────────────────────────────────────

fn ensureDir() !void {
    var buf: [512]u8 = undefined;
    const sessions_dir = try sessionsDirPath(&buf);
    return ensureDirFor(sessions_dir);
}

fn ensureDirFor(sessions_dir: []const u8) !void {
    // mkdir -p SESSIONS_DIR
    var buf: [512]u8 = undefined;
    var pos: usize = 1;
    var it = std.mem.splitScalar(u8, sessions_dir[1..], '/');
    buf[0] = '/';
    while (it.next()) |part| {
        @memcpy(buf[pos..pos + part.len], part);
        pos += part.len;
        std.fs.makeDirAbsolute(buf[0..pos]) catch |e| switch (e) {
            error.PathAlreadyExists => {},
            else => return e,
        };
        buf[pos] = '/';
        pos += 1;
    }
}

fn sessionPath(allocator: std.mem.Allocator, id: []const u8) ![]u8 {
    var buf: [512]u8 = undefined;
    const sessions_dir = try sessionsDirPath(&buf);
    return std.fmt.allocPrint(allocator, "{s}/{s}.json", .{ sessions_dir, id });
}

fn tmpPath(allocator: std.mem.Allocator, id: []const u8) ![]u8 {
    var buf: [512]u8 = undefined;
    const sessions_dir = try sessionsDirPath(&buf);
    return std.fmt.allocPrint(allocator, "{s}/{s}.json.tmp", .{ sessions_dir, id });
}

fn sessionsDirPath(buf: []u8) ![]const u8 {
    if (std.posix.getenv("NEXA_API_SESSIONS_DIR")) |path| return path;
    if (std.posix.getenv("AURA_API_SESSIONS_DIR")) |path| return path;
    if (std.posix.getenv("NEXA_ROOT")) |root| {
        return std.fmt.bufPrint(buf, "{s}/var/aura-api/sessions", .{root});
    }
    if (std.posix.getenv("AURA_ROOT")) |root| {
        return std.fmt.bufPrint(buf, "{s}/var/aura-api/sessions", .{root});
    }
    return DEFAULT_AURA_ROOT ++ "/var/aura-api/sessions";
}

// ── Tests ─────────────────────────────────────────────────────────────────────

test "session path construction" {
    const a = std.testing.allocator;
    const p = try sessionPath(a, "myworkspace");
    defer a.free(p);    try std.testing.expect(std.mem.endsWith(u8, p, "/myworkspace.json"));
}
