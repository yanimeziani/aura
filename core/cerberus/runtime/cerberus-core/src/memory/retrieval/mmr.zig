//! MMR (Maximal Marginal Relevance) diversity reranking.
//!
//! Iteratively selects candidates that balance relevance to the query
//! with diversity from already-selected results.  Applied after temporal
//! decay and before final truncation.
//!
//! Formula:  MMR(d) = lambda * Rel(d) - (1 - lambda) * max_sim(d, S)
//!   where   Rel(d)      = normalized final_score
//!           max_sim(d,S) = max Jaccard similarity to any selected candidate
//!           lambda       = config parameter (0.7 default)

const std = @import("std");
const Allocator = std.mem.Allocator;
const retrieval = @import("engine.zig");
const RetrievalCandidate = retrieval.RetrievalCandidate;
const config_types = @import("../../config_types.zig");

pub const MmrConfig = config_types.MemoryMmrConfig;

// ── Jaccard similarity ──────────────────────────────────────────

/// Tokenize text by splitting on whitespace and lowercasing.
/// Returns a set of unique lowercase tokens.  Caller must call
/// `deinitTokenSet` when done.
fn tokenize(allocator: Allocator, text: []const u8) !std.StringHashMap(void) {
    var set = std.StringHashMap(void).init(allocator);
    errdefer {
        var it = set.keyIterator();
        while (it.next()) |k| allocator.free(k.*);
        set.deinit();
    }

    var start: usize = 0;
    var i: usize = 0;
    while (i < text.len) : (i += 1) {
        if (text[i] == ' ' or text[i] == '\t' or text[i] == '\n' or text[i] == '\r') {
            if (i > start) {
                try insertToken(allocator, &set, text[start..i]);
            }
            start = i + 1;
        }
    }
    // Trailing token
    if (start < text.len) {
        try insertToken(allocator, &set, text[start..]);
    }

    return set;
}

fn insertToken(allocator: Allocator, set: *std.StringHashMap(void), raw: []const u8) !void {
    // Lowercase the token
    const lower = try allocator.alloc(u8, raw.len);
    for (raw, 0..) |ch, j| {
        lower[j] = std.ascii.toLower(ch);
    }

    const gop = try set.getOrPut(lower);
    if (gop.found_existing) {
        // Already present — free the duplicate
        allocator.free(lower);
    }
}

fn deinitTokenSet(allocator: Allocator, set: *std.StringHashMap(void)) void {
    var it = set.keyIterator();
    while (it.next()) |k| allocator.free(k.*);
    set.deinit();
}

/// Jaccard similarity between two text strings.
/// Tokenizes by whitespace, lowercases, computes |intersection|/|union|.
/// Both-empty → 0.0 (nothing in common).
pub fn jaccardSimilarity(allocator: Allocator, text_a: []const u8, text_b: []const u8) !f64 {
    var set_a = try tokenize(allocator, text_a);
    defer deinitTokenSet(allocator, &set_a);
    var set_b = try tokenize(allocator, text_b);
    defer deinitTokenSet(allocator, &set_b);

    return jaccardFromSets(&set_a, &set_b);
}

fn jaccardFromSets(set_a: *const std.StringHashMap(void), set_b: *const std.StringHashMap(void)) f64 {
    const count_a = set_a.count();
    const count_b = set_b.count();

    if (count_a == 0 and count_b == 0) return 0.0;
    if (count_a == 0 or count_b == 0) return 0.0;

    // Count intersection: keys in A that also exist in B
    var intersection: usize = 0;
    var it = set_a.keyIterator();
    while (it.next()) |k| {
        if (set_b.contains(k.*)) intersection += 1;
    }

    const union_size = count_a + count_b - intersection;
    if (union_size == 0) return 0.0;

    return @as(f64, @floatFromInt(intersection)) / @as(f64, @floatFromInt(union_size));
}

// ── MMR reranking ────────────────────────────────────────────────

/// Apply MMR reranking to candidates.
/// Returns a new slice with candidates reordered by MMR selection.
/// Caller owns the returned slice (all strings are duped).
pub fn applyMmr(
    allocator: Allocator,
    candidates: []const RetrievalCandidate,
    config: MmrConfig,
    limit: usize,
) ![]RetrievalCandidate {
    if (!config.enabled or candidates.len <= 1) {
        return try copySlice(allocator, candidates, limit);
    }

    const n = candidates.len;
    const result_len = @min(n, limit);

    // Pre-tokenize all candidates
    var token_sets = try allocator.alloc(std.StringHashMap(void), n);
    var tokenized_count: usize = 0;
    defer {
        for (token_sets[0..tokenized_count]) |*ts| deinitTokenSet(allocator, ts);
        allocator.free(token_sets);
    }
    for (candidates, 0..) |c, i| {
        token_sets[i] = try tokenize(allocator, c.content);
        tokenized_count = i + 1;
    }

    // Normalize scores to [0,1]
    var min_score: f64 = candidates[0].final_score;
    var max_score: f64 = candidates[0].final_score;
    for (candidates[1..]) |c| {
        if (c.final_score < min_score) min_score = c.final_score;
        if (c.final_score > max_score) max_score = c.final_score;
    }
    const score_range = max_score - min_score;

    var normalized = try allocator.alloc(f64, n);
    defer allocator.free(normalized);
    for (candidates, 0..) |c, i| {
        normalized[i] = if (score_range > 0.0)
            (c.final_score - min_score) / score_range
        else
            1.0; // All equal scores → all get 1.0
    }

    // Track which candidates are selected / remaining
    var selected_indices = try allocator.alloc(usize, result_len);
    defer allocator.free(selected_indices);
    var is_selected = try allocator.alloc(bool, n);
    defer allocator.free(is_selected);
    @memset(is_selected, false);

    // Step 1: Select the candidate with highest final_score
    var best_idx: usize = 0;
    for (candidates, 0..) |c, i| {
        if (c.final_score > candidates[best_idx].final_score) {
            best_idx = i;
        }
    }
    selected_indices[0] = best_idx;
    is_selected[best_idx] = true;
    var selected_count: usize = 1;

    // Steps 2-4: Iterative MMR selection
    while (selected_count < result_len) {
        var best_mmr: f64 = -std.math.inf(f64);
        // Initialize to first unselected candidate to avoid re-selecting index 0
        var best_mmr_idx: usize = for (0..n) |i| {
            if (!is_selected[i]) break i;
        } else break; // all selected (shouldn't happen)

        for (0..n) |i| {
            if (is_selected[i]) continue;

            // Compute max similarity to any already-selected candidate
            var max_sim: f64 = 0.0;
            for (selected_indices[0..selected_count]) |si| {
                const sim = jaccardFromSets(&token_sets[i], &token_sets[si]);
                if (sim > max_sim) max_sim = sim;
            }

            const mmr_score = config.lambda * normalized[i] - (1.0 - config.lambda) * max_sim;

            if (mmr_score > best_mmr or (mmr_score == best_mmr and candidates[i].final_score > candidates[best_mmr_idx].final_score)) {
                best_mmr = mmr_score;
                best_mmr_idx = i;
            }
        }

        selected_indices[selected_count] = best_mmr_idx;
        is_selected[best_mmr_idx] = true;
        selected_count += 1;
    }

    // Build result with duped strings
    var result = try allocator.alloc(RetrievalCandidate, result_len);
    var duped: usize = 0;
    errdefer {
        for (result[0..duped]) |*c| c.deinit(allocator);
        allocator.free(result);
    }
    for (selected_indices[0..result_len]) |si| {
        result[duped] = try dupeCandidate(allocator, candidates[si]);
        duped += 1;
    }

    return result;
}

/// Copy up to `limit` candidates with duped strings.
fn copySlice(
    allocator: Allocator,
    candidates: []const RetrievalCandidate,
    limit: usize,
) ![]RetrievalCandidate {
    const out_len = @min(candidates.len, limit);
    var result = try allocator.alloc(RetrievalCandidate, out_len);
    var duped: usize = 0;
    errdefer {
        for (result[0..duped]) |*c| c.deinit(allocator);
        allocator.free(result);
    }
    for (candidates[0..out_len]) |c| {
        result[duped] = try dupeCandidate(allocator, c);
        duped += 1;
    }
    return result;
}

/// Deep-copy a single RetrievalCandidate (all string fields duped).
fn dupeCandidate(allocator: Allocator, c: RetrievalCandidate) !RetrievalCandidate {
    const id = try allocator.dupe(u8, c.id);
    errdefer allocator.free(id);
    const key = try allocator.dupe(u8, c.key);
    errdefer allocator.free(key);
    const content = try allocator.dupe(u8, c.content);
    errdefer allocator.free(content);
    const snippet = try allocator.dupe(u8, c.snippet);
    errdefer allocator.free(snippet);
    const source = try allocator.dupe(u8, c.source);
    errdefer allocator.free(source);
    const source_path = try allocator.dupe(u8, c.source_path);
    errdefer allocator.free(source_path);

    const cat: @import("../root.zig").MemoryCategory = switch (c.category) {
        .custom => |name| .{ .custom = try allocator.dupe(u8, name) },
        else => c.category,
    };

    return .{
        .id = id,
        .key = key,
        .content = content,
        .snippet = snippet,
        .category = cat,
        .keyword_rank = c.keyword_rank,
        .vector_score = c.vector_score,
        .final_score = c.final_score,
        .source = source,
        .source_path = source_path,
        .start_line = c.start_line,
        .end_line = c.end_line,
        .created_at = c.created_at,
    };
}

// ── Tests ────────────────────────────────────────────────────────

const MemoryCategory = @import("../root.zig").MemoryCategory;

fn makeCandidate(comptime id_key: []const u8, comptime content: []const u8, score: f64) RetrievalCandidate {
    return .{
        .id = id_key,
        .key = id_key,
        .content = content,
        .snippet = content,
        .category = .core,
        .keyword_rank = null,
        .vector_score = null,
        .final_score = score,
        .source = "test",
        .source_path = "",
        .start_line = 0,
        .end_line = 0,
        .created_at = 0,
    };
}

test "mmr: single candidate returned as-is" {
    const allocator = std.testing.allocator;
    const candidates = [_]RetrievalCandidate{
        makeCandidate("a", "hello world", 1.0),
    };
    const result = try applyMmr(allocator, &candidates, .{ .enabled = true, .lambda = 0.7 }, 10);
    defer retrieval.freeCandidates(allocator, result);
    try std.testing.expectEqual(@as(usize, 1), result.len);
    try std.testing.expectEqualStrings("a", result[0].id);
}

test "mmr: two identical candidates — duplicate penalized" {
    const allocator = std.testing.allocator;
    const candidates = [_]RetrievalCandidate{
        makeCandidate("a", "the quick brown fox", 0.9),
        makeCandidate("b", "the quick brown fox", 0.8),
    };
    const result = try applyMmr(allocator, &candidates, .{ .enabled = true, .lambda = 0.5 }, 10);
    defer retrieval.freeCandidates(allocator, result);
    try std.testing.expectEqual(@as(usize, 2), result.len);
    // First selected = highest score
    try std.testing.expectEqualStrings("a", result[0].id);
    // Second is b (only remaining), but its MMR score would be penalized
    try std.testing.expectEqualStrings("b", result[1].id);
}

test "mmr: two completely different candidates — both selected at high scores" {
    const allocator = std.testing.allocator;
    const candidates = [_]RetrievalCandidate{
        makeCandidate("a", "alpha beta gamma", 0.9),
        makeCandidate("b", "one two three", 0.8),
    };
    const result = try applyMmr(allocator, &candidates, .{ .enabled = true, .lambda = 0.5 }, 10);
    defer retrieval.freeCandidates(allocator, result);
    try std.testing.expectEqual(@as(usize, 2), result.len);
    try std.testing.expectEqualStrings("a", result[0].id);
    try std.testing.expectEqualStrings("b", result[1].id);
}

test "mmr: lambda=1.0 pure relevance order" {
    const allocator = std.testing.allocator;
    const candidates = [_]RetrievalCandidate{
        makeCandidate("a", "same content here", 0.9),
        makeCandidate("b", "same content here", 0.7),
        makeCandidate("c", "same content here", 0.8),
    };
    const result = try applyMmr(allocator, &candidates, .{ .enabled = true, .lambda = 1.0 }, 10);
    defer retrieval.freeCandidates(allocator, result);
    try std.testing.expectEqual(@as(usize, 3), result.len);
    // Pure relevance: 0.9 > 0.8 > 0.7
    try std.testing.expectEqualStrings("a", result[0].id);
    try std.testing.expectEqualStrings("c", result[1].id);
    try std.testing.expectEqualStrings("b", result[2].id);
}

test "mmr: lambda=0.0 maximum diversity" {
    const allocator = std.testing.allocator;
    // A and B have identical content, C is different
    const candidates = [_]RetrievalCandidate{
        makeCandidate("a", "zig memory retrieval", 0.9),
        makeCandidate("b", "zig memory retrieval", 0.85),
        makeCandidate("c", "completely different topic", 0.5),
    };
    const result = try applyMmr(allocator, &candidates, .{ .enabled = true, .lambda = 0.0 }, 10);
    defer retrieval.freeCandidates(allocator, result);
    try std.testing.expectEqual(@as(usize, 3), result.len);
    // First = highest score (a)
    try std.testing.expectEqualStrings("a", result[0].id);
    // Second should prefer C (different) over B (identical to A)
    try std.testing.expectEqualStrings("c", result[1].id);
}

test "mmr: empty candidates returns empty" {
    const allocator = std.testing.allocator;
    const candidates = [_]RetrievalCandidate{};
    const result = try applyMmr(allocator, &candidates, .{ .enabled = true, .lambda = 0.7 }, 10);
    defer allocator.free(result);
    try std.testing.expectEqual(@as(usize, 0), result.len);
}

test "mmr: disabled config preserves original order" {
    const allocator = std.testing.allocator;
    const candidates = [_]RetrievalCandidate{
        makeCandidate("a", "hello", 0.5),
        makeCandidate("b", "world", 0.9),
    };
    const result = try applyMmr(allocator, &candidates, .{ .enabled = false, .lambda = 0.7 }, 10);
    defer retrieval.freeCandidates(allocator, result);
    try std.testing.expectEqual(@as(usize, 2), result.len);
    // Original order preserved (not reranked by score)
    try std.testing.expectEqualStrings("a", result[0].id);
    try std.testing.expectEqualStrings("b", result[1].id);
}

test "jaccard: identical texts returns 1.0" {
    const allocator = std.testing.allocator;
    const sim = try jaccardSimilarity(allocator, "hello world foo", "hello world foo");
    try std.testing.expectApproxEqAbs(@as(f64, 1.0), sim, 1e-10);
}

test "jaccard: completely different texts returns 0.0" {
    const allocator = std.testing.allocator;
    const sim = try jaccardSimilarity(allocator, "alpha beta gamma", "one two three");
    try std.testing.expectApproxEqAbs(@as(f64, 0.0), sim, 1e-10);
}

test "jaccard: partial overlap" {
    const allocator = std.testing.allocator;
    // tokens A: {hello, world, foo} — 3 tokens
    // tokens B: {hello, world, bar} — 3 tokens
    // intersection = 2, union = 4 → 0.5
    const sim = try jaccardSimilarity(allocator, "hello world foo", "hello world bar");
    try std.testing.expectApproxEqAbs(@as(f64, 0.5), sim, 1e-10);
}

test "jaccard: empty text returns 0.0" {
    const allocator = std.testing.allocator;
    const sim1 = try jaccardSimilarity(allocator, "", "hello");
    try std.testing.expectApproxEqAbs(@as(f64, 0.0), sim1, 1e-10);
    const sim2 = try jaccardSimilarity(allocator, "", "");
    try std.testing.expectApproxEqAbs(@as(f64, 0.0), sim2, 1e-10);
}

test "jaccard: case insensitive" {
    const allocator = std.testing.allocator;
    const sim = try jaccardSimilarity(allocator, "Hello World", "hello world");
    try std.testing.expectApproxEqAbs(@as(f64, 1.0), sim, 1e-10);
}

test "mmr: limit less than candidates returns limited count" {
    const allocator = std.testing.allocator;
    const candidates = [_]RetrievalCandidate{
        makeCandidate("a", "alpha", 0.9),
        makeCandidate("b", "beta", 0.8),
        makeCandidate("c", "gamma", 0.7),
    };
    const result = try applyMmr(allocator, &candidates, .{ .enabled = true, .lambda = 0.7 }, 2);
    defer retrieval.freeCandidates(allocator, result);
    try std.testing.expectEqual(@as(usize, 2), result.len);
}

test "mmr: preserves candidate data" {
    const allocator = std.testing.allocator;
    const candidates = [_]RetrievalCandidate{
        .{
            .id = "id1",
            .key = "key1",
            .content = "test content",
            .snippet = "snippet1",
            .category = .daily,
            .keyword_rank = 3,
            .vector_score = 0.95,
            .final_score = 0.88,
            .source = "vector",
            .source_path = "/some/path",
            .start_line = 10,
            .end_line = 20,
            .created_at = 1700000000,
        },
    };
    const result = try applyMmr(allocator, &candidates, .{ .enabled = true, .lambda = 0.7 }, 10);
    defer retrieval.freeCandidates(allocator, result);

    try std.testing.expectEqual(@as(usize, 1), result.len);
    try std.testing.expectEqualStrings("id1", result[0].id);
    try std.testing.expectEqualStrings("key1", result[0].key);
    try std.testing.expectEqualStrings("test content", result[0].content);
    try std.testing.expectEqualStrings("snippet1", result[0].snippet);
    try std.testing.expectEqual(MemoryCategory.daily, result[0].category);
    try std.testing.expectEqual(@as(u32, 3), result[0].keyword_rank.?);
    try std.testing.expect(@abs(result[0].vector_score.? - 0.95) < 0.001);
    try std.testing.expectApproxEqAbs(@as(f64, 0.88), result[0].final_score, 1e-10);
    try std.testing.expectEqualStrings("vector", result[0].source);
    try std.testing.expectEqualStrings("/some/path", result[0].source_path);
    try std.testing.expectEqual(@as(u32, 10), result[0].start_line);
    try std.testing.expectEqual(@as(u32, 20), result[0].end_line);
    try std.testing.expectEqual(@as(i64, 1700000000), result[0].created_at);
}

test "mmr: diversity — A relevant, B=copy of A, C different selects A then C" {
    const allocator = std.testing.allocator;
    const candidates = [_]RetrievalCandidate{
        makeCandidate("a", "zig programming language systems", 0.9),
        makeCandidate("b", "zig programming language systems", 0.85),
        makeCandidate("c", "machine learning neural networks", 0.6),
    };
    // lambda=0.3 → heavy diversity preference
    const result = try applyMmr(allocator, &candidates, .{ .enabled = true, .lambda = 0.3 }, 3);
    defer retrieval.freeCandidates(allocator, result);
    try std.testing.expectEqual(@as(usize, 3), result.len);
    // First = highest relevance
    try std.testing.expectEqualStrings("a", result[0].id);
    // Second = C (diverse from A) rather than B (identical to A)
    try std.testing.expectEqualStrings("c", result[1].id);
    // Third = B (only remaining)
    try std.testing.expectEqualStrings("b", result[2].id);
}
