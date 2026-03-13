const std = @import("std");

pub const JniCallbacks = struct {
    onOutput: fn ([*]const u8) callconv(.C) void,
    onError: fn ([*]const u8) callconv(.C) void,
};

var callbacks: ?*JniCallbacks = null;

export fn shell_init() [*]const u8 {
    const version = "Pegasus Shell v0.1.0";
    return (try std.heap.c_allocator.dupeZ(u8, version)).ptr;
}

export fn shell_set_callbacks(output_fn: fn ([*]const u8) callconv(.C) void, error_fn: fn ([*]const u8) callconv(.C) void) void {
    callbacks = @as([*]JniCallbacks, @ptrFromInt(@intFromPtr(&JniCallbacks{
        .onOutput = output_fn,
        .onError = error_fn,
    })))[0..1].ptr;
}

export fn shell_execute(command: [*]const u8) i32 {
    if (callbacks == null) return -1;

    const cmd = std.mem.span(command);

    if (std.mem.startsWith(u8, cmd, "echo ")) {
        const text = cmd[5..];
        callbacks.?.onOutput(text);
        return 0;
    }

    if (std.mem.eql(u8, cmd, "help")) {
        const help: [:0]const u8 = "Available commands: echo, help, date, whoami, pwd, ls, cd, cat, agents";
        callbacks.?.onOutput(help.ptr);
        return 0;
    }

    if (std.mem.eql(u8, cmd, "date")) {
        const now = std.time.Timestamp.now();
        var buf: [32]u8 = undefined;
        const str = std.fmt.bufPrint(&buf, "{}", .{now}) catch return -1;
        callbacks.?.onOutput(str.ptr);
        return 0;
    }

    if (std.mem.eql(u8, cmd, "whoami")) {
        callbacks.?.onOutput("pegasus".ptr);
        return 0;
    }

    if (std.mem.eql(u8, cmd, "pwd")) {
        callbacks.?.onOutput("/data/data/org.dragun.pegasus".ptr);
        return 0;
    }

    const err_buf = try std.fmt.allocPrint(std.heap.c_allocator, "Unknown command: {s}", .{cmd});
    defer std.heap.c_allocator.free(err_buf);
    callbacks.?.onError(err_buf.ptr);

    return 0;
}

export fn shell_cleanup() void {
    callbacks = null;
}
