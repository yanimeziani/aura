const std = @import("std");
const Allocator = std.mem.Allocator;

/// Agent states
pub const State = enum {
    idle,
    thinking,
    executing,
    waiting,
    error,
    terminated,
};

/// Message between agents
pub const Message = struct {
    id: u64,
    from: []const u8,
    to: []const u8,
    kind: Kind,
    payload: []const u8,
    timestamp: i64,

    pub const Kind = enum {
        task,
        result,
        query,
        response,
        error,
        system,
    };
};

/// Agent capability
pub const Capability = struct {
    name: []const u8,
    description: []const u8,
    handler: *const fn (*Agent, []const u8) anyerror![]const u8,
};

/// Core Agent runtime
pub const Agent = struct {
    allocator: Allocator,
    id: []const u8,
    role: []const u8,
    state: State,
    capabilities: std.ArrayList(Capability),
    inbox: std.ArrayList(Message),
    outbox: std.ArrayList(Message),
    context: []const u8,
    msg_counter: u64,

    const Self = @This();

    pub fn init(allocator: Allocator, id: []const u8, role: []const u8) Self {
        return .{
            .allocator = allocator,
            .id = id,
            .role = role,
            .state = .idle,
            .capabilities = std.ArrayList(Capability).init(allocator),
            .inbox = std.ArrayList(Message).init(allocator),
            .outbox = std.ArrayList(Message).init(allocator),
            .context = "",
            .msg_counter = 0,
        };
    }

    pub fn deinit(self: *Self) void {
        self.capabilities.deinit();
        self.inbox.deinit();
        self.outbox.deinit();
    }

    pub fn register(self: *Self, cap: Capability) !void {
        try self.capabilities.append(cap);
    }

    pub fn send(self: *Self, to: []const u8, kind: Message.Kind, payload: []const u8) !void {
        self.msg_counter += 1;
        try self.outbox.append(.{
            .id = self.msg_counter,
            .from = self.id,
            .to = to,
            .kind = kind,
            .payload = payload,
            .timestamp = std.time.timestamp(),
        });
    }

    pub fn receive(self: *Self, msg: Message) !void {
        try self.inbox.append(msg);
    }

    pub fn process(self: *Self) !?Message {
        if (self.inbox.items.len == 0) return null;

        self.state = .thinking;
        const msg = self.inbox.orderedRemove(0);

        // Find matching capability
        for (self.capabilities.items) |cap| {
            if (std.mem.eql(u8, cap.name, msg.payload)) {
                self.state = .executing;
                const result = try cap.handler(self, msg.payload);
                self.state = .idle;

                return .{
                    .id = self.msg_counter + 1,
                    .from = self.id,
                    .to = msg.from,
                    .kind = .result,
                    .payload = result,
                    .timestamp = std.time.timestamp(),
                };
            }
        }

        self.state = .idle;
        return null;
    }
};

test "agent basic" {
    const allocator = std.testing.allocator;
    var agent = Agent.init(allocator, "test-agent", "worker");
    defer agent.deinit();

    try std.testing.expectEqual(State.idle, agent.state);
    try std.testing.expectEqualStrings("test-agent", agent.id);
}
