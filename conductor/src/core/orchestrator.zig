const std = @import("std");
const Agent = @import("agent.zig").Agent;
const Message = @import("agent.zig").Message;
const State = @import("agent.zig").State;
const Allocator = std.mem.Allocator;

/// Task definition
pub const Task = struct {
    id: u64,
    name: []const u8,
    prompt: []const u8,
    assigned_to: ?[]const u8,
    status: Status,
    result: ?[]const u8,
    created_at: i64,
    completed_at: ?i64,

    pub const Status = enum {
        pending,
        assigned,
        running,
        completed,
        failed,
        cancelled,
    };
};

/// Orchestrator — coordinates multiple agents
pub const Orchestrator = struct {
    allocator: Allocator,
    agents: std.StringHashMap(*Agent),
    tasks: std.ArrayList(Task),
    task_counter: u64,
    running: bool,

    const Self = @This();

    pub fn init(allocator: Allocator) Self {
        return .{
            .allocator = allocator,
            .agents = std.StringHashMap(*Agent).init(allocator),
            .tasks = std.ArrayList(Task).init(allocator),
            .task_counter = 0,
            .running = false,
        };
    }

    pub fn deinit(self: *Self) void {
        var it = self.agents.valueIterator();
        while (it.next()) |agent| {
            agent.*.deinit();
            self.allocator.destroy(agent.*);
        }
        self.agents.deinit();
        self.tasks.deinit();
    }

    pub fn spawn(self: *Self, id: []const u8, role: []const u8) !*Agent {
        const agent = try self.allocator.create(Agent);
        agent.* = Agent.init(self.allocator, id, role);
        try self.agents.put(id, agent);
        return agent;
    }

    pub fn submit(self: *Self, name: []const u8, prompt: []const u8) !u64 {
        self.task_counter += 1;
        try self.tasks.append(.{
            .id = self.task_counter,
            .name = name,
            .prompt = prompt,
            .assigned_to = null,
            .status = .pending,
            .result = null,
            .created_at = std.time.timestamp(),
            .completed_at = null,
        });
        return self.task_counter;
    }

    pub fn assign(self: *Self, task_id: u64, agent_id: []const u8) !void {
        for (self.tasks.items) |*task| {
            if (task.id == task_id) {
                if (self.agents.get(agent_id)) |agent| {
                    task.assigned_to = agent_id;
                    task.status = .assigned;

                    try agent.receive(.{
                        .id = task_id,
                        .from = "orchestrator",
                        .to = agent_id,
                        .kind = .task,
                        .payload = task.prompt,
                        .timestamp = std.time.timestamp(),
                    });
                }
                return;
            }
        }
    }

    pub fn tick(self: *Self) !void {
        var it = self.agents.valueIterator();
        while (it.next()) |agent| {
            if (try agent.*.process()) |response| {
                // Route response
                if (self.agents.get(response.to)) |target| {
                    try target.receive(response);
                }
            }

            // Flush outbox
            while (agent.*.outbox.items.len > 0) {
                const msg = agent.*.outbox.orderedRemove(0);
                if (self.agents.get(msg.to)) |target| {
                    try target.receive(msg);
                }
            }
        }
    }

    pub fn status(self: *Self) struct { agents: usize, pending: usize, running: usize } {
        var pending: usize = 0;
        var running: usize = 0;

        for (self.tasks.items) |task| {
            switch (task.status) {
                .pending => pending += 1,
                .running, .assigned => running += 1,
                else => {},
            }
        }

        return .{
            .agents = self.agents.count(),
            .pending = pending,
            .running = running,
        };
    }
};

test "orchestrator basic" {
    const allocator = std.testing.allocator;
    var orch = Orchestrator.init(allocator);
    defer orch.deinit();

    _ = try orch.spawn("agent-1", "coder");
    _ = try orch.spawn("agent-2", "reviewer");

    const task_id = try orch.submit("test-task", "write hello world");
    try orch.assign(task_id, "agent-1");

    const s = orch.status();
    try std.testing.expectEqual(@as(usize, 2), s.agents);
}
