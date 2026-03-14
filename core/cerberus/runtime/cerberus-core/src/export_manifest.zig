/// Export manifest JSON for nullhub integration.
///
/// Generates the manifest from the same data structures used by the
/// interactive wizard (onboard.zig) and channel catalog, ensuring a
/// single source of truth.
const std = @import("std");
const onboard = @import("onboard.zig");
const channel_catalog = @import("channel_catalog.zig");
const memory_root = @import("memory/root.zig");
const version = @import("version.zig");

fn writeOption(out: *std.Io.Writer, value: []const u8, label: []const u8) !void {
    try out.print("          {{ \"value\": {f}, \"label\": {f} }}", .{
        std.json.fmt(value, .{}),
        std.json.fmt(label, .{}),
    });
}

pub fn writeManifest(out: *std.Io.Writer) !void {
    // ── Top-level fields ─────────────────────────────────────────────
    try out.writeAll(
        \\{
        \\  "schema_version": 1,
        \\  "version":
    );
    try out.print("{f}", .{std.json.fmt(version.string, .{})});
    try out.writeAll(
        \\,
        \\  "name": "cerberus",
        \\  "display_name": "Cerberus",
        \\  "description": "Autonomous AI agent runtime",
        \\  "icon": "agent",
        \\  "repo": "cerberus/cerberus",
        \\
    );

    // ── Platforms ────────────────────────────────────────────────────
    try out.writeAll(
        \\  "platforms": {
        \\    "aarch64-macos": { "asset": "cerberus-macos-aarch64", "binary": "cerberus" },
        \\    "x86_64-macos": { "asset": "cerberus-macos-x86_64", "binary": "cerberus" },
        \\    "x86_64-linux": { "asset": "cerberus-linux-x86_64", "binary": "cerberus" },
        \\    "aarch64-linux": { "asset": "cerberus-linux-aarch64", "binary": "cerberus" },
        \\    "riscv64-linux": { "asset": "cerberus-linux-riscv64", "binary": "cerberus" },
        \\    "x86_64-windows": { "asset": "cerberus-windows-x86_64.exe", "binary": "cerberus.exe" },
        \\    "aarch64-windows": { "asset": "cerberus-windows-aarch64.exe", "binary": "cerberus.exe" }
        \\  },
        \\
    );

    // ── Build from source ───────────────────────────────────────────
    try out.writeAll(
        \\  "build_from_source": {
        \\    "zig_version": "0.15.2",
        \\    "command": "zig build -Doptimize=ReleaseSmall",
        \\    "output": "zig-out/bin/cerberus"
        \\  },
        \\
    );

    // ── Launch / health / ports ─────────────────────────────────────
    try out.writeAll(
        \\  "launch": { "command": "gateway", "args": [] },
        \\  "health": { "endpoint": "/health", "port_from_config": "gateway.port", "interval_ms": 15000 },
        \\  "ports": [
        \\    { "name": "gateway", "config_key": "gateway.port", "default": 3000, "protocol": "http" }
        \\  ],
        \\
    );

    // ── Wizard ──────────────────────────────────────────────────────
    try out.writeAll(
        \\  "wizard": {
        \\    "steps": [
        \\
    );

    // Step 1: provider (select)
    try out.writeAll(
        \\      {
        \\        "id": "provider",
        \\        "title": "AI Provider",
        \\        "description": "Select your AI model provider",
        \\        "type": "select",
        \\        "required": true,
        \\        "options": [
        \\
    );
    for (onboard.known_providers, 0..) |p, i| {
        var desc_buf: [512]u8 = undefined;
        const description = std.fmt.bufPrint(&desc_buf, "Default model: {s}", .{p.default_model}) catch "Default model";
        try out.print("          {{ \"value\": {f}, \"label\": {f}, \"description\": {f} }}", .{
            std.json.fmt(p.key, .{}),
            std.json.fmt(p.label, .{}),
            std.json.fmt(description, .{}),
        });
        if (i < onboard.known_providers.len - 1) {
            try out.writeAll(",");
        }
        try out.writeAll("\n");
    }
    try out.writeAll(
        \\        ]
        \\      },
        \\
    );

    // Step 2: api_key (secret, conditional)
    try out.writeAll(
        \\      {
        \\        "id": "api_key",
        \\        "title": "API Key",
        \\        "description": "Your provider API key",
        \\        "type": "secret",
        \\        "required": true,
        \\        "condition": { "step": "provider", "not_equals": "ollama" }
        \\      },
        \\
    );

    // Step 3: model (dynamic_select)
    try out.writeAll(
        \\      {
        \\        "id": "model",
        \\        "title": "Model",
        \\        "description": "Select the AI model to use",
        \\        "type": "dynamic_select",
        \\        "required": true,
        \\        "dynamic_source": { "command": "--list-models", "depends_on": ["provider", "api_key"] }
        \\      },
        \\
    );

    // Step 4: memory (select)
    try out.writeAll(
        \\      {
        \\        "id": "memory",
        \\        "title": "Memory Backend",
        \\        "description": "How the agent stores conversation history",
        \\        "type": "select",
        \\        "required": true,
        \\        "options": [
        \\
    );
    var wrote_memory = false;
    for (onboard.wizard_memory_backend_order) |name| {
        if (memory_root.findBackend(name) == null) continue;
        if (wrote_memory) try out.writeAll(",\n");
        try writeOption(out, name, name);
        wrote_memory = true;
    }
    if (wrote_memory) try out.writeAll("\n");
    try out.writeAll(
        \\        ]
        \\      },
        \\
    );

    // Step 5: tunnel (select)
    try out.writeAll(
        \\      {
        \\        "id": "tunnel",
        \\        "title": "Tunnel Provider",
        \\        "description": "Expose your agent to the internet",
        \\        "type": "select",
        \\        "required": true,
        \\        "options": [
        \\
    );
    for (onboard.tunnel_options, 0..) |name, i| {
        try writeOption(out, name, name);
        if (i < onboard.tunnel_options.len - 1) {
            try out.writeAll(",");
        }
        try out.writeAll("\n");
    }
    try out.writeAll(
        \\        ]
        \\      },
        \\
    );

    // Step 6: autonomy (select)
    try out.writeAll(
        \\      {
        \\        "id": "autonomy",
        \\        "title": "Autonomy Level",
        \\        "description": "How much freedom the agent has",
        \\        "type": "select",
        \\        "required": true,
        \\        "options": [
        \\
    );
    for (onboard.autonomy_options, 0..) |name, i| {
        try writeOption(out, name, name);
        if (i < onboard.autonomy_options.len - 1) {
            try out.writeAll(",");
        }
        try out.writeAll("\n");
    }
    try out.writeAll(
        \\        ]
        \\      },
        \\
    );

    // Step 7: channels (multi_select)
    try out.writeAll(
        \\      {
        \\        "id": "channels",
        \\        "title": "Channels",
        \\        "description": "Messaging channels to enable (non-interactive: webhook only)",
        \\        "type": "multi_select",
        \\        "required": false,
        \\        "options": [
        \\
    );
    var wrote_channel = false;
    for (channel_catalog.known_channels) |ch| {
        if (!channel_catalog.isBuildEnabled(ch.id)) continue;
        if (!onboard.isWizardInteractiveChannel(ch.id)) continue;
        if (ch.id != .webhook) continue;
        if (wrote_channel) try out.writeAll(",\n");
        try writeOption(out, ch.key, ch.label);
        wrote_channel = true;
    }
    if (wrote_channel) try out.writeAll("\n");
    try out.writeAll(
        \\        ]
        \\      },
        \\
    );

    // Step 8: gateway_port (number)
    try out.writeAll(
        \\      {
        \\        "id": "gateway_port",
        \\        "title": "Gateway Port",
        \\        "description": "HTTP gateway listen port",
        \\        "type": "number",
        \\        "required": true
        \\      }
        \\
    );

    // Close wizard and steps
    try out.writeAll(
        \\    ]
        \\  },
        \\
    );

    // ── depends_on / connects_to ────────────────────────────────────
    try out.writeAll(
        \\  "depends_on": [],
        \\  "connects_to": [
        \\    { "component": "nullboiler", "role": "worker", "description": "Registers as a worker node" }
        \\  ]
        \\}
        \\
    );
}

pub fn run() !void {
    var buf: [65536]u8 = undefined;
    var bw = std.fs.File.stdout().writer(&buf);
    try writeManifest(&bw.interface);
    try bw.interface.flush();
}

fn findStepOptions(steps: std.json.Array, step_id: []const u8) ?std.json.Array {
    for (steps.items) |step| {
        if (step != .object) continue;
        const id_val = step.object.get("id") orelse continue;
        if (id_val != .string) continue;
        if (!std.mem.eql(u8, id_val.string, step_id)) continue;
        const options_val = step.object.get("options") orelse return null;
        if (options_val != .array) return null;
        return options_val.array;
    }
    return null;
}

test "export_manifest produces valid structure and filtered options" {
    var aw: std.Io.Writer.Allocating = .init(std.testing.allocator);
    defer aw.deinit();
    try writeManifest(&aw.writer);
    const rendered = aw.writer.buffer[0..aw.writer.end];

    const parsed = try std.json.parseFromSlice(std.json.Value, std.testing.allocator, rendered, .{});
    defer parsed.deinit();
    try std.testing.expect(parsed.value == .object);

    const root = parsed.value.object;
    const version_val = root.get("version") orelse return error.TestUnexpectedResult;
    try std.testing.expect(version_val == .string);
    try std.testing.expectEqualStrings(version.string, version_val.string);

    const wizard_val = root.get("wizard") orelse return error.TestUnexpectedResult;
    try std.testing.expect(wizard_val == .object);
    const steps_val = wizard_val.object.get("steps") orelse return error.TestUnexpectedResult;
    try std.testing.expect(steps_val == .array);

    const memory_options = findStepOptions(steps_val.array, "memory") orelse return error.TestUnexpectedResult;
    for (memory_options.items) |entry| {
        try std.testing.expect(entry == .object);
        const value = entry.object.get("value") orelse return error.TestUnexpectedResult;
        try std.testing.expect(value == .string);
        try std.testing.expect(memory_root.findBackend(value.string) != null);
    }

    const channel_options = findStepOptions(steps_val.array, "channels") orelse return error.TestUnexpectedResult;
    try std.testing.expect(channel_options.items.len == 1);
    const channel_entry = channel_options.items[0];
    try std.testing.expect(channel_entry == .object);
    const channel_value = channel_entry.object.get("value") orelse return error.TestUnexpectedResult;
    try std.testing.expect(channel_value == .string);
    try std.testing.expectEqualStrings("webhook", channel_value.string);
}
