const std = @import("std");
const hardware = @import("../hardware.zig");

const LockdownContext = struct {
    disconnected: bool = false,
    reconnected: bool = false,
    substring: []const u8,
    mutex: std.Thread.Mutex = .{},
    cond: std.Thread.Condition = .{},
};

/// Perform a hardware-based Human-In-The-Loop (HITL) lockdown.
/// Halts execution and waits for a physical "disconnect and reconnect" of a specific USB device.
/// This ensures a human is physically present and authorizes the critical decision.
pub fn performLockdown(allocator: std.mem.Allocator, device_id_substring: []const u8) !void {
    std.log.info("LOCKDOWN: Critical decision requires physical authorization.", .{});
    std.log.info("ACTION: Please disconnect and reconnect the private hybrid USB device (ID contains '{s}').", .{device_id_substring});

    var ctx = LockdownContext{ .substring = device_id_substring };
    
    var monitor = hardware.HotplugMonitor{
        .allocator = allocator,
        .callback = &onDeviceEvent,
        .callback_ctx = &ctx,
    };

    try hardware.startHotplugMonitor(&monitor);
    defer hardware.stopHotplugMonitor(&monitor);

    ctx.mutex.lock();
    defer ctx.mutex.unlock();

    // 1. Wait for disconnect
    while (!ctx.disconnected) {
        ctx.cond.wait(&ctx.mutex);
    }
    std.log.warn("USB device DISCONNECTED. Verification step 1/2 complete. Waiting for reconnect...", .{});

    // 2. Wait for reconnect
    while (!ctx.reconnected) {
        ctx.cond.wait(&ctx.mutex);
    }
    std.log.info("USB device RECONNECTED. Verification step 2/2 complete. Authorization GRANTED.", .{});
}

fn onDeviceEvent(event: hardware.DeviceEvent, context: ?*anyopaque) void {
    const ctx: *LockdownContext = @ptrCast(@alignCast(context.?));
    
    // Check if the device ID matches the requested substring (e.g. VID/PID or model name)
    if (std.mem.indexOf(u8, event.device_id, ctx.substring) == null) return;

    ctx.mutex.lock();
    defer ctx.mutex.unlock();

    if (std.mem.eql(u8, event.action, "remove")) {
        ctx.disconnected = true;
        ctx.cond.signal();
    } else if (std.mem.eql(u8, event.action, "add")) {
        if (ctx.disconnected) {
            ctx.reconnected = true;
            ctx.cond.signal();
        }
    }
}
