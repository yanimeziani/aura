const std = @import("std");
const flow = @import("flow.zig");
const stripe = @import("stripe.zig");
const Allocator = std.mem.Allocator;

pub const ExecutionContext = struct {
    allocator: Allocator,
    arena: *std.heap.ArenaAllocator,
    state: std.StringArrayMap(std.json.Value),
    logs: std.ArrayList([]const u8),

    pub fn init(allocator: Allocator) !*ExecutionContext {
        var arena = try allocator.create(std.heap.ArenaAllocator);
        arena.* = std.heap.ArenaAllocator.init(allocator);
        const arena_alloc = arena.allocator();

        const ctx = try arena_alloc.create(ExecutionContext);
        ctx.* = .{
            .allocator = arena_alloc,
            .arena = arena,
            .state = std.StringArrayMap(std.json.Value).init(arena_alloc),
            .logs = std.ArrayList([]const u8).init(arena_alloc),
        };
        return ctx;
    }

    pub fn deinit(self: *ExecutionContext) void {
        const arena_ptr = self.arena;
        const alloc = arena_ptr.child_allocator;
        arena_ptr.deinit();
        alloc.destroy(arena_ptr);
    }

    pub fn log(self: *ExecutionContext, msg: []const u8) !void {
        try self.logs.append(try self.allocator.dupe(u8, msg));
    }

    pub fn set(self: *ExecutionContext, key: []const u8, value: std.json.Value) !void {
        // We need to deep copy the value into our arena
        const copied = try deepCopyJson(self.allocator, value);
        try self.state.put(try self.allocator.dupe(u8, key), copied);
    }
};

fn deepCopyJson(allocator: Allocator, val: std.json.Value) !std.json.Value {
    switch (val) {
        .null, .bool, .integer, .float, .string => return val, // primitive or immutable-ish
        .array => {
            var new_arr = std.json.Array.init(allocator);
            for (val.array.items) |item| {
                try new_arr.append(try deepCopyJson(allocator, item));
            }
            return .{ .array = new_arr };
        },
        .object => {
            var new_obj = std.json.ObjectMap.init(allocator);
            var it = val.object.iterator();
            while (it.next()) |entry| {
                try new_obj.put(try allocator.dupe(u8, entry.key_ptr.*), try deepCopyJson(allocator, entry.value_ptr.*));
            }
            return .{ .object = new_obj };
        },
    }
}

pub fn execute(wf: *flow.Workflow, ctx: *ExecutionContext) !void {
    var current_id: ?[]const u8 = "start"; // assume entry point is 'start'
    
    while (current_id) |id| {
        const node = wf.nodes.get(id) orelse {
            try ctx.log("Node not found");
            break;
        };

        try ctx.log(try std.fmt.allocPrint(ctx.allocator, "Executing node: {s} ({s})", .{ id, @tagName(node.kind) }));

        const result = try executeNode(node, ctx);
        
        current_id = switch (node.kind) {
            .condition => if (result) node.on_true else node.on_false,
            else => node.next,
        };
    }
}

fn executeNode(node: flow.Node, ctx: *ExecutionContext) !bool {
    switch (node.kind) {
        .trigger => return true,
        .subprocess => {
            const cmd = node.config.object.get("cmd").?.string;
            var argv = std.ArrayList([]const u8).init(ctx.allocator);
            var it = std.mem.splitScalar(u8, cmd, ' ');
            while (it.next()) |arg| {
                if (arg.len > 0) try argv.append(arg);
            }
            
            var child = std.process.Child.init(argv.items, ctx.allocator);
            child.stdout_behavior = .Pipe;
            child.stderr_behavior = .Pipe;
            
            try child.spawn();
            
            const stdout = try child.stdout.?.readToEndAlloc(ctx.allocator, 10 * 1024 * 1024);
            const stderr = try child.stderr.?.readToEndAlloc(ctx.allocator, 10 * 1024 * 1024);
            
            const term = try child.wait();
            
            try ctx.set("last_stdout", .{ .string = stdout });
            try ctx.set("last_stderr", .{ .string = stderr });
            
            return term == .Exited and term.Exited == 0;
        },
        .http_request => {
            const url = node.config.object.get("url").?.string;
            const method_str = if (node.config.object.get("method")) |m| m.string else "GET";
            const method = std.http.Method.parse(method_str);
            
            var client = std.http.Client{ .allocator = ctx.allocator };
            defer client.deinit();
            
            const uri = try std.Uri.parse(url);
            var req = try client.open(method, uri, .{ .server_header_buffer = try ctx.allocator.alloc(u8, 4096) });
            defer req.deinit();
            
            try req.send();
            try req.finish();
            try req.wait();
            
            const body = try req.reader().readToEndAlloc(ctx.allocator, 10 * 1024 * 1024);
            try ctx.set("last_http_response", .{ .string = body });
            try ctx.set("last_http_status", .{ .integer = @intCast(@intFromEnum(req.response.status)) });
            
            return @intFromEnum(req.response.status) < 400;
        },
        .condition => {
            const key = node.config.object.get("key").?.string;
            const value = node.config.object.get("value").?.string;
            
            if (ctx.state.get(key)) |val| {
                if (val == .string) {
                    return std.mem.eql(u8, val.string, value);
                }
            }
            return false;
        },
        .stripe_parse => {
            if (ctx.state.get("input")) |input| {
                try stripe.parseAndNormalizeStripe(ctx, input);
            }
            return true;
        },
        .fulfillment_template => {
            // This could run a whole predefined workflow but for now let's just log
            try ctx.log("Running fulfillment template");
            return true;
        },
    }
}
