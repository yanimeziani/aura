const std = @import("std");

const Node = struct {
    id: []const u8,
    label: []const u8,
    level: u8,
};

const Edge = struct {
    from: []const u8,
    to: []const u8,
    label: []const u8,
};

const nodes = [_]Node{
    .{ .id = "bi", .label = "Biological Invariant (Ground Truth)", .level = 0 },
    .{ .id = "im", .label = "Immutable Audit (Cross-Node Verification)", .level = 0 },
    .{ .id = "qn", .label = "Quarantine (Isolation of Corruption)", .level = 0 },
    .{ .id = "gw", .label = "Nexa Gateway (Coordination Membrane)", .level = 1 },
    .{ .id = "house", .label = "Living Conditions: Sovereign Housing", .level = 2 },
    .{ .id = "edu", .label = "Living Conditions: Montessori Education", .level = 2 },
    .{ .id = "comm", .label = "Living Conditions: Resource Commerce", .level = 2 },
    .{ .id = "nv", .label = "Hardware Board: NVIDIA NIM", .level = 3 },
    .{ .id = "int", .label = "Hardware Board: Intel (French Tech)", .level = 3 },
    .{ .id = "op", .label = "Operator Authority (HITL)", .level = 5 },
};

const edges = [_]Edge{
    .{ .from = "op", .to = "gw", .label = "Directs" },
    .{ .from = "gw", .to = "bi", .label = "Verifies Integrity" },
    .{ .from = "house", .to = "gw", .label = "Sustains Life" },
    .{ .from = "edu", .to = "gw", .label = "Empowers Cognition" },
    .{ .from = "comm", .to = "gw", .label = "Funds Collective" },
};

pub fn main() !void {
    var buffer: [8192]u8 = undefined;
    var stdout_writer = std.fs.File.stdout().writer(&buffer);
    const stdout = &stdout_writer.interface;

    try stdout.print("\x1b[2J\x1b[H", .{});
    try stdout.print("--- EQUANIMOUS ARCHITECTURE: NEXT LIVING CONDITIONS ---\n\n", .{});

    inline for (nodes) |node| {
        var i: usize = 0;
        while (i < node.level * 4) : (i += 1) try stdout.print(" ", .{});
        try stdout.print("[*] {s} (L{d})\n", .{ node.label, node.level });
    }

    try stdout.print("\nEquanimous Connections:\n", .{});
    inline for (edges) |edge| {
        try stdout.print("  {s} --({s})--> {s}\n", .{ edge.from, edge.label, edge.to });
    }
    try stdout.print("\n[STATUS] Biological Integrity: INTACT | Equanimity: MAINTAINED\n", .{});
    try stdout.print("\n[ESC] to exit | [TAB] to focus\n", .{});
    try stdout.flush();
}
