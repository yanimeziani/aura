const std = @import("std");

const VitalStatus = enum {
    green,    // 0% Casualty Probability - Biological Integrity Intact
    yellow,   // < 1% Probability - System Degradation Detected
    red,      // > 1% Probability - INVARIANT BREACHED
};

const Node = struct {
    id: []const u8,
    label: []const u8,
    level: u8,
    healthy: bool,
};

pub fn main() !void {
    var buffer: [8192]u8 = undefined;
    var stdout_writer = std.fs.File.stdout().writer(&buffer);
    const stdout = &stdout_writer.interface;
    
    // Simulated mesh state
    const status = VitalStatus.green;
    const nodes = [_]Node{
        .{ .id = "bi", .label = "Biological Invariant (Ground Truth)", .level = 0, .healthy = true },
        .{ .id = "house", .label = "Sovereign Housing", .level = 2, .healthy = true },
        .{ .id = "edu", .label = "Montessori Education", .level = 2, .healthy = true },
        .{ .id = "comm", .label = "Resource Commerce", .level = 2, .healthy = true },
    };

    try stdout.print("\x1b[2J\x1b[H", .{});
    
    // EQUANIMOUS VITAL RENDERER (High Contrast)
    switch (status) {
        .green => {
            try stdout.print("\x1b[42;30m", .{}); // Green background, black text
            try stdout.print("[ SAFE ] BIOLOGICAL INTEGRITY: 100% | EQUANIMITY: ACTIVE ", .{});
        },
        .yellow => {
            try stdout.print("\x1b[43;30m", .{}); // Yellow background, black text
            try stdout.print("[ WARN ] SYSTEM DEGRADATION: MINIMAL RISK TO LIFE ", .{});
        },
        .red => {
            try stdout.print("\x1b[41;37;1m", .{}); // Red background, white bold text
            try stdout.print("[ CRIT ] INVARIANT BREACH: IMMEDIATE ACTION REQUIRED ", .{});
        },
    }
    try stdout.print("\x1b[0m\n\n", .{});

    try stdout.print("EQUANIMOUS LIVING CONDITIONS STATUS:\n", .{});
    for (nodes) |node| {
        const color = if (node.healthy) "\x1b[32m" else "\x1b[31m";
        const indent = node.level * 2;
        var i: usize = 0;
        while (i < indent) : (i += 1) try stdout.print(" ", .{});
        try stdout.print("{s}[*] {s} (L{d})\x1b[0m\n", .{ color, node.label, node.level });
    }

    // Vital Heartbeat (Auditory Accessibility: ANSI Bell)
    if (status == .green) {
        try stdout.print("\n[PULSE] . . . . . .\n", .{});
    } else {
        try stdout.print("\x07\n[ALARM] ! ! ! ! ! !\x07\n", .{}); // System Bell
    }

    try stdout.print("\n[ESC] to exit | [TAB] to toggle accessibility modes\n", .{});
    try stdout.flush();
}
