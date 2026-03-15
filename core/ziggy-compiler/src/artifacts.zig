//! Output layout: out/bin, out/lib, out/lint, out/reports. Ziggy compiler — Zig 0.15.2.

const std = @import("std");

const subdirs = [_][]const u8{ "bin", "lib", "lint", "reports" };

/// Create out_root and subdirs bin, lib, lint, reports. Idempotent (makePath is mkdir -p).
pub fn ensureOutDir(allocator: std.mem.Allocator, out_root: []const u8) !void {
    _ = allocator;
    try std.fs.cwd().makePath(out_root);
    var dir = try std.fs.cwd().openDir(out_root, .{});
    defer dir.close();
    for (subdirs) |name| try dir.makePath(name);
}

test "ensureOutDir creates bin, lib, lint, reports" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const tmp = "ziggy-compiler-out-test";
    defer std.fs.cwd().deleteTree(tmp) catch {};

    try ensureOutDir(allocator, tmp);
    var d = try std.fs.cwd().openDir(tmp, .{});
    defer d.close();

    for (subdirs) |name| {
        var sub = try d.openDir(name, .{});
        sub.close();
    }
}
