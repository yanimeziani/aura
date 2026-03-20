//! World State Map logic — aura-api.
//! Handles regions, state transitions, and delta generation.

const std = @import("std");

pub const Region = struct {
    id: []const u8,
    owner_id: []const u8,
    level: u32,
    resources: u32,
    fog_level: f32, // 0.0 = clear, 1.0 = hidden
    last_updated: i64,

    pub fn format(
        self: Region,
        comptime fmt: []const u8,
        options: std.fmt.FormatOptions,
        writer: anytype,
    ) !void {
        _ = fmt;
        _ = options;
        try writer.print(
            "{{\"id\":\"{s}\",\"owner_id\":\"{s}\",\"level\":{d},\"resources\":{d},\"fog_level\":{d},\"last_updated\":{d}}}",
            .{ self.id, self.owner_id, self.level, self.resources, self.fog_level, self.last_updated },
        );
    }
};

pub const Delta = struct {
    type: []const u8 = "delta",
    region_id: []const u8,
    field: []const u8,
    old_value: []const u8,
    new_value: []const u8,

    pub fn format(
        self: Delta,
        comptime fmt: []const u8,
        options: std.fmt.FormatOptions,
        writer: anytype,
    ) !void {
        _ = fmt;
        _ = options;
        try writer.print(
            \\{{"type":"{s}","region_id":"{s}","field":"{s}","old":"{s}","new":"{s}"}}
        , .{ self.type, self.region_id, self.field, self.old_value, self.new_value });
    }
};

pub const WorldState = struct {
    allocator: std.mem.Allocator,
    regions: std.StringHashMap(Region),
    mutex: std.Thread.Mutex,
    subscribers: [10]?std.net.Stream, // Simple fixed array for demo

    pub fn init(allocator: std.mem.Allocator) WorldState {
        var self = WorldState{
            .allocator = allocator,
            .regions = std.StringHashMap(Region).init(allocator),
            .mutex = .{},
            .subscribers = undefined,
        };
        for (&self.subscribers) |*sub| {
            sub.* = null;
        }
        return self;
    }

    pub fn deinit(self: *WorldState) void {
        var it = self.regions.iterator();
        while (it.next()) |entry| {
            self.allocator.free(entry.key_ptr.*);
            self.allocator.free(entry.value_ptr.owner_id);
        }
        self.regions.deinit();
    }

    pub fn subscribe(self: *WorldState, stream: std.net.Stream) !void {
        self.mutex.lock();
        defer self.mutex.unlock();
        for (&self.subscribers) |*sub| {
            if (sub.* == null) {
                sub.* = stream;
                return;
            }
        }
    }

    pub fn broadcast(self: *WorldState, delta: Delta) void {
        self.mutex.lock();
        defer self.mutex.unlock();

        for (&self.subscribers) |*sub| {
            if (sub.*) |stream| {
                var buf: [512]u8 = undefined;
                const data = std.fmt.bufPrint(&buf, "data: {any}\n\n", .{delta}) catch {
                    sub.* = null;
                    continue;
                };
                
                stream.writeAll(data) catch {
                    sub.* = null;
                    continue;
                };
            }
        }
    }

    pub fn serialize(self: *WorldState, stream: std.net.Stream) !void {
        self.mutex.lock();
        defer self.mutex.unlock();

        try stream.writeAll("{\"regions\":[");
        var it = self.regions.iterator();
        var first = true;
        while (it.next()) |entry| {
            if (!first) try stream.writeAll(",");
            var buf: [512]u8 = undefined;
            const region_json = try std.fmt.bufPrint(&buf, "{any}", .{entry.value_ptr.*});
            try stream.writeAll(region_json);
            first = false;
        }
        try stream.writeAll("]}");
    }

    pub fn seed(self: *WorldState) !void {
        self.mutex.lock();
        defer self.mutex.unlock();

        try self.addRegion("versailles", "yani_meziani", 10, 1000, 0.0);
        try self.addRegion("region_1", "player_1", 1, 100, 0.0);
        try self.addRegion("region_2", "player_2", 1, 150, 0.5);
        try self.addRegion("region_3", "none", 0, 500, 1.0);
    }

    fn addRegion(self: *WorldState, id: []const u8, owner: []const u8, level: u32, res: u32, fog: f32) !void {
        const id_dup = try self.allocator.dupe(u8, id);
        const owner_dup = try self.allocator.dupe(u8, owner);
        try self.regions.put(id_dup, .{
            .id = id_dup,
            .owner_id = owner_dup,
            .level = level,
            .resources = res,
            .fog_level = fog,
            .last_updated = std.time.timestamp(),
        });
    }

    pub fn updateOwner(self: *WorldState, region_id: []const u8, new_owner: []const u8) !?Delta {
        self.mutex.lock();
        defer self.mutex.unlock();

        if (self.regions.getPtr(region_id)) |region| {
            const old_owner = region.owner_id;
            const new_owner_dup = try self.allocator.dupe(u8, new_owner);
            
            const delta = Delta{
                .region_id = region_id,
                .field = "owner_id",
                .old_value = old_owner,
                .new_value = new_owner_dup,
            };

            region.owner_id = new_owner_dup;
            region.last_updated = std.time.timestamp();
            
            return delta;
        }
        return null;
    }

    pub fn nextDay(self: *WorldState) !void {
        self.mutex.lock();
        defer self.mutex.unlock();

        var it = self.regions.iterator();
        while (it.next()) |entry| {
            const region = entry.value_ptr;
            if (std.mem.eql(u8, region.owner_id, "none")) {
                region.fog_level = @min(1.0, region.fog_level + 0.1);
            }
            region.resources += 10 * region.level;
        }
    }
};
