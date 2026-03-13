//! Aura Mesh — sovereign Tailscale-like VPN in Zig.
//! Reimplementation of the mesh-VPN experience on Zig + std.crypto (WireGuard protocol).
//! Part of the Aura sovereign network stack; integrates with aura-edge and Aura CLI.

const std = @import("std");

pub const Config = struct {
    /// Control plane URL (e.g. Headscale or Aura coordination server).
    control_url: []const u8 = "https://control.tailscale.com",
    /// Optional auth key for automated join.
    auth_key: ?[]const u8 = null,
    /// Interface name for TUN device (e.g. "aura0").
    interface_name: []const u8 = "aura0",
    /// Optional pre-shared key (32 bytes) for WireGuard.
    psk: ?[32]u8 = null,
};

pub const Peer = struct {
    public_key: [32]u8,
    endpoint: ?std.net.Address = null,
    allowed_ips: []const std.net.Address = &.{},
    name: []const u8 = "",
};

pub const MeshState = enum {
    down,
    connecting,
    up,
};

/// WireGuard protocol constants (from wireguard.zig).
pub const wireguard = @import("wireguard.zig");

/// TUN device interface (from tun.zig).
pub const tun = @import("tun.zig");

/// Peer table — fixed-size registry of known WireGuard peers (from peers.zig).
pub const peers = @import("peers.zig");
pub const registry = @import("registry.zig");
pub const udp = @import("udp.zig");
pub const control = @import("control.zig");

fn ensureDirAbsolute(path: []const u8) !void {
    // Recursive mkdir -p for absolute paths.
    if (path.len == 0) return;
    if (path[0] != '/') return error.InvalidArgument;

    var buf: [std.fs.max_path_bytes]u8 = undefined;
    var fbs = std.io.fixedBufferStream(&buf);
    const w = fbs.writer();

    // Start at root.
    try w.writeByte('/');
    var it = std.mem.splitScalar(u8, path[1..], '/');
    while (it.next()) |part| {
        if (part.len == 0) continue;
        if (fbs.pos > 1) try w.writeByte('/');
        try w.writeAll(part);
        const cur = fbs.getWritten();
        std.fs.makeDirAbsolute(cur) catch |err| switch (err) {
            error.PathAlreadyExists => {},
            else => return err,
        };
    }
}

fn getStateDir(allocator: std.mem.Allocator) ![]u8 {
    if (std.process.getEnvVarOwned(allocator, "AURA_STATE_DIR")) |d| {
        return d;
    } else |_| {}

    const home = try std.process.getEnvVarOwned(allocator, "HOME");
    defer allocator.free(home);
    return try std.fmt.allocPrint(allocator, "{s}/.local/state/aura", .{home});
}

fn getMeshStatePath(allocator: std.mem.Allocator) ![]u8 {
    const dir = try getStateDir(allocator);
    defer allocator.free(dir);
    return try std.fmt.allocPrint(allocator, "{s}/mesh.state", .{dir});
}

fn parseState(raw: []const u8) MeshState {
    const trimmed = std.mem.trim(u8, raw, " \t\r\n");
    if (std.mem.eql(u8, trimmed, "up")) return .up;
    if (std.mem.eql(u8, trimmed, "connecting")) return .connecting;
    return .down;
}

fn stateToString(state: MeshState) []const u8 {
    return switch (state) {
        .down => "down",
        .connecting => "connecting",
        .up => "up",
    };
}

/// Returns current mesh state.
///
/// While the real daemon handshake/TUN/control-plane is under construction, we persist a tiny
/// state file so `aura mesh up/down/status` behaves consistently for UX and scripting.
pub fn getState(allocator: std.mem.Allocator) MeshState {
    _ = wireguard;

    const path = getMeshStatePath(allocator) catch return .down;
    defer allocator.free(path);

    const file = std.fs.openFileAbsolute(path, .{}) catch return .down;
    defer file.close();

    var buf: [32]u8 = undefined;
    const n = file.readAll(&buf) catch return .down;
    return parseState(buf[0..n]);
}

pub fn setState(allocator: std.mem.Allocator, state: MeshState) !void {
    const dir = try getStateDir(allocator);
    defer allocator.free(dir);
    try ensureDirAbsolute(dir);

    const path = try std.fmt.allocPrint(allocator, "{s}/mesh.state", .{dir});
    defer allocator.free(path);

    var file = try std.fs.createFileAbsolute(path, .{ .truncate = true });
    defer file.close();
    try file.writeAll(stateToString(state));
    try file.writeAll("\n");
}

test "config default" {
    const c = Config{};
    try std.testing.expect(c.interface_name.len > 0);
}

test "wireguard constants" {
    try std.testing.expect(wireguard.KEY_SIZE == 32);
    try std.testing.expect(wireguard.MAC_SIZE == 16);
}

test "mesh state parser" {
    try std.testing.expect(parseState("up\n") == .up);
    try std.testing.expect(parseState("connecting") == .connecting);
    try std.testing.expect(parseState("down") == .down);
    try std.testing.expect(parseState("") == .down);
}
