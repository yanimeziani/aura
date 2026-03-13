const std = @import("std");
const Agent = @import("core/agent.zig").Agent;
const Orchestrator = @import("core/orchestrator.zig").Orchestrator;
const LLM = @import("providers/llm.zig");
const Registry = @import("tools/registry.zig").Registry;
const registerBuiltins = @import("tools/registry.zig").registerBuiltins;

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const stdout = std.io.getStdOut().writer();

    try stdout.print(
        \\
        \\  ╔═══════════════════════════════════════╗
        \\  ║         C O N D U C T O R             ║
        \\  ║     Multi-Agent Orchestration         ║
        \\  ╚═══════════════════════════════════════╝
        \\
        \\
    , .{});

    // Initialize orchestrator
    var orch = Orchestrator.init(allocator);
    defer orch.deinit();

    // Initialize tool registry
    var registry = Registry.init(allocator);
    defer registry.deinit();
    try registerBuiltins(&registry);

    // Spawn agents
    const coder = try orch.spawn("coder", "code-generation");
    const reviewer = try orch.spawn("reviewer", "code-review");
    const executor = try orch.spawn("executor", "task-execution");

    _ = coder;
    _ = reviewer;
    _ = executor;

    const status = orch.status();
    try stdout.print("Agents: {d} | Tools: {d}\n", .{ status.agents, registry.tools.count() });
    try stdout.print("Status: Ready\n\n", .{});

    // CLI loop
    try stdout.print("conductor> ", .{});

    const stdin = std.io.getStdIn().reader();
    var buf: [1024]u8 = undefined;

    while (try stdin.readUntilDelimiterOrEof(&buf, '\n')) |line| {
        const cmd = std.mem.trim(u8, line, " \t\r\n");

        if (cmd.len == 0) {
            try stdout.print("conductor> ", .{});
            continue;
        }

        if (std.mem.eql(u8, cmd, "quit") or std.mem.eql(u8, cmd, "exit")) {
            break;
        }

        if (std.mem.eql(u8, cmd, "status")) {
            const s = orch.status();
            try stdout.print("Agents: {d} | Pending: {d} | Running: {d}\n", .{ s.agents, s.pending, s.running });
        } else if (std.mem.eql(u8, cmd, "agents")) {
            try stdout.print("Active agents:\n", .{});
            var it = orch.agents.keyIterator();
            while (it.next()) |key| {
                try stdout.print("  - {s}\n", .{key.*});
            }
        } else if (std.mem.eql(u8, cmd, "tools")) {
            try stdout.print("Available tools:\n", .{});
            var it = registry.tools.keyIterator();
            while (it.next()) |key| {
                try stdout.print("  - {s}\n", .{key.*});
            }
        } else if (std.mem.eql(u8, cmd, "help")) {
            try stdout.print(
                \\Commands:
                \\  status  - Show orchestrator status
                \\  agents  - List active agents
                \\  tools   - List available tools
                \\  quit    - Exit conductor
                \\
            , .{});
        } else {
            try stdout.print("Unknown command: {s}\n", .{cmd});
        }

        try stdout.print("conductor> ", .{});
    }

    try stdout.print("\nShutting down...\n", .{});
}

test "main modules" {
    _ = @import("core/agent.zig");
    _ = @import("core/orchestrator.zig");
    _ = @import("providers/llm.zig");
    _ = @import("tools/registry.zig");
}
