const std = @import("std");
const builtin = @import("builtin");
const root = @import("root.zig");
const Tool = root.Tool;
const ToolResult = root.ToolResult;
const JsonObjectMap = root.JsonObjectMap;

/// Screenshot tool — capture the screen using platform-native commands.
/// macOS: `screencapture -x FILE`
/// Linux: `import FILE` (ImageMagick)
pub const ScreenshotTool = struct {
    workspace_dir: []const u8,

    pub const tool_name = "screenshot";
    pub const tool_description = "Capture a screenshot of the current screen. Returns [IMAGE:path] marker — include it verbatim in your response to send the image to the user.";
    pub const tool_params =
        \\{"type":"object","properties":{"filename":{"type":"string","description":"Optional filename (default: screenshot.png). Saved in workspace."}}}
    ;

    const vtable = root.ToolVTable(@This());

    pub fn tool(self: *ScreenshotTool) Tool {
        return .{
            .ptr = @ptrCast(self),
            .vtable = &vtable,
        };
    }

    pub fn execute(self: *ScreenshotTool, allocator: std.mem.Allocator, args: JsonObjectMap) !ToolResult {
        const filename = root.getString(args, "filename") orelse "screenshot.png";

        // Build output path: workspace_dir/filename
        const output_path = try std.fmt.allocPrint(allocator, "{s}/{s}", .{ self.workspace_dir, filename });
        defer allocator.free(output_path);

        // In test mode, return a mock result without spawning a real process
        if (comptime builtin.is_test) {
            const msg = try std.fmt.allocPrint(allocator, "[IMAGE:{s}]", .{output_path});
            return ToolResult{ .success = true, .output = msg };
        }

        // Platform-specific screenshot command
        const argv: []const []const u8 = switch (comptime builtin.os.tag) {
            .macos => &.{ "screencapture", "-x", output_path },
            .linux => &.{ "import", "-window", "root", output_path },
            else => {
                return ToolResult.fail("Screenshot not supported on this platform");
            },
        };

        const proc = @import("process_util.zig");
        const result = proc.run(allocator, argv, .{}) catch {
            return ToolResult.fail("Failed to spawn screenshot command");
        };
        defer result.deinit(allocator);

        if (result.success) {
            const msg = try std.fmt.allocPrint(allocator, "[IMAGE:{s}/{s}]", .{ self.workspace_dir, filename });
            return ToolResult{ .success = true, .output = msg };
        }
        const err_msg = try std.fmt.allocPrint(allocator, "Screenshot command failed: {s}", .{if (result.stderr.len > 0) result.stderr else "unknown error"});
        return ToolResult{ .success = false, .output = "", .error_msg = err_msg };
    }
};

// ── Tests ───────────────────────────────────────────────────────────

test "screenshot tool name" {
    var st = ScreenshotTool{ .workspace_dir = "/tmp" };
    const t = st.tool();
    try std.testing.expectEqualStrings("screenshot", t.name());
}

test "screenshot tool schema has filename" {
    var st = ScreenshotTool{ .workspace_dir = "/tmp" };
    const t = st.tool();
    const schema = t.parametersJson();
    try std.testing.expect(std.mem.indexOf(u8, schema, "filename") != null);
}

test "screenshot execute returns mock in test mode" {
    const allocator = std.testing.allocator;
    var st = ScreenshotTool{ .workspace_dir = "/tmp/workspace" };
    const parsed = try root.parseTestArgs("{}");
    defer parsed.deinit();
    const result = try st.execute(allocator, parsed.value.object);
    defer allocator.free(result.output);
    try std.testing.expect(result.success);
    try std.testing.expect(std.mem.indexOf(u8, result.output, "[IMAGE:") != null);
    try std.testing.expect(std.mem.indexOf(u8, result.output, "screenshot.png") != null);
}

test "screenshot execute with custom filename" {
    const allocator = std.testing.allocator;
    var st = ScreenshotTool{ .workspace_dir = "/tmp" };
    const parsed = try root.parseTestArgs("{\"filename\":\"capture.png\"}");
    defer parsed.deinit();
    const result = try st.execute(allocator, parsed.value.object);
    defer allocator.free(result.output);
    try std.testing.expect(result.success);
    try std.testing.expect(std.mem.indexOf(u8, result.output, "capture.png") != null);
}
