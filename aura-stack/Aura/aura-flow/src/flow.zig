const std = @import("std");
const Allocator = std.mem.Allocator;

pub const NodeKind = enum {
    trigger,
    stripe_parse,
    http_request,
    subprocess,
    condition,
    fulfillment_template,
};

pub const Node = struct {
    id: []const u8,
    kind: NodeKind,
    config: std.json.Value,
    next: ?[]const u8 = null,
    on_true: ?[]const u8 = null, // for condition
    on_false: ?[]const u8 = null, // for condition
};

pub const Workflow = struct {
    name: []const u8,
    nodes: std.StringArrayMap(Node),
    allocator: Allocator,
    arena: *std.heap.ArenaAllocator,

    pub fn deinit(self: *Workflow) void {
        const arena_ptr = self.arena;
        const alloc = arena_ptr.child_allocator;
        arena_ptr.deinit();
        alloc.destroy(arena_ptr);
    }

    pub fn parse(allocator: Allocator, json_text: []const u8) !*Workflow {
        var arena = try allocator.create(std.heap.ArenaAllocator);
        arena.* = std.heap.ArenaAllocator.init(allocator);
        const arena_alloc = arena.allocator();

        const parsed = try std.json.parseFromSlice(std.json.Value, arena_alloc, json_text, .{});
        // parsed.deinit() is not needed because we use arena

        const root = parsed.value;
        if (root != .object) return error.InvalidJson;

        const name_val = root.object.get("name") orelse return error.MissingName;
        const name = try arena_alloc.dupe(u8, name_val.string);
        
        var nodes = std.StringArrayMap(Node).init(arena_alloc);

        const nodes_val = root.object.get("nodes") orelse return error.MissingNodes;
        if (nodes_val != .array) return error.InvalidNodes;

        for (nodes_val.array.items) |node_val| {
            if (node_val != .object) continue;
            const obj = node_val.object;
            const id_val = obj.get("id") orelse continue;
            const id = try arena_alloc.dupe(u8, id_val.string);
            const type_val = obj.get("type") orelse continue;
            const kind_str = type_val.string;
            const kind = std.meta.stringToEnum(NodeKind, kind_str) orelse .trigger;
            
            const next = if (obj.get("next")) |v| try arena_alloc.dupe(u8, v.string) else null;
            const on_true = if (obj.get("on_true")) |v| try arena_alloc.dupe(u8, v.string) else null;
            const on_false = if (obj.get("on_false")) |v| try arena_alloc.dupe(u8, v.string) else null;
            
            const config = if (obj.get("config")) |v| v else std.json.Value{ .object = std.json.ObjectMap.init(arena_alloc) };

            try nodes.put(id, .{
                .id = id,
                .kind = kind,
                .config = config,
                .next = next,
                .on_true = on_true,
                .on_false = on_false,
            });
        }

        const wf = try arena_alloc.create(Workflow);
        wf.* = .{
            .name = name,
            .nodes = nodes,
            .allocator = arena_alloc,
            .arena = arena,
        };
        return wf;
    }
};

test "parse simple workflow" {
    const allocator = std.testing.allocator;
    const json = 
        \\{
        \\  "name": "test-flow",
        \\  "nodes": [
        \\    { "id": "start", "type": "trigger", "next": "end" },
        \\    { "id": "end", "type": "subprocess", "config": { "cmd": "echo done" } }
        \\  ]
        \\}
    ;

    const wf = try Workflow.parse(allocator, json);
    defer wf.deinit();

    try std.testing.expectEqualStrings("test-flow", wf.name);
    try std.testing.expect(wf.nodes.contains("start"));
    try std.testing.expect(wf.nodes.contains("end"));
    
    const start = wf.nodes.get("start").?;
    try std.testing.expectEqual(NodeKind.trigger, start.kind);
    try std.testing.expectEqualStrings("end", start.next.?);
}
