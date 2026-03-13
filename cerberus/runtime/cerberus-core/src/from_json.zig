/// --from-json subcommand: non-interactive config generation from wizard answers.
///
/// Accepts a JSON string with wizard answers, applies them to the config,
/// saves, scaffolds the workspace, and prints {"status":"ok"} on success.
/// Used by nullhub to configure cerberus without interactive terminal input.
const std = @import("std");
const builtin = @import("builtin");
const onboard = @import("onboard.zig");
const channel_catalog = @import("channel_catalog.zig");
const config_mod = @import("config.zig");
const Config = config_mod.Config;

const WizardAnswers = struct {
    provider: ?[]const u8 = null,
    api_key: ?[]const u8 = null,
    model: ?[]const u8 = null,
    memory: ?[]const u8 = null,
    tunnel: ?[]const u8 = null,
    autonomy: ?[]const u8 = null,
    gateway_port: ?u16 = null,
    channels: ?[]const []const u8 = null,
};

const AutonomySelectionError = error{InvalidAutonomyLevel};
const ChannelSelectionError = error{
    UnknownChannel,
    ChannelDisabledInBuild,
    UnsupportedChannelInFromJson,
};

fn isKnownTunnelProvider(tunnel: []const u8) bool {
    for (onboard.tunnel_options) |option| {
        if (std.mem.eql(u8, option, tunnel)) return true;
    }
    return false;
}

fn applyAutonomySelection(cfg: *Config, autonomy: []const u8) AutonomySelectionError!void {
    if (std.mem.eql(u8, autonomy, "supervised")) {
        cfg.autonomy.level = .supervised;
        cfg.autonomy.require_approval_for_medium_risk = true;
        cfg.autonomy.block_high_risk_commands = true;
        return;
    }
    if (std.mem.eql(u8, autonomy, "autonomous")) {
        cfg.autonomy.level = .full;
        cfg.autonomy.require_approval_for_medium_risk = false;
        cfg.autonomy.block_high_risk_commands = true;
        return;
    }
    if (std.mem.eql(u8, autonomy, "fully_autonomous")) {
        cfg.autonomy.level = .full;
        cfg.autonomy.require_approval_for_medium_risk = false;
        cfg.autonomy.block_high_risk_commands = false;
        return;
    }
    return error.InvalidAutonomyLevel;
}

fn applyChannelsSelection(cfg: *Config, channels: []const []const u8) ChannelSelectionError!void {
    var webhook_selected = false;

    for (channels) |channel_key| {
        const meta = channel_catalog.findByKey(channel_key) orelse {
            if (!builtin.is_test) std.debug.print("error: unknown channel '{s}'\n", .{channel_key});
            return error.UnknownChannel;
        };
        if (!channel_catalog.isBuildEnabled(meta.id)) {
            if (!builtin.is_test) std.debug.print("error: channel '{s}' is disabled in this build\n", .{channel_key});
            return error.ChannelDisabledInBuild;
        }

        switch (meta.id) {
            .webhook => webhook_selected = true,
            .cli => {}, // CLI is always enabled by default.
            else => {
                if (!builtin.is_test) {
                    std.debug.print(
                        "error: channel '{s}' requires interactive/manual setup; --from-json currently supports only 'webhook'\n",
                        .{channel_key},
                    );
                }
                return error.UnsupportedChannelInFromJson;
            },
        }
    }

    cfg.channels.webhook = if (webhook_selected) .{ .port = cfg.gateway.port } else null;
}

pub fn run(allocator: std.mem.Allocator, args: []const []const u8) !void {
    if (args.len == 0) {
        std.debug.print("error: --from-json requires a JSON argument\n", .{});
        std.process.exit(1);
    }

    const json_str = args[0];
    const parsed = std.json.parseFromSlice(
        WizardAnswers,
        allocator,
        json_str,
        .{ .allocate = .alloc_always, .ignore_unknown_fields = true },
    ) catch {
        std.debug.print("error: invalid JSON\n", .{});
        std.process.exit(1);
    };
    defer parsed.deinit();
    const answers = parsed.value;

    // Load existing config or create fresh
    var cfg = Config.load(allocator) catch try onboard.initFreshConfig(allocator);
    defer cfg.deinit();

    // Apply provider and API key
    if (answers.provider) |p| {
        const provider_info = onboard.resolveProviderForQuickSetup(p) orelse {
            std.debug.print("error: unknown provider '{s}'\n", .{p});
            std.process.exit(1);
        };
        cfg.default_provider = try cfg.allocator.dupe(u8, provider_info.key);

        if (answers.api_key) |key| {
            // Store in providers section (same pattern as runQuickSetup)
            const entries = try cfg.allocator.alloc(config_mod.ProviderEntry, 1);
            entries[0] = .{
                .name = try cfg.allocator.dupe(u8, provider_info.key),
                .api_key = try cfg.allocator.dupe(u8, key),
            };
            cfg.providers = entries;
        }
    } else if (answers.api_key) |key| {
        // API key without provider change: set for the current default_provider
        const entries = try cfg.allocator.alloc(config_mod.ProviderEntry, 1);
        entries[0] = .{
            .name = try cfg.allocator.dupe(u8, cfg.default_provider),
            .api_key = try cfg.allocator.dupe(u8, key),
        };
        cfg.providers = entries;
    }

    // Apply model (explicit or derive from provider)
    if (answers.model) |m| {
        cfg.default_model = try cfg.allocator.dupe(u8, m);
    } else if (answers.provider != null) {
        cfg.default_model = try cfg.allocator.dupe(u8, onboard.defaultModelForProvider(cfg.default_provider));
    }

    // Apply memory backend
    if (answers.memory) |m| {
        const backend = onboard.resolveMemoryBackendForQuickSetup(m) catch |err| switch (err) {
            error.UnknownMemoryBackend => {
                std.debug.print("error: unknown memory backend '{s}'\n", .{m});
                std.process.exit(1);
            },
            error.MemoryBackendDisabledInBuild => {
                std.debug.print("error: memory backend '{s}' is disabled in this build\n", .{m});
                std.process.exit(1);
            },
        };
        cfg.memory.backend = backend.name;
        cfg.memory.profile = onboard.memoryProfileForBackend(backend.name);
        cfg.memory.auto_save = backend.auto_save_default;
    }

    // Apply tunnel provider
    if (answers.tunnel) |t| {
        if (!isKnownTunnelProvider(t)) {
            std.debug.print("error: invalid tunnel provider '{s}'\n", .{t});
            std.process.exit(1);
        }
        cfg.tunnel.provider = try cfg.allocator.dupe(u8, t);
    }

    // Apply autonomy level
    if (answers.autonomy) |a| {
        applyAutonomySelection(&cfg, a) catch {
            std.debug.print("error: invalid autonomy level '{s}'\n", .{a});
            std.process.exit(1);
        };
    }

    // Apply gateway port
    if (answers.gateway_port) |port| {
        if (port == 0) {
            std.debug.print("error: gateway_port must be > 0\n", .{});
            std.process.exit(1);
        }
        cfg.gateway.port = port;
    }

    // Apply channels selection (currently supports webhook only).
    // We fail-fast on unsupported channel keys to avoid silent no-op behavior.
    if (answers.channels) |channels| {
        _ = applyChannelsSelection(&cfg, channels) catch {
            std.process.exit(1);
        };
    }

    // Ensure a valid default model exists even when omitted in JSON payload.
    if (cfg.default_model == null) {
        cfg.default_model = try cfg.allocator.dupe(u8, onboard.defaultModelForProvider(cfg.default_provider));
    }

    // Sync flat convenience fields
    cfg.syncFlatFields();
    cfg.validate() catch |err| {
        Config.printValidationError(err);
        std.process.exit(1);
    };

    // Ensure parent config directory and workspace directory exist
    if (std.fs.path.dirname(cfg.workspace_dir)) |parent| {
        std.fs.makeDirAbsolute(parent) catch |err| switch (err) {
            error.PathAlreadyExists => {},
            else => return err,
        };
    }
    std.fs.makeDirAbsolute(cfg.workspace_dir) catch |err| switch (err) {
        error.PathAlreadyExists => {},
        else => return err,
    };

    // Scaffold workspace files
    try onboard.scaffoldWorkspace(allocator, cfg.workspace_dir, &onboard.ProjectContext{});

    // Save config
    try cfg.save();

    // Output success as JSON to stdout
    var stdout_buf: [4096]u8 = undefined;
    var bw = std.fs.File.stdout().writer(&stdout_buf);
    try bw.interface.writeAll("{\"status\":\"ok\"}\n");
    try bw.interface.flush();
}

test "from_json requires JSON argument" {
    // Cannot easily test process.exit in-process; just verify the function signature compiles.
    // The real integration test is: cerberus --from-json '{"provider":"openrouter"}'
}

test "isKnownTunnelProvider validates wizard options" {
    try std.testing.expect(isKnownTunnelProvider("none"));
    try std.testing.expect(isKnownTunnelProvider("cloudflare"));
    try std.testing.expect(!isKnownTunnelProvider("invalid-tunnel"));
}

test "applyAutonomySelection rejects invalid value" {
    var cfg = Config{
        .workspace_dir = "/tmp",
        .config_path = "/tmp/config.json",
        .allocator = std.testing.allocator,
    };
    try std.testing.expectError(error.InvalidAutonomyLevel, applyAutonomySelection(&cfg, "danger-mode"));
}

test "applyChannelsSelection supports webhook and rejects unsupported channels" {
    var cfg = Config{
        .workspace_dir = "/tmp",
        .config_path = "/tmp/config.json",
        .allocator = std.testing.allocator,
    };

    try applyChannelsSelection(&cfg, &.{"webhook"});
    try std.testing.expect(cfg.channels.webhook != null);
    try std.testing.expectEqual(@as(u16, 3000), cfg.channels.webhook.?.port);

    try std.testing.expectError(error.UnsupportedChannelInFromJson, applyChannelsSelection(&cfg, &.{"telegram"}));
    try std.testing.expectError(error.UnknownChannel, applyChannelsSelection(&cfg, &.{"not-a-channel"}));
}
