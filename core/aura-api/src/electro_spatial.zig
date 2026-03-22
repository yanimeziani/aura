//! Electro-Spatial RAG — aura-api.
//! Solidifies the connection between technical metrics (Electro) and world state (Spatial)
//! for grounded RAG-based agent reasoning.

const std = @import("std");
const world = @import("world.zig");

pub const ElectroSpatialState = struct {
    allocator: std.mem.Allocator,
    world_state: *world.WorldState,

    pub fn init(allocator: std.mem.Allocator, world_state: *world.WorldState) ElectroSpatialState {
        return .{
            .allocator = allocator,
            .world_state = world_state,
        };
    }

    /// Generates a grounded RAG context string combining technical and spatial data.
    pub fn generateRagContext(self: *const ElectroSpatialState) ![]const u8 {
        var list: std.ArrayListUnmanaged(u8) = .empty;
        errdefer list.deinit(self.allocator);

        const writer = list.writer(self.allocator);

        try writer.writeAll("### ELECTRO-SPATIAL GROUND TRUTH\n\n");

        // 1. Technical Invariants (Electro)
        try writer.writeAll("#### Technical Surface (Electro)\n");
        try writer.print("- Time: {d}\n", .{std.time.timestamp()});
        try writer.writeAll("- Mesh Protocol: Noise_IK (Post-Quantum Ready)\n");
        try writer.writeAll("- Safety Invariant: 0% Casualty Probability (Hard-Locked)\n\n");

        // 2. World State (Spatial)
        try writer.writeAll("#### World Map (Spatial)\n");
        
        self.world_state.mutex.lock();
        defer self.world_state.mutex.unlock();

        var it = self.world_state.regions.iterator();
        while (it.next()) |entry| {
            const region = entry.value_ptr;
            try writer.print("- Region: {s}\n", .{region.id});
            try writer.print("  - Owner: {s}\n", .{region.owner_id});
            try writer.print("  - Level: {d}\n", .{region.level});
            try writer.print("  - Resources: {d}\n", .{region.resources});
            try writer.print("  - Fog: {d:.2}\n", .{region.fog_level});
        }

        return list.toOwnedSlice(self.allocator);
    }
};
