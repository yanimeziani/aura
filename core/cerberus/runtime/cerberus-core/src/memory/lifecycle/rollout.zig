//! Rollout modes — safe hybrid adoption state machine.
//!
//! Controls how the memory system transitions from keyword-only to hybrid
//! (keyword + vector) retrieval. Supports shadow mode (run both, serve keyword)
//! and canary mode (hash-based gradual rollout per session).

const std = @import("std");
const config_types = @import("../../config_types.zig");
const log = std.log.scoped(.rollout);

pub const RolloutMode = enum {
    off,
    shadow,
    canary,
    on,

    pub fn fromString(s: []const u8) RolloutMode {
        if (std.mem.eql(u8, s, "off")) return .off;
        if (std.mem.eql(u8, s, "shadow")) return .shadow;
        if (std.mem.eql(u8, s, "canary")) return .canary;
        if (std.mem.eql(u8, s, "on")) return .on;
        return .off; // unknown → safe default
    }
};

pub const RolloutDecision = enum {
    keyword_only,
    hybrid,
    shadow_hybrid,
};

pub const RolloutPolicy = struct {
    mode: RolloutMode,
    canary_percent: u32,
    shadow_percent: u32,

    pub fn init(reliability_cfg: config_types.MemoryReliabilityConfig) RolloutPolicy {
        return .{
            .mode = RolloutMode.fromString(reliability_cfg.rollout_mode),
            .canary_percent = @min(reliability_cfg.canary_hybrid_percent, 100),
            .shadow_percent = @min(reliability_cfg.shadow_hybrid_percent, 100),
        };
    }

    pub fn decide(self: RolloutPolicy, session_id: ?[]const u8) RolloutDecision {
        const decision: RolloutDecision = switch (self.mode) {
            .off => .keyword_only,
            .shadow => .shadow_hybrid,
            .on => .hybrid,
            .canary => blk: {
                const sid = session_id orelse break :blk .keyword_only;
                if (sid.len == 0) break :blk .keyword_only;
                const hash = std.hash.Fnv1a_32.hash(sid);
                if (hash % 100 < self.canary_percent) break :blk .hybrid;
                break :blk .keyword_only;
            },
        };
        log.debug("rollout decide: mode={s} decision={s} session={s}", .{
            @tagName(self.mode),
            @tagName(decision),
            session_id orelse "<none>",
        });
        return decision;
    }
};

// ── Tests ──────────────────────────────────────────────────────────

test "fromString: off" {
    try std.testing.expect(RolloutMode.fromString("off") == .off);
}

test "fromString: shadow" {
    try std.testing.expect(RolloutMode.fromString("shadow") == .shadow);
}

test "fromString: canary" {
    try std.testing.expect(RolloutMode.fromString("canary") == .canary);
}

test "fromString: on" {
    try std.testing.expect(RolloutMode.fromString("on") == .on);
}

test "fromString: unknown defaults to off" {
    try std.testing.expect(RolloutMode.fromString("bogus") == .off);
    try std.testing.expect(RolloutMode.fromString("") == .off);
}

test "off mode always returns keyword_only" {
    const policy = RolloutPolicy{ .mode = .off, .canary_percent = 100, .shadow_percent = 100 };
    try std.testing.expect(policy.decide("session1") == .keyword_only);
    try std.testing.expect(policy.decide(null) == .keyword_only);
}

test "on mode always returns hybrid" {
    const policy = RolloutPolicy{ .mode = .on, .canary_percent = 0, .shadow_percent = 0 };
    try std.testing.expect(policy.decide("session1") == .hybrid);
    try std.testing.expect(policy.decide(null) == .hybrid);
}

test "shadow mode always returns shadow_hybrid" {
    const policy = RolloutPolicy{ .mode = .shadow, .canary_percent = 0, .shadow_percent = 0 };
    try std.testing.expect(policy.decide("session1") == .shadow_hybrid);
    try std.testing.expect(policy.decide(null) == .shadow_hybrid);
}

test "canary mode with 0% always returns keyword_only" {
    const policy = RolloutPolicy{ .mode = .canary, .canary_percent = 0, .shadow_percent = 0 };
    try std.testing.expect(policy.decide("session1") == .keyword_only);
    try std.testing.expect(policy.decide("session2") == .keyword_only);
    try std.testing.expect(policy.decide("session3") == .keyword_only);
}

test "canary mode with 100% always returns hybrid" {
    const policy = RolloutPolicy{ .mode = .canary, .canary_percent = 100, .shadow_percent = 0 };
    try std.testing.expect(policy.decide("session1") == .hybrid);
    try std.testing.expect(policy.decide("session2") == .hybrid);
    try std.testing.expect(policy.decide("session3") == .hybrid);
}

test "canary mode: same session_id always gets same result" {
    const policy = RolloutPolicy{ .mode = .canary, .canary_percent = 50, .shadow_percent = 0 };
    const d1 = policy.decide("test-session-abc");
    const d2 = policy.decide("test-session-abc");
    const d3 = policy.decide("test-session-abc");
    try std.testing.expect(d1 == d2);
    try std.testing.expect(d2 == d3);
}

test "canary mode: null session_id returns keyword_only" {
    const policy = RolloutPolicy{ .mode = .canary, .canary_percent = 50, .shadow_percent = 0 };
    try std.testing.expect(policy.decide(null) == .keyword_only);
}

test "canary mode: empty session_id returns keyword_only" {
    const policy = RolloutPolicy{ .mode = .canary, .canary_percent = 50, .shadow_percent = 0 };
    try std.testing.expect(policy.decide("") == .keyword_only);
}

test "canary mode with 50%: distribution is roughly balanced" {
    const policy = RolloutPolicy{ .mode = .canary, .canary_percent = 50, .shadow_percent = 0 };
    var hybrid_count: u32 = 0;
    const total: u32 = 1000;
    var buf: [32]u8 = undefined;

    for (0..total) |i| {
        const session_id = std.fmt.bufPrint(&buf, "session-{d}", .{i}) catch continue;
        if (policy.decide(session_id) == .hybrid) {
            hybrid_count += 1;
        }
    }

    // Expect roughly 50% ± 10% (400-600 out of 1000)
    try std.testing.expect(hybrid_count >= 350);
    try std.testing.expect(hybrid_count <= 650);
}

test "init from config defaults" {
    const cfg = config_types.MemoryReliabilityConfig{};
    const policy = RolloutPolicy.init(cfg);
    try std.testing.expect(policy.mode == .off);
    try std.testing.expectEqual(@as(u32, 0), policy.canary_percent);
    try std.testing.expectEqual(@as(u32, 0), policy.shadow_percent);
}

test "init from explicit config values" {
    const cfg = config_types.MemoryReliabilityConfig{
        .rollout_mode = "canary",
        .canary_hybrid_percent = 25,
        .shadow_hybrid_percent = 10,
    };
    const policy = RolloutPolicy.init(cfg);
    try std.testing.expect(policy.mode == .canary);
    try std.testing.expectEqual(@as(u32, 25), policy.canary_percent);
    try std.testing.expectEqual(@as(u32, 10), policy.shadow_percent);
}

test "init with on mode from config" {
    const cfg = config_types.MemoryReliabilityConfig{
        .rollout_mode = "on",
    };
    const policy = RolloutPolicy.init(cfg);
    try std.testing.expect(policy.mode == .on);
    try std.testing.expect(policy.decide("any-session") == .hybrid);
}

test "init with shadow mode from config" {
    const cfg = config_types.MemoryReliabilityConfig{
        .rollout_mode = "shadow",
        .shadow_hybrid_percent = 50,
    };
    const policy = RolloutPolicy.init(cfg);
    try std.testing.expect(policy.mode == .shadow);
    try std.testing.expect(policy.decide("any-session") == .shadow_hybrid);
}

test "decide is pure function (no side effects)" {
    var policy = RolloutPolicy{ .mode = .canary, .canary_percent = 50, .shadow_percent = 0 };
    const d1 = policy.decide("stable-session");
    policy.shadow_percent = 99; // mutate unrelated field
    const d2 = policy.decide("stable-session");
    try std.testing.expect(d1 == d2);
}

// ── R3 Tests ──────────────────────────────────────────────────────

test "R3: rollout boundary — 0% always keyword_only for canary" {
    const policy = RolloutPolicy{ .mode = .canary, .canary_percent = 0, .shadow_percent = 0 };
    var buf: [32]u8 = undefined;
    for (0..100) |i| {
        const sid = std.fmt.bufPrint(&buf, "session-{d}", .{i}) catch continue;
        try std.testing.expect(policy.decide(sid) == .keyword_only);
    }
}

test "R3: rollout boundary — 100% always hybrid for canary" {
    const policy = RolloutPolicy{ .mode = .canary, .canary_percent = 100, .shadow_percent = 0 };
    var buf: [32]u8 = undefined;
    for (0..100) |i| {
        const sid = std.fmt.bufPrint(&buf, "session-{d}", .{i}) catch continue;
        try std.testing.expect(policy.decide(sid) == .hybrid);
    }
}

test "R3: rollout init clamps >100 to 100" {
    const cfg = config_types.MemoryReliabilityConfig{
        .rollout_mode = "canary",
        .canary_hybrid_percent = 200,
        .shadow_hybrid_percent = 300,
    };
    const policy = RolloutPolicy.init(cfg);
    try std.testing.expectEqual(@as(u32, 100), policy.canary_percent);
    try std.testing.expectEqual(@as(u32, 100), policy.shadow_percent);
}

test "R3: rollout canary deterministic — same session_id across 100 calls" {
    const policy = RolloutPolicy{ .mode = .canary, .canary_percent = 50, .shadow_percent = 0 };
    const sid = "deterministic-session-id-xyz";
    const first = policy.decide(sid);
    for (0..100) |_| {
        try std.testing.expect(policy.decide(sid) == first);
    }
}
