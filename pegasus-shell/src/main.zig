const std = @import("std");
const builtin = @import("builtin");

const ShellEngine = @import("shell_engine.zig").ShellEngine;
const jni = @import("jni.zig");

pub fn main() void {
    std.debug.print("Pegasus Shell Library\n", .{});
}
