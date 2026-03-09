//! Alarm categories and emission. Ziggy compiler — Zig 0.15.2.
//! See docs/ziggy-compiler.md: security, performance, syntax, architecture.

const std = @import("std");

pub const AlarmCategory = enum {
    security,
    performance,
    syntax,
    architecture,
};

/// Emit one alarm line to the given writer (e.g. stderr). Stub: writes structured line.
pub fn emitAlarm(writer: anytype, category: AlarmCategory, msg: []const u8) !void {
    try writer.print("level=alarm category={s} msg={s}\n", .{ @tagName(category), msg });
}
