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
            \\{{"id":"{s}","owner_id":"{s}","level":{d},"resources":{d},"fog_level":{d:.2},"last_updated":{d}}}
        , .{ self.id, self.owner_id, self.level, self.resources, self.fog_level, self.last_updated });
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

pub const Skill = struct {
    id: []const u8,
    name: []const u8,
    category: []const u8, // "Carpentry", "Coding", "Electronics", etc.
    difficulty: u8,
    steps_count: u32,

    pub fn format(self: Skill, comptime fmt: []const u8, options: std.fmt.FormatOptions, writer: anytype) !void {
        _ = fmt; _ = options;
        try writer.print(
            \\{{"id":"{s}","name":"{s}","category":"{s}","difficulty":{d},"steps":{d}}}
        , .{ self.id, self.name, self.category, self.difficulty, self.steps_count });
    }
};

pub const CognitiveShield = struct {
    is_active: bool,
    manipulation_threshold: f32, // Seuil de détection de manipulation
    protection_level: u8, // 0-100

    pub fn checkContent(self: CognitiveShield, content_impact: f32) bool {
        if (!self.is_active) return true;
        return content_impact < self.manipulation_threshold;
    }
};

pub const ContributionRole = enum {
    Apprentice,
    Journeyman,
    Master,
    Guardian, // Reserved for validated Elders (Gardiens du Savoir)
    Architect, // Reserved for Yani Meziani and designated leads
};

pub const Contributor = struct {
    id: []const u8,
    role: ContributionRole,
    verified_skills: u32, 
    reputation_score: f32, 
    cognitive_stability: f32, // Score d'intégrité mentale (0.0 - 1.0)

    pub fn canLead(self: Contributor) bool {
        // Le pouvoir exige une stabilité supérieure à 0.8
        const has_integrity = self.cognitive_stability > 0.8;
        return has_integrity and (self.role == .Master or self.role == .Guardian or self.role == .Architect);
    }

    pub fn format(self: Contributor, comptime fmt: []const u8, options: std.fmt.FormatOptions, writer: anytype) !void {
        _ = fmt; _ = options;
        try writer.print(
            \\{{"id":"{s}","role":"{s}","skills":{d},"reputation":{d:.2},"stability":{d:.2}}}
        , .{ self.id, @tagName(self.role), self.verified_skills, self.reputation_score, self.cognitive_stability });
    }
};

pub const LearningState = struct {
    student_id: []const u8,
    skill_id: []const u8,
    current_step: u32,
    is_hands_on_verified: bool,
    safety_rating: f32, 
    cognitive_load: f32,
    bio_stress_level: f32, // Surveiller l'impact physique (EMF/Fatigue)

    pub fn format(self: LearningState, comptime fmt: []const u8, options: std.fmt.FormatOptions, writer: anytype) !void {
        _ = fmt; _ = options;
        try writer.print(
            \\{{"student":"{s}","skill":"{s}","step":{d},"verified":{s},"safety":{d:.2},"mental_load":{d:.2},"bio_stress":{d:.2}}}
        , .{ self.student_id, self.skill_id, self.current_step, if (self.is_hands_on_verified) "true" else "false", self.safety_rating, self.cognitive_load, self.bio_stress_level });
    }
};

pub const WorldState = struct {
    allocator: std.mem.Allocator,
    regions: std.StringHashMap(Region),
    skills: std.StringHashMap(Skill),
    learning_progress: std.StringHashMap(LearningState),
    mutex: std.Thread.Mutex,
    subscribers: std.ArrayList(std.net.Stream),

    pub fn init(allocator: std.mem.Allocator) WorldState {
        return .{
            .allocator = allocator,
            .regions = std.StringHashMap(Region).init(allocator),
            .skills = std.StringHashMap(Skill).init(allocator),
            .learning_progress = std.StringHashMap(LearningState).init(allocator),
            .mutex = .{},
            .subscribers = std.ArrayList(std.net.Stream).init(allocator),
        };
    }

    pub fn deinit(self: *WorldState) void {
        var it = self.regions.iterator();
        while (it.next()) |entry| {
            self.allocator.free(entry.key_ptr.*);
            self.allocator.free(entry.value_ptr.owner_id);
        }
        self.regions.deinit();
        self.subscribers.deinit();
    }

    pub fn subscribe(self: *WorldState, stream: std.net.Stream) !void {
        self.mutex.lock();
        defer self.mutex.unlock();
        try self.subscribers.append(stream);
    }

    pub fn broadcast(self: *WorldState, delta: Delta) void {
        self.mutex.lock();
        defer self.mutex.unlock();

        var i: usize = 0;
        while (i < self.subscribers.items.len) {
            const stream = self.subscribers.items[i];
            var buf: [512]u8 = undefined;
            const data = std.fmt.bufPrint(&buf, "data: {any}\n\n", .{delta}) catch {
                _ = self.subscribers.swapRemove(i);
                continue;
            };
            
            stream.writeAll(data) catch {
                _ = self.subscribers.swapRemove(i);
                continue;
            };
            i += 1;
        }
    }

    pub fn serialize(self: *WorldState, writer: anytype) !void {
        self.mutex.lock();
        defer self.mutex.unlock();

        try writer.writeAll("{\"regions\":[");
        var it = self.regions.iterator();
        var first = true;
        while (it.next()) |entry| {
            if (!first) try writer.writeAll(",");
            try writer.print("{any}", .{entry.value_ptr.*});
            first = false;
        }
        try writer.writeAll("]}");
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
