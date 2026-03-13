const std = @import("std");
const aura = @import("aura/aura.zig");

pub fn main() !void {
    const stdout = std.io.getStdOut().writer();
    try stdout.print("Forge v0.1.0 — Systems language with Aura memory regions\n", .{});
    try stdout.print("Usage: forge <source.frg>\n", .{});
}

test "forge initializes" {
    // Basic smoke test
    const allocator = std.testing.allocator;
    _ = allocator;
}
