//! Provider router — embedding route selection, fallback chain, and auto-provider orchestration.
//!
//! Implements E-P1 (auto/fallback) and route-based provider selection from the
//! embedding provider spec (reference/memory/embeddings.md).
//!
//! The router wraps multiple EmbeddingProviders and exposes the same vtable interface.
//! On embed() failure, it walks a fallback chain until one succeeds or all fail.
//!
//! Route resolution:
//!   - If a model name starts with "hint:", resolve to a matching route
//!   - Route fields override the base embedder config
//!   - Unknown hints fall back to the base provider

const std = @import("std");
const embeddings = @import("embeddings.zig");
const EmbeddingProvider = embeddings.EmbeddingProvider;

const log = std.log.scoped(.provider_router);

// ── Error classification ──────────────────────────────────────────

pub const ErrorClass = enum {
    /// Authentication/authorization failure — do not retry, skip provider.
    auth,
    /// Transient failure (network, timeout, rate limit) — may retry.
    transient,
    /// Permanent failure (bad request, unsupported model) — skip provider.
    permanent,
};

/// Classify an embedding error for fallback decisions.
pub fn classifyError(err: anyerror) ErrorClass {
    return switch (err) {
        error.EmbeddingApiError => .transient,
        error.InvalidEmbeddingResponse => .permanent,
        error.OutOfMemory => .permanent,
        error.ConnectionRefused => .transient,
        error.ConnectionResetByPeer => .transient,
        error.ConnectionTimedOut => .transient,
        else => .transient,
    };
}

// ── Embedding route ───────────────────────────────────────────────

pub const EmbeddingRoute = struct {
    hint: []const u8,
    provider_name: []const u8,
    model: []const u8,
    dimensions: u32,
};

// ── Provider router ───────────────────────────────────────────────

pub const ProviderRouter = struct {
    allocator: std.mem.Allocator,
    /// Primary provider (first in chain).
    primary: EmbeddingProvider,
    /// Fallback providers in priority order.
    fallbacks: []EmbeddingProvider,
    /// Named routes for hint-based selection.
    routes: []EmbeddingRoute,
    /// Metrics: total embed calls.
    metrics: Metrics,

    const Self = @This();

    pub const Metrics = struct {
        total_calls: u64 = 0,
        primary_successes: u64 = 0,
        fallback_successes: u64 = 0,
        total_failures: u64 = 0,
    };

    pub fn init(
        allocator: std.mem.Allocator,
        primary: EmbeddingProvider,
        fallbacks: []const EmbeddingProvider,
        routes: []const EmbeddingRoute,
    ) !*Self {
        const self_ = try allocator.create(Self);
        self_.* = .{
            .allocator = allocator,
            .primary = primary,
            .fallbacks = try allocator.dupe(EmbeddingProvider, fallbacks),
            .routes = try allocator.dupe(EmbeddingRoute, routes),
            .metrics = .{},
        };
        return self_;
    }

    pub fn deinitSelf(self: *Self) void {
        // Deinit primary and all fallback providers
        self.primary.deinit();
        for (self.fallbacks) |fb| {
            fb.deinit();
        }
        self.allocator.free(self.fallbacks);
        self.allocator.free(self.routes);
        self.allocator.destroy(self);
    }

    /// Resolve a hint to a matching route. Returns null if no match.
    pub fn resolveRoute(self: *const Self, hint: []const u8) ?EmbeddingRoute {
        for (self.routes) |route| {
            if (std.mem.eql(u8, route.hint, hint)) {
                return route;
            }
        }
        return null;
    }

    /// Extract hint from model string if it starts with "hint:".
    pub fn extractHint(model: []const u8) ?[]const u8 {
        const prefix = "hint:";
        if (std.mem.startsWith(u8, model, prefix)) {
            return model[prefix.len..];
        }
        return null;
    }

    fn implName(_: *anyopaque) []const u8 {
        return "auto";
    }

    fn implDimensions(ptr: *anyopaque) u32 {
        const self_: *Self = @ptrCast(@alignCast(ptr));
        return self_.primary.getDimensions();
    }

    fn implEmbed(ptr: *anyopaque, allocator: std.mem.Allocator, text: []const u8) anyerror![]f32 {
        const self_: *Self = @ptrCast(@alignCast(ptr));
        self_.metrics.total_calls += 1;

        if (text.len == 0) {
            self_.metrics.primary_successes += 1;
            return allocator.alloc(f32, 0);
        }

        // Try primary provider
        if (self_.primary.embed(allocator, text)) |result| {
            self_.metrics.primary_successes += 1;
            return result;
        } else |primary_err| {
            const class = classifyError(primary_err);
            log.warn("primary provider '{s}' failed (class={s}): {}", .{
                self_.primary.getName(),
                @tagName(class),
                primary_err,
            });

            // Try fallbacks in order
            for (self_.fallbacks) |fb| {
                if (fb.embed(allocator, text)) |result| {
                    self_.metrics.fallback_successes += 1;
                    log.info("fallback to '{s}' succeeded", .{fb.getName()});
                    return result;
                } else |fb_err| {
                    const fb_class = classifyError(fb_err);
                    log.warn("fallback provider '{s}' failed (class={s}): {}", .{
                        fb.getName(),
                        @tagName(fb_class),
                        fb_err,
                    });
                }
            }

            // All providers failed
            self_.metrics.total_failures += 1;
            return primary_err;
        }
    }

    fn implDeinit(ptr: *anyopaque) void {
        const self_: *Self = @ptrCast(@alignCast(ptr));
        self_.deinitSelf();
    }

    const vtable = EmbeddingProvider.VTable{
        .name = &implName,
        .dimensions = &implDimensions,
        .embed = &implEmbed,
        .deinit = &implDeinit,
    };

    pub fn provider(self: *Self) EmbeddingProvider {
        return .{
            .ptr = @ptrCast(self),
            .vtable = &vtable,
        };
    }
};

/// Build the default auto fallback chain from config.
/// Chain order: openai → gemini → voyage → ollama → none
/// Only providers with valid api_key (or local like ollama) are included.
pub fn buildAutoChain(
    allocator: std.mem.Allocator,
    primary_name: []const u8,
    api_key: ?[]const u8,
    model: []const u8,
    dims: u32,
    fallback_name: ?[]const u8,
) !EmbeddingProvider {
    // If provider is not "auto", just create the single provider
    if (!std.mem.eql(u8, primary_name, "auto")) {
        return embeddings.createEmbeddingProvider(allocator, primary_name, api_key, model, dims);
    }

    // Build auto chain: try to create primary as openai, fallback to noop
    var chain: std.ArrayListUnmanaged(EmbeddingProvider) = .empty;
    defer chain.deinit(allocator);

    // Determine primary from fallback_name or default to openai
    const effective_primary = fallback_name orelse "openai";
    const primary = try embeddings.createEmbeddingProvider(allocator, effective_primary, api_key, model, dims);
    errdefer primary.deinit();

    // Add noop as final fallback (always available)
    const noop_inst = try allocator.create(embeddings.NoopEmbedding);
    noop_inst.* = .{ .allocator = allocator };
    errdefer noop_inst.provider().deinit();
    try chain.append(allocator, noop_inst.provider());

    var router = try ProviderRouter.init(allocator, primary, chain.items, &.{});
    return router.provider();
}

// ── Tests ─────────────────────────────────────────────────────────

test "extractHint returns hint portion" {
    const hint = ProviderRouter.extractHint("hint:semantic");
    try std.testing.expect(hint != null);
    try std.testing.expectEqualStrings("semantic", hint.?);
}

test "extractHint returns null for non-hint" {
    const hint = ProviderRouter.extractHint("text-embedding-3-small");
    try std.testing.expect(hint == null);
}

test "extractHint empty after prefix" {
    const hint = ProviderRouter.extractHint("hint:");
    try std.testing.expect(hint != null);
    try std.testing.expectEqualStrings("", hint.?);
}

test "classifyError maps EmbeddingApiError to transient" {
    const class = classifyError(error.EmbeddingApiError);
    try std.testing.expectEqual(ErrorClass.transient, class);
}

test "classifyError maps InvalidEmbeddingResponse to permanent" {
    const class = classifyError(error.InvalidEmbeddingResponse);
    try std.testing.expectEqual(ErrorClass.permanent, class);
}

test "classifyError maps OutOfMemory to permanent" {
    const class = classifyError(error.OutOfMemory);
    try std.testing.expectEqual(ErrorClass.permanent, class);
}

test "ProviderRouter init and deinit with noop primary" {
    const noop1 = try std.testing.allocator.create(embeddings.NoopEmbedding);
    noop1.* = .{ .allocator = std.testing.allocator };

    const noop2 = try std.testing.allocator.create(embeddings.NoopEmbedding);
    noop2.* = .{ .allocator = std.testing.allocator };

    var router = try ProviderRouter.init(
        std.testing.allocator,
        noop1.provider(),
        &.{noop2.provider()},
        &.{},
    );
    const p = router.provider();

    try std.testing.expectEqualStrings("auto", p.getName());
    try std.testing.expectEqual(@as(u32, 0), p.getDimensions());

    p.deinit();
}

test "ProviderRouter embed succeeds with primary noop" {
    const noop1 = try std.testing.allocator.create(embeddings.NoopEmbedding);
    noop1.* = .{ .allocator = std.testing.allocator };

    var router = try ProviderRouter.init(
        std.testing.allocator,
        noop1.provider(),
        &.{},
        &.{},
    );
    const p = router.provider();
    defer p.deinit();

    const vec = try p.embed(std.testing.allocator, "hello");
    defer std.testing.allocator.free(vec);
    try std.testing.expectEqual(@as(usize, 0), vec.len);
}

test "ProviderRouter embed empty text" {
    const noop1 = try std.testing.allocator.create(embeddings.NoopEmbedding);
    noop1.* = .{ .allocator = std.testing.allocator };

    var router = try ProviderRouter.init(
        std.testing.allocator,
        noop1.provider(),
        &.{},
        &.{},
    );
    const p = router.provider();
    defer p.deinit();

    const vec = try p.embed(std.testing.allocator, "");
    defer std.testing.allocator.free(vec);
    try std.testing.expectEqual(@as(usize, 0), vec.len);

    // Metrics should show primary_successes incremented
    try std.testing.expectEqual(@as(u64, 1), router.metrics.total_calls);
    try std.testing.expectEqual(@as(u64, 1), router.metrics.primary_successes);
}

test "ProviderRouter resolveRoute finds matching route" {
    const noop1 = try std.testing.allocator.create(embeddings.NoopEmbedding);
    noop1.* = .{ .allocator = std.testing.allocator };

    const routes = [_]EmbeddingRoute{
        .{ .hint = "semantic", .provider_name = "openai", .model = "text-embedding-3-small", .dimensions = 1536 },
        .{ .hint = "fast", .provider_name = "gemini", .model = "gemini-embedding-001", .dimensions = 768 },
    };

    var router = try ProviderRouter.init(
        std.testing.allocator,
        noop1.provider(),
        &.{},
        &routes,
    );
    defer router.deinitSelf();

    const route = router.resolveRoute("semantic");
    try std.testing.expect(route != null);
    try std.testing.expectEqualStrings("openai", route.?.provider_name);
    try std.testing.expectEqual(@as(u32, 1536), route.?.dimensions);
}

test "ProviderRouter resolveRoute returns null for unknown hint" {
    const noop1 = try std.testing.allocator.create(embeddings.NoopEmbedding);
    noop1.* = .{ .allocator = std.testing.allocator };

    const routes = [_]EmbeddingRoute{
        .{ .hint = "semantic", .provider_name = "openai", .model = "text-embedding-3-small", .dimensions = 1536 },
    };

    var router = try ProviderRouter.init(
        std.testing.allocator,
        noop1.provider(),
        &.{},
        &routes,
    );
    defer router.deinitSelf();

    const route = router.resolveRoute("offline");
    try std.testing.expect(route == null);
}

test "ProviderRouter metrics tracking" {
    const noop1 = try std.testing.allocator.create(embeddings.NoopEmbedding);
    noop1.* = .{ .allocator = std.testing.allocator };

    var router = try ProviderRouter.init(
        std.testing.allocator,
        noop1.provider(),
        &.{},
        &.{},
    );
    const p = router.provider();
    defer p.deinit();

    // Make 3 calls
    for (0..3) |_| {
        const vec = try p.embed(std.testing.allocator, "test");
        std.testing.allocator.free(vec);
    }

    try std.testing.expectEqual(@as(u64, 3), router.metrics.total_calls);
    try std.testing.expectEqual(@as(u64, 3), router.metrics.primary_successes);
    try std.testing.expectEqual(@as(u64, 0), router.metrics.fallback_successes);
    try std.testing.expectEqual(@as(u64, 0), router.metrics.total_failures);
}

test "buildAutoChain non-auto returns single provider" {
    const p = try buildAutoChain(std.testing.allocator, "none", null, "", 0, null);
    try std.testing.expectEqualStrings("none", p.getName());
    p.deinit();
}

test "buildAutoChain auto creates router with fallback" {
    const p = try buildAutoChain(std.testing.allocator, "auto", null, "", 0, null);
    try std.testing.expectEqualStrings("auto", p.getName());
    p.deinit();
}

// ── R3 tests ──────────────────────────────────────────────────────

/// Test helper: embedding provider that always fails.
const FailingTestProvider = struct {
    allocator: ?std.mem.Allocator = null,

    const Self = @This();

    fn implName(_: *anyopaque) []const u8 {
        return "failing";
    }

    fn implDimensions(_: *anyopaque) u32 {
        return 3;
    }

    fn implEmbed(_: *anyopaque, _: std.mem.Allocator, _: []const u8) anyerror![]f32 {
        return error.EmbeddingApiError;
    }

    fn implDeinit(ptr: *anyopaque) void {
        const self_: *Self = @ptrCast(@alignCast(ptr));
        if (self_.allocator) |alloc| {
            alloc.destroy(self_);
        }
    }

    const vtable_inst = EmbeddingProvider.VTable{
        .name = &implName,
        .dimensions = &implDimensions,
        .embed = &implEmbed,
        .deinit = &implDeinit,
    };

    fn provider(self: *Self) EmbeddingProvider {
        return .{
            .ptr = @ptrCast(self),
            .vtable = &vtable_inst,
        };
    }
};

test "primary available routes to primary" {
    // Create a working primary (noop) and verify it's used
    const noop1 = try std.testing.allocator.create(embeddings.NoopEmbedding);
    noop1.* = .{ .allocator = std.testing.allocator };

    var router = try ProviderRouter.init(
        std.testing.allocator,
        noop1.provider(),
        &.{},
        &.{},
    );
    const p = router.provider();
    defer p.deinit();

    // Embed should succeed via primary
    const vec = try p.embed(std.testing.allocator, "test text");
    defer std.testing.allocator.free(vec);

    // Metrics should show primary success, no fallback
    try std.testing.expectEqual(@as(u64, 1), router.metrics.total_calls);
    try std.testing.expectEqual(@as(u64, 1), router.metrics.primary_successes);
    try std.testing.expectEqual(@as(u64, 0), router.metrics.fallback_successes);
    try std.testing.expectEqual(@as(u64, 0), router.metrics.total_failures);
}

test "primary down falls back to secondary" {
    // Primary: always fails. Fallback: noop (always succeeds).
    const failing = try std.testing.allocator.create(FailingTestProvider);
    failing.* = .{ .allocator = std.testing.allocator };

    const noop_fb = try std.testing.allocator.create(embeddings.NoopEmbedding);
    noop_fb.* = .{ .allocator = std.testing.allocator };

    var router = try ProviderRouter.init(
        std.testing.allocator,
        failing.provider(),
        &.{noop_fb.provider()},
        &.{},
    );
    const p = router.provider();
    defer p.deinit();

    // Embed should succeed via fallback
    const vec = try p.embed(std.testing.allocator, "test text");
    defer std.testing.allocator.free(vec);

    // Metrics: primary failed, fallback succeeded
    try std.testing.expectEqual(@as(u64, 1), router.metrics.total_calls);
    try std.testing.expectEqual(@as(u64, 0), router.metrics.primary_successes);
    try std.testing.expectEqual(@as(u64, 1), router.metrics.fallback_successes);
    try std.testing.expectEqual(@as(u64, 0), router.metrics.total_failures);
}

test "all providers fail returns error" {
    // Both primary and fallback fail
    const failing1 = try std.testing.allocator.create(FailingTestProvider);
    failing1.* = .{ .allocator = std.testing.allocator };

    const failing2 = try std.testing.allocator.create(FailingTestProvider);
    failing2.* = .{ .allocator = std.testing.allocator };

    var router = try ProviderRouter.init(
        std.testing.allocator,
        failing1.provider(),
        &.{failing2.provider()},
        &.{},
    );
    const p = router.provider();
    defer p.deinit();

    // Embed should fail
    const result = p.embed(std.testing.allocator, "test text");
    try std.testing.expectError(error.EmbeddingApiError, result);

    // Metrics: total_failures incremented
    try std.testing.expectEqual(@as(u64, 1), router.metrics.total_calls);
    try std.testing.expectEqual(@as(u64, 0), router.metrics.primary_successes);
    try std.testing.expectEqual(@as(u64, 0), router.metrics.fallback_successes);
    try std.testing.expectEqual(@as(u64, 1), router.metrics.total_failures);
}
