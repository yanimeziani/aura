//! Explicit no-op memory backend.
//!
//! Used when `memory.backend = "none"` to disable persistence
//! while keeping the runtime wiring stable.

const std = @import("std");
const root = @import("../root.zig");
const Memory = root.Memory;
const MemoryCategory = root.MemoryCategory;
const MemoryEntry = root.MemoryEntry;

pub const NoneMemory = struct {
    allocator: ?std.mem.Allocator = null,
    const Self = @This();

    pub fn init() Self {
        return Self{};
    }

    pub fn deinit(_: *Self) void {}

    fn implName(_: *anyopaque) []const u8 {
        return "none";
    }

    fn implStore(_: *anyopaque, _: []const u8, _: []const u8, _: MemoryCategory, _: ?[]const u8) anyerror!void {}

    fn implRecall(_: *anyopaque, allocator: std.mem.Allocator, _: []const u8, _: usize, _: ?[]const u8) anyerror![]MemoryEntry {
        return allocator.alloc(MemoryEntry, 0);
    }

    fn implGet(_: *anyopaque, _: std.mem.Allocator, _: []const u8) anyerror!?MemoryEntry {
        return null;
    }

    fn implList(_: *anyopaque, allocator: std.mem.Allocator, _: ?MemoryCategory, _: ?[]const u8) anyerror![]MemoryEntry {
        return allocator.alloc(MemoryEntry, 0);
    }

    fn implForget(_: *anyopaque, _: []const u8) anyerror!bool {
        return false;
    }

    fn implCount(_: *anyopaque) anyerror!usize {
        return 0;
    }

    fn implHealthCheck(_: *anyopaque) bool {
        return true;
    }

    fn implDeinit(ptr: *anyopaque) void {
        const self_: *Self = @ptrCast(@alignCast(ptr));
        if (self_.allocator) |alloc| {
            alloc.destroy(self_);
        }
    }

    const vtable = Memory.VTable{
        .name = &implName,
        .store = &implStore,
        .recall = &implRecall,
        .get = &implGet,
        .list = &implList,
        .forget = &implForget,
        .count = &implCount,
        .healthCheck = &implHealthCheck,
        .deinit = &implDeinit,
    };

    pub fn memory(self: *Self) Memory {
        return .{
            .ptr = @ptrCast(self),
            .vtable = &vtable,
        };
    }
};

// ── Tests ──────────────────────────────────────────────────────────

test "none memory is noop" {
    var mem = NoneMemory.init();
    defer mem.deinit();
    const m = mem.memory();

    try std.testing.expectEqualStrings("none", m.name());

    try m.store("k", "v", .core, null);

    const got = try m.get(std.testing.allocator, "k");
    try std.testing.expect(got == null);

    const recalled = try m.recall(std.testing.allocator, "k", 10, null);
    defer std.testing.allocator.free(recalled);
    try std.testing.expectEqual(@as(usize, 0), recalled.len);

    const listed = try m.list(std.testing.allocator, null, null);
    defer std.testing.allocator.free(listed);
    try std.testing.expectEqual(@as(usize, 0), listed.len);

    const forgotten = try m.forget("k");
    try std.testing.expect(!forgotten);

    try std.testing.expectEqual(@as(usize, 0), try m.count());

    try std.testing.expect(m.healthCheck());
}

test "none memory accepts session_id param" {
    var mem = NoneMemory.init();
    defer mem.deinit();
    const m = mem.memory();

    // Store with session_id
    try m.store("k", "v", .core, "session-123");

    // Recall with session_id
    const recalled = try m.recall(std.testing.allocator, "k", 10, "session-123");
    defer std.testing.allocator.free(recalled);
    try std.testing.expectEqual(@as(usize, 0), recalled.len);

    // List with session_id
    const listed = try m.list(std.testing.allocator, null, "session-123");
    defer std.testing.allocator.free(listed);
    try std.testing.expectEqual(@as(usize, 0), listed.len);
}
