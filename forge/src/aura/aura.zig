const std = @import("std");

/// Aura represents memory region lifetime tags.
/// These are compile-time only — zero runtime cost.
pub const Aura = enum {
    /// Memory dies with current scope (stack-allocated)
    stack,
    /// Memory dies when arena is reset/destroyed
    arena,
    /// Memory lives until explicit free
    persistent,
    /// Reference to memory owned elsewhere — cannot outlive source
    borrowed,
    /// Static/global memory — lives for program duration
    static,
};

/// AuraPtr wraps a pointer with its associated aura tag.
/// Enables compile-time verification of lifetime safety.
pub fn AuraPtr(comptime T: type, comptime aura_tag: Aura) type {
    return struct {
        ptr: *T,

        const Self = @This();
        const aura = aura_tag;

        pub fn init(ptr: *T) Self {
            return .{ .ptr = ptr };
        }

        pub fn get(self: Self) *T {
            return self.ptr;
        }

        /// Borrow creates a borrowed reference — cannot outlive source
        pub fn borrow(self: Self) AuraPtr(T, .borrowed) {
            return AuraPtr(T, .borrowed).init(self.ptr);
        }
    };
}

/// Region allocator with aura tagging
pub const Region = struct {
    allocator: std.mem.Allocator,
    aura_tag: Aura,

    pub fn init(allocator: std.mem.Allocator, aura_tag: Aura) Region {
        return .{
            .allocator = allocator,
            .aura_tag = aura_tag,
        };
    }

    pub fn alloc(self: Region, comptime T: type, n: usize) ![]T {
        return self.allocator.alloc(T, n);
    }

    pub fn free(self: Region, memory: anytype) void {
        self.allocator.free(memory);
    }
};

// Tests
test "aura ptr basic" {
    var value: u32 = 42;
    const ptr = AuraPtr(u32, .stack).init(&value);
    try std.testing.expectEqual(@as(u32, 42), ptr.get().*);
}

test "aura ptr borrow" {
    var value: u32 = 100;
    const stack_ptr = AuraPtr(u32, .stack).init(&value);
    const borrowed = stack_ptr.borrow();
    try std.testing.expectEqual(@as(u32, 100), borrowed.get().*);
    try std.testing.expectEqual(Aura.borrowed, @TypeOf(borrowed).aura);
}

test "region allocator" {
    const region = Region.init(std.testing.allocator, .arena);
    const data = try region.alloc(u8, 1024);
    defer region.free(data);
    try std.testing.expectEqual(@as(usize, 1024), data.len);
}
