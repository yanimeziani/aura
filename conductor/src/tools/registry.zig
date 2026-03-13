const std = @import("std");
const Allocator = std.mem.Allocator;

/// Tool parameter
pub const Param = struct {
    name: []const u8,
    description: []const u8,
    param_type: Type,
    required: bool,

    pub const Type = enum {
        string,
        number,
        boolean,
        array,
        object,
    };
};

/// Tool definition
pub const Tool = struct {
    name: []const u8,
    description: []const u8,
    params: []const Param,
    handler: *const fn (std.json.Value) anyerror!std.json.Value,
};

/// Tool registry
pub const Registry = struct {
    allocator: Allocator,
    tools: std.StringHashMap(Tool),

    const Self = @This();

    pub fn init(allocator: Allocator) Self {
        return .{
            .allocator = allocator,
            .tools = std.StringHashMap(Tool).init(allocator),
        };
    }

    pub fn deinit(self: *Self) void {
        self.tools.deinit();
    }

    pub fn register(self: *Self, tool: Tool) !void {
        try self.tools.put(tool.name, tool);
    }

    pub fn get(self: *Self, name: []const u8) ?Tool {
        return self.tools.get(name);
    }

    pub fn invoke(self: *Self, name: []const u8, args: std.json.Value) !std.json.Value {
        if (self.get(name)) |tool| {
            return tool.handler(args);
        }
        return error.ToolNotFound;
    }

    pub fn list(self: *Self) []const []const u8 {
        var names = std.ArrayList([]const u8).init(self.allocator);
        var it = self.tools.keyIterator();
        while (it.next()) |key| {
            names.append(key.*) catch {};
        }
        return names.items;
    }

    /// Export as JSON schema (for LLM function calling)
    pub fn toSchema(self: *Self, allocator: Allocator) ![]const u8 {
        var buffer = std.ArrayList(u8).init(allocator);
        var writer = buffer.writer();

        try writer.writeAll("[");
        var first = true;
        var it = self.tools.valueIterator();

        while (it.next()) |tool| {
            if (!first) try writer.writeAll(",");
            first = false;

            try writer.print(
                \\{{"name":"{s}","description":"{s}","parameters":{{"type":"object","properties":{{
            , .{ tool.name, tool.description });

            var pfirst = true;
            for (tool.params) |param| {
                if (!pfirst) try writer.writeAll(",");
                pfirst = false;
                try writer.print(
                    \\"{s}":{{"type":"{s}","description":"{s}"}}
                , .{ param.name, @tagName(param.param_type), param.description });
            }

            try writer.writeAll("}}}}");
        }

        try writer.writeAll("]");
        return buffer.items;
    }
};

// Built-in tools
pub fn bashHandler(args: std.json.Value) anyerror!std.json.Value {
    _ = args;
    return std.json.Value{ .string = "bash result" };
}

pub fn readFileHandler(args: std.json.Value) anyerror!std.json.Value {
    _ = args;
    return std.json.Value{ .string = "file content" };
}

pub fn writeFileHandler(args: std.json.Value) anyerror!std.json.Value {
    _ = args;
    return std.json.Value{ .string = "ok" };
}

/// Register built-in tools
pub fn registerBuiltins(registry: *Registry) !void {
    try registry.register(.{
        .name = "bash",
        .description = "Execute bash command",
        .params = &[_]Param{
            .{ .name = "command", .description = "Command to execute", .param_type = .string, .required = true },
        },
        .handler = bashHandler,
    });

    try registry.register(.{
        .name = "read_file",
        .description = "Read file contents",
        .params = &[_]Param{
            .{ .name = "path", .description = "File path", .param_type = .string, .required = true },
        },
        .handler = readFileHandler,
    });

    try registry.register(.{
        .name = "write_file",
        .description = "Write to file",
        .params = &[_]Param{
            .{ .name = "path", .description = "File path", .param_type = .string, .required = true },
            .{ .name = "content", .description = "Content to write", .param_type = .string, .required = true },
        },
        .handler = writeFileHandler,
    });
}

test "registry basic" {
    const allocator = std.testing.allocator;
    var registry = Registry.init(allocator);
    defer registry.deinit();

    try registerBuiltins(&registry);
    try std.testing.expect(registry.get("bash") != null);
}
