//! Temporal decay — exponential time decay for retrieval candidates.
//!
//! Reduces the final_score of older memories so that recent information
//! is ranked higher.  Applied after hybrid merge but before MMR reranking.
//!
//! Formula:  score *= exp(-lambda * age_days)
//!   where   lambda = ln(2) / half_life_days
//!
//! At age == half_life_days the multiplier is exactly 0.5.
//! Evergreen entries (category == .core) are never decayed.

const std = @import("std");
const retrieval = @import("engine.zig");
const RetrievalCandidate = retrieval.RetrievalCandidate;
const MemoryCategory = @import("../root.zig").MemoryCategory;
const config_types = @import("../../config_types.zig");

pub const TemporalDecayConfig = config_types.MemoryTemporalDecayConfig;

// ── Pure helpers ──────────────────────────────────────────────────

/// Compute the decay constant lambda from a half-life in days.
/// Returns 0 when half_life_days is 0 (i.e. decay is effectively disabled).
pub fn decayLambda(half_life_days: u32) f64 {
    if (half_life_days == 0) return 0;
    return @log(2.0) / @as(f64, @floatFromInt(half_life_days));
}

/// Compute the decay multiplier for a given age.
/// Negative ages are clamped to 0 (no decay for future timestamps).
pub fn decayMultiplier(age_in_days: f64, half_life_days: u32) f64 {
    if (half_life_days == 0) return 1.0;
    const lambda = decayLambda(half_life_days);
    return @exp(-lambda * @max(0.0, age_in_days));
}

/// Apply decay to a single score value.
pub fn applyDecay(score: f64, age_in_days: f64, half_life_days: u32) f64 {
    return score * decayMultiplier(age_in_days, half_life_days);
}

/// Check whether a path refers to an evergreen memory file.
pub fn isEvergreen(path: []const u8) bool {
    return std.mem.endsWith(u8, path, "MEMORY.md") or
        std.mem.endsWith(u8, path, "memory.md");
}

// ── Pipeline stage ───────────────────────────────────────────────

const secs_per_day: f64 = 86400.0;

/// Apply temporal decay to candidate scores in-place.
/// Evergreen candidates (category == .core) are not decayed.
/// Candidates with created_at == 0 (unknown timestamp) are not decayed.
pub fn applyTemporalDecay(
    candidates: []RetrievalCandidate,
    config: TemporalDecayConfig,
    now_timestamp: i64,
) void {
    if (!config.enabled or candidates.len == 0) return;
    if (config.half_life_days == 0) return;

    const lambda = decayLambda(config.half_life_days);

    for (candidates) |*c| {
        // Skip evergreen (core) entries
        if (c.category == .core) continue;

        // Skip entries with no known timestamp
        if (c.created_at == 0) continue;

        // Use wrapping subtraction to avoid overflow panic when timestamps
        // are at extreme i64 values, then clamp negative ages to 0.
        const age_secs_raw = now_timestamp -% c.created_at;
        const age_secs: f64 = if (age_secs_raw < 0) 0.0 else @floatFromInt(age_secs_raw);
        const age_days = age_secs / secs_per_day;
        const decay = @exp(-lambda * age_days);
        c.final_score *= decay;
    }
}

// ── Tests ────────────────────────────────────────────────────────

test "decay_lambda_30_days" {
    const lambda = decayLambda(30);
    try std.testing.expectApproxEqAbs(@as(f64, 0.0231049), lambda, 1e-5);
}

test "decay_lambda_zero_half_life" {
    const lambda = decayLambda(0);
    try std.testing.expectEqual(@as(f64, 0.0), lambda);
}

test "decay_multiplier_at_half_life" {
    const m = decayMultiplier(30.0, 30);
    try std.testing.expectApproxEqAbs(@as(f64, 0.5), m, 1e-10);
}

test "decay_multiplier_at_zero_age" {
    const m = decayMultiplier(0.0, 30);
    try std.testing.expectApproxEqAbs(@as(f64, 1.0), m, 1e-10);
}

test "decay_multiplier_at_double_half_life" {
    const m = decayMultiplier(60.0, 30);
    try std.testing.expectApproxEqAbs(@as(f64, 0.25), m, 1e-10);
}

test "apply_decay_to_score" {
    const decayed = applyDecay(0.8, 30.0, 30);
    try std.testing.expectApproxEqAbs(@as(f64, 0.4), decayed, 1e-10);
}

test "negative_age_clamped_to_zero" {
    const m = decayMultiplier(-10.0, 30);
    try std.testing.expectApproxEqAbs(@as(f64, 1.0), m, 1e-10);
}

test "zero_half_life_returns_one" {
    const m = decayMultiplier(100.0, 0);
    try std.testing.expectApproxEqAbs(@as(f64, 1.0), m, 1e-10);
}

test "is_evergreen_memory_md" {
    try std.testing.expect(isEvergreen("path/to/MEMORY.md"));
    try std.testing.expect(isEvergreen("memory.md"));
}

test "is_evergreen_daily_file" {
    try std.testing.expect(!isEvergreen("memory/2024-01-15.md"));
    try std.testing.expect(!isEvergreen("notes.txt"));
}

fn makeCandidate(category: MemoryCategory, score: f64, created_at: i64) RetrievalCandidate {
    return .{
        .id = "test",
        .key = "test",
        .content = "test",
        .snippet = "test",
        .category = category,
        .keyword_rank = null,
        .vector_score = null,
        .final_score = score,
        .source = "test",
        .source_path = "",
        .start_line = 0,
        .end_line = 0,
        .created_at = created_at,
    };
}

test "applyTemporalDecay fresh entry unchanged" {
    var candidates = [_]RetrievalCandidate{
        makeCandidate(.daily, 1.0, 1000000),
    };
    // now == created_at → 0 days old
    applyTemporalDecay(&candidates, .{ .enabled = true, .half_life_days = 30 }, 1000000);
    try std.testing.expectApproxEqAbs(@as(f64, 1.0), candidates[0].final_score, 1e-10);
}

test "applyTemporalDecay at half_life halves score" {
    const half_life: u32 = 30;
    const created = 1000000;
    const now = created + 30 * 86400; // exactly 30 days later
    var candidates = [_]RetrievalCandidate{
        makeCandidate(.daily, 1.0, created),
    };
    applyTemporalDecay(&candidates, .{ .enabled = true, .half_life_days = half_life }, now);
    try std.testing.expectApproxEqAbs(@as(f64, 0.5), candidates[0].final_score, 1e-10);
}

test "applyTemporalDecay very old entry near zero" {
    const created = 1000000;
    const now = created + 365 * 86400; // 365 days later
    var candidates = [_]RetrievalCandidate{
        makeCandidate(.daily, 1.0, created),
    };
    applyTemporalDecay(&candidates, .{ .enabled = true, .half_life_days = 30 }, now);
    try std.testing.expect(candidates[0].final_score < 0.001);
}

test "applyTemporalDecay core category never decayed" {
    const created = 1000000;
    const now = created + 365 * 86400;
    var candidates = [_]RetrievalCandidate{
        makeCandidate(.core, 1.0, created),
    };
    applyTemporalDecay(&candidates, .{ .enabled = true, .half_life_days = 30 }, now);
    try std.testing.expectApproxEqAbs(@as(f64, 1.0), candidates[0].final_score, 1e-10);
}

test "applyTemporalDecay disabled config no changes" {
    const created = 1000000;
    const now = created + 365 * 86400;
    var candidates = [_]RetrievalCandidate{
        makeCandidate(.daily, 1.0, created),
    };
    applyTemporalDecay(&candidates, .{ .enabled = false, .half_life_days = 30 }, now);
    try std.testing.expectApproxEqAbs(@as(f64, 1.0), candidates[0].final_score, 1e-10);
}

test "applyTemporalDecay empty candidates no-op" {
    var candidates = [_]RetrievalCandidate{};
    applyTemporalDecay(&candidates, .{ .enabled = true, .half_life_days = 30 }, 1000000);
}

test "applyTemporalDecay negative age no decay" {
    // created_at is in the future relative to now
    var candidates = [_]RetrievalCandidate{
        makeCandidate(.daily, 1.0, 2000000),
    };
    applyTemporalDecay(&candidates, .{ .enabled = true, .half_life_days = 30 }, 1000000);
    try std.testing.expectApproxEqAbs(@as(f64, 1.0), candidates[0].final_score, 1e-10);
}

test "applyTemporalDecay half_life zero gracefully handled" {
    const created = 1000000;
    const now = created + 30 * 86400;
    var candidates = [_]RetrievalCandidate{
        makeCandidate(.daily, 1.0, created),
    };
    applyTemporalDecay(&candidates, .{ .enabled = true, .half_life_days = 0 }, now);
    // half_life=0 means no decay
    try std.testing.expectApproxEqAbs(@as(f64, 1.0), candidates[0].final_score, 1e-10);
}

test "applyTemporalDecay multiple candidates each decayed independently" {
    const now: i64 = 1000000 + 30 * 86400;
    var candidates = [_]RetrievalCandidate{
        makeCandidate(.daily, 1.0, 1000000), // 30 days old → 0.5
        makeCandidate(.daily, 0.8, 1000000 + 15 * 86400), // 15 days old → ≈0.707
        makeCandidate(.core, 0.6, 1000000), // core → unchanged
    };
    applyTemporalDecay(&candidates, .{ .enabled = true, .half_life_days = 30 }, now);

    try std.testing.expectApproxEqAbs(@as(f64, 0.5), candidates[0].final_score, 1e-10);
    // 15 days: multiplier = e^(-ln2/30 * 15) = 2^(-0.5) ≈ 0.7071
    try std.testing.expectApproxEqAbs(@as(f64, 0.8 * 0.70710678118), candidates[1].final_score, 1e-5);
    try std.testing.expectApproxEqAbs(@as(f64, 0.6), candidates[2].final_score, 1e-10);
}

test "applyTemporalDecay skips entries with unknown timestamp" {
    var candidates = [_]RetrievalCandidate{
        makeCandidate(.daily, 1.0, 0), // created_at=0 → unknown
    };
    applyTemporalDecay(&candidates, .{ .enabled = true, .half_life_days = 30 }, 1000000);
    try std.testing.expectApproxEqAbs(@as(f64, 1.0), candidates[0].final_score, 1e-10);
}

test "applyTemporalDecay conversation category is decayed" {
    const created = 1000000;
    const now = created + 30 * 86400;
    var candidates = [_]RetrievalCandidate{
        makeCandidate(.conversation, 1.0, created),
    };
    applyTemporalDecay(&candidates, .{ .enabled = true, .half_life_days = 30 }, now);
    try std.testing.expectApproxEqAbs(@as(f64, 0.5), candidates[0].final_score, 1e-10);
}
