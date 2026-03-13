const std = @import("std");
const root = @import("root.zig");
const Tool = root.Tool;
const ToolResult = root.ToolResult;
const JsonObjectMap = root.JsonObjectMap;

/// RAM base for STM32F401 Nucleo boards.
const NUCLEO_RAM_BASE: u64 = 0x2000_0000;

/// Maximum output size from probe-rs commands (64 KB).
const MAX_PROBE_OUTPUT: usize = 65_536;

/// Hardware memory read/write tool — read/write memory at addresses via probe-rs or serial.
/// Supports Nucleo boards connected via USB.
pub const HardwareMemoryTool = struct {
    boards: []const []const u8,

    pub const tool_name = "hardware_memory";
    pub const tool_description = "Read/write hardware memory maps via probe-rs or serial. " ++
        "Use for: 'read memory', 'read register', 'dump memory', 'write memory'. " ++
        "Params: action (read/write), address (hex), length (bytes), value (for write).";
    pub const tool_params =
        \\{"type":"object","properties":{"action":{"type":"string","enum":["read","write"],"description":"read or write memory"},"address":{"type":"string","description":"Memory address in hex (e.g. 0x20000000)"},"length":{"type":"integer","description":"Bytes to read (default 128, max 256)"},"value":{"type":"string","description":"Hex value to write (for write action)"},"board":{"type":"string","description":"Board name (optional if only one configured)"}},"required":["action"]}
    ;

    const vtable = root.ToolVTable(@This());

    pub fn tool(self: *HardwareMemoryTool) Tool {
        return .{
            .ptr = @ptrCast(self),
            .vtable = &vtable,
        };
    }

    pub fn execute(self: *HardwareMemoryTool, allocator: std.mem.Allocator, args: JsonObjectMap) !ToolResult {
        if (self.boards.len == 0) {
            return ToolResult.fail("No peripherals configured. Add boards to config.toml [peripherals.boards].");
        }

        const action = root.getString(args, "action") orelse
            return ToolResult.fail("Missing 'action' parameter (read or write)");

        const board = root.getString(args, "board") orelse
            (if (self.boards.len > 0) self.boards[0] else "unknown");

        // Validate board is a supported type
        const chip = chipForBoard(board) orelse {
            const msg = try std.fmt.allocPrint(allocator, "Memory operations only support nucleo-f401re, nucleo-f411re. Got: {s}", .{board});
            return ToolResult{ .success = false, .output = "", .error_msg = msg };
        };

        const address_str = root.getString(args, "address") orelse "0x20000000";
        const address = parseHexAddress(address_str) orelse NUCLEO_RAM_BASE;

        if (std.mem.eql(u8, action, "read")) {
            const length_raw = root.getInt(args, "length") orelse 128;
            const length: usize = @intCast(@min(@max(length_raw, 1), 256));
            return probeRead(allocator, chip, address, length);
        } else if (std.mem.eql(u8, action, "write")) {
            const value = root.getString(args, "value") orelse
                return ToolResult.fail("Missing 'value' parameter for write action");
            return probeWrite(allocator, chip, address, value);
        } else {
            const msg = try std.fmt.allocPrint(allocator, "Unknown action '{s}'. Use 'read' or 'write'.", .{action});
            return ToolResult{ .success = false, .output = "", .error_msg = msg };
        }
    }
};

const proc = @import("process_util.zig");

/// Check if probe-rs is available on the system.
fn probeRsAvailable(allocator: std.mem.Allocator) bool {
    const result = proc.run(allocator, &.{ "probe-rs", "--version" }, .{ .max_output_bytes = 4096 }) catch return false;
    result.deinit(allocator);
    return result.success;
}

/// Execute a probe-rs read command: `probe-rs read --chip CHIP ADDRESS LENGTH`
fn probeRead(allocator: std.mem.Allocator, chip: []const u8, address: u64, length: usize) !ToolResult {
    if (!probeRsAvailable(allocator)) {
        return ToolResult.fail("probe-rs not found. Install with: cargo install probe-rs-tools");
    }

    const addr_str = try std.fmt.allocPrint(allocator, "0x{X:0>8}", .{address});
    defer allocator.free(addr_str);
    const len_str = try std.fmt.allocPrint(allocator, "{d}", .{length});
    defer allocator.free(len_str);

    const result = proc.run(allocator, &.{ "probe-rs", "read", "--chip", chip, addr_str, len_str }, .{ .max_output_bytes = MAX_PROBE_OUTPUT }) catch {
        return ToolResult.fail("Failed to spawn probe-rs read command");
    };
    defer allocator.free(result.stderr);

    if (result.success) {
        if (result.stdout.len > 0) return ToolResult{ .success = true, .output = result.stdout };
        allocator.free(result.stdout);
        return ToolResult{ .success = true, .output = try allocator.dupe(u8, "(no output from probe-rs)") };
    }
    defer allocator.free(result.stdout);
    if (result.exit_code) |code| {
        const err_msg = try std.fmt.allocPrint(
            allocator,
            "probe-rs read failed (exit {d}): {s}",
            .{ code, if (result.stderr.len > 0) result.stderr else "unknown error" },
        );
        return ToolResult{ .success = false, .output = "", .error_msg = err_msg };
    }
    return ToolResult{ .success = false, .output = "", .error_msg = "probe-rs read terminated by signal" };
}

/// Execute a probe-rs write command: `probe-rs write --chip CHIP ADDRESS VALUE`
fn probeWrite(allocator: std.mem.Allocator, chip: []const u8, address: u64, value: []const u8) !ToolResult {
    if (!probeRsAvailable(allocator)) {
        return ToolResult.fail("probe-rs not found. Install with: cargo install probe-rs-tools");
    }

    const addr_str = try std.fmt.allocPrint(allocator, "0x{X:0>8}", .{address});
    defer allocator.free(addr_str);

    const result = proc.run(allocator, &.{ "probe-rs", "write", "--chip", chip, addr_str, value }, .{ .max_output_bytes = MAX_PROBE_OUTPUT }) catch {
        return ToolResult.fail("Failed to spawn probe-rs write command");
    };
    defer allocator.free(result.stderr);

    if (result.success) {
        defer allocator.free(result.stdout);
        const out = try std.fmt.allocPrint(
            allocator,
            "Write OK: 0x{X:0>8} <- {s} ({s}){s}",
            .{ address, value, chip, if (result.stdout.len > 0) result.stdout else "" },
        );
        return ToolResult{ .success = true, .output = out };
    }
    defer allocator.free(result.stdout);
    if (result.exit_code) |code| {
        const err_msg = try std.fmt.allocPrint(
            allocator,
            "probe-rs write failed (exit {d}): {s}",
            .{ code, if (result.stderr.len > 0) result.stderr else "unknown error" },
        );
        return ToolResult{ .success = false, .output = "", .error_msg = err_msg };
    }
    return ToolResult{ .success = false, .output = "", .error_msg = "probe-rs write terminated by signal" };
}

fn chipForBoard(board: []const u8) ?[]const u8 {
    if (std.mem.eql(u8, board, "nucleo-f401re")) return "STM32F401RETx";
    if (std.mem.eql(u8, board, "nucleo-f411re")) return "STM32F411RETx";
    return null;
}

fn parseHexAddress(s: []const u8) ?u64 {
    var trimmed = s;
    if (std.mem.startsWith(u8, trimmed, "0x") or std.mem.startsWith(u8, trimmed, "0X")) {
        trimmed = trimmed[2..];
    }
    return std.fmt.parseInt(u64, trimmed, 16) catch null;
}

// ── Tests ───────────────────────────────────────────────────────────

test "hardware_memory tool name" {
    var hm = HardwareMemoryTool{ .boards = &.{} };
    const t = hm.tool();
    try std.testing.expectEqualStrings("hardware_memory", t.name());
}

test "hardware_memory schema has action" {
    var hm = HardwareMemoryTool{ .boards = &.{} };
    const t = hm.tool();
    const schema = t.parametersJson();
    try std.testing.expect(std.mem.indexOf(u8, schema, "action") != null);
    try std.testing.expect(std.mem.indexOf(u8, schema, "address") != null);
}

test "hardware_memory no boards returns error" {
    var hm = HardwareMemoryTool{ .boards = &.{} };
    const t = hm.tool();
    const parsed = try root.parseTestArgs("{\"action\": \"read\"}");
    defer parsed.deinit();
    const result = try t.execute(std.testing.allocator, parsed.value.object);
    try std.testing.expect(!result.success);
    try std.testing.expect(std.mem.indexOf(u8, result.error_msg.?, "peripherals") != null);
}

test "hardware_memory missing action returns error" {
    const boards = [_][]const u8{"nucleo-f401re"};
    var hm = HardwareMemoryTool{ .boards = &boards };
    const t = hm.tool();
    const parsed = try root.parseTestArgs("{}");
    defer parsed.deinit();
    const result = try t.execute(std.testing.allocator, parsed.value.object);
    try std.testing.expect(!result.success);
    try std.testing.expect(std.mem.indexOf(u8, result.error_msg.?, "action") != null);
}

test "hardware_memory unsupported board" {
    const boards = [_][]const u8{"esp32"};
    var hm = HardwareMemoryTool{ .boards = &boards };
    const t = hm.tool();
    const parsed = try root.parseTestArgs("{\"action\": \"read\", \"board\": \"esp32\"}");
    defer parsed.deinit();
    const result = try t.execute(std.testing.allocator, parsed.value.object);
    defer if (result.error_msg) |e| std.testing.allocator.free(e);
    try std.testing.expect(!result.success);
    try std.testing.expect(std.mem.indexOf(u8, result.error_msg.?, "nucleo") != null);
}

test "hardware_memory read without probe-rs" {
    const boards = [_][]const u8{"nucleo-f401re"};
    var hm = HardwareMemoryTool{ .boards = &boards };
    const t = hm.tool();
    const parsed = try root.parseTestArgs("{\"action\": \"read\", \"address\": \"0x20000000\", \"length\": 64}");
    defer parsed.deinit();
    const result = try t.execute(std.testing.allocator, parsed.value.object);
    // Only free heap-allocated output/error_msg (probe-rs failure returns a
    // heap-allocated error when the command runs but fails, or allocPrint output
    // on success; ToolResult.fail() returns a string literal that must NOT be freed).
    const has_probe = probeRsAvailable(std.testing.allocator);
    defer if (result.output.len > 0) std.testing.allocator.free(result.output);
    defer if (has_probe) {
        if (result.error_msg) |e| std.testing.allocator.free(e);
    };
    if (has_probe) {
        // probe-rs is installed — we expect a real result (success or device error)
        // Either way, no crash is the key assertion.
    } else {
        // probe-rs not found — expect helpful error message
        try std.testing.expect(!result.success);
        try std.testing.expect(result.error_msg != null);
        try std.testing.expect(std.mem.indexOf(u8, result.error_msg.?, "probe-rs not found") != null);
    }
}

test "hardware_memory write without probe-rs" {
    const boards = [_][]const u8{"nucleo-f401re"};
    var hm = HardwareMemoryTool{ .boards = &boards };
    const t = hm.tool();
    const parsed = try root.parseTestArgs("{\"action\": \"write\", \"address\": \"0x20000000\", \"value\": \"DEADBEEF\"}");
    defer parsed.deinit();
    const result = try t.execute(std.testing.allocator, parsed.value.object);
    const has_probe = probeRsAvailable(std.testing.allocator);
    defer if (result.output.len > 0) std.testing.allocator.free(result.output);
    defer if (has_probe) {
        if (result.error_msg) |e| std.testing.allocator.free(e);
    };
    if (has_probe) {
        // probe-rs is installed — we expect a real result (success or device error)
    } else {
        // probe-rs not found — expect helpful error message
        try std.testing.expect(!result.success);
        try std.testing.expect(result.error_msg != null);
        try std.testing.expect(std.mem.indexOf(u8, result.error_msg.?, "probe-rs not found") != null);
    }
}

test "hardware_memory write missing value" {
    const boards = [_][]const u8{"nucleo-f401re"};
    var hm = HardwareMemoryTool{ .boards = &boards };
    const t = hm.tool();
    const parsed = try root.parseTestArgs("{\"action\": \"write\", \"address\": \"0x20000000\"}");
    defer parsed.deinit();
    const result = try t.execute(std.testing.allocator, parsed.value.object);
    try std.testing.expect(!result.success);
    try std.testing.expect(std.mem.indexOf(u8, result.error_msg.?, "value") != null);
}

test "hardware_memory unknown action" {
    const boards = [_][]const u8{"nucleo-f401re"};
    var hm = HardwareMemoryTool{ .boards = &boards };
    const t = hm.tool();
    const parsed = try root.parseTestArgs("{\"action\": \"delete\"}");
    defer parsed.deinit();
    const result = try t.execute(std.testing.allocator, parsed.value.object);
    defer if (result.error_msg) |e| std.testing.allocator.free(e);
    try std.testing.expect(!result.success);
}

test "parseHexAddress valid" {
    try std.testing.expectEqual(@as(?u64, 0x20000000), parseHexAddress("0x20000000"));
    try std.testing.expectEqual(@as(?u64, 0x20000000), parseHexAddress("0X20000000"));
    try std.testing.expectEqual(@as(?u64, 0xFF), parseHexAddress("FF"));
    try std.testing.expectEqual(@as(?u64, 0), parseHexAddress("0x0"));
}

test "parseHexAddress invalid" {
    try std.testing.expect(parseHexAddress("not_hex") == null);
    try std.testing.expect(parseHexAddress("") == null);
}

test "chipForBoard known" {
    try std.testing.expectEqualStrings("STM32F401RETx", chipForBoard("nucleo-f401re").?);
    try std.testing.expectEqualStrings("STM32F411RETx", chipForBoard("nucleo-f411re").?);
}

test "chipForBoard unknown" {
    try std.testing.expect(chipForBoard("esp32") == null);
    try std.testing.expect(chipForBoard("unknown") == null);
}
