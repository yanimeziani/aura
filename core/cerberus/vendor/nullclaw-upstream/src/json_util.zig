//! Shared JSON string utilities (RFC 8259).
//!
//! Replaces 10+ local `appendJsonString` duplicates across the codebase.

const std = @import("std");
const Allocator = std.mem.Allocator;

/// Append a JSON-escaped string (with enclosing quotes) to the buffer.
/// Handles: `"`, `\`, `\n`, `\r`, `\t`, control chars < 0x20 → `\u00XX`.
pub fn appendJsonString(buf: *std.ArrayListUnmanaged(u8), allocator: Allocator, s: []const u8) !void {
    try buf.append(allocator, '"');
    for (s) |c| {
        switch (c) {
            '"' => try buf.appendSlice(allocator, "\\\""),
            '\\' => try buf.appendSlice(allocator, "\\\\"),
            '\n' => try buf.appendSlice(allocator, "\\n"),
            '\r' => try buf.appendSlice(allocator, "\\r"),
            '\t' => try buf.appendSlice(allocator, "\\t"),
            else => {
                if (c < 0x20) {
                    var escape_buf: [6]u8 = undefined;
                    const escape = std.fmt.bufPrint(&escape_buf, "\\u{x:0>4}", .{c}) catch unreachable;
                    try buf.appendSlice(allocator, escape);
                } else {
                    try buf.append(allocator, c);
                }
            },
        }
    }
    try buf.append(allocator, '"');
}

/// Append `"key":` (JSON-escaped key with colon) to the buffer.
pub fn appendJsonKey(buf: *std.ArrayListUnmanaged(u8), allocator: Allocator, key: []const u8) !void {
    try appendJsonString(buf, allocator, key);
    try buf.append(allocator, ':');
}

/// Append `"key":"value"` (both JSON-escaped) to the buffer.
pub fn appendJsonKeyValue(buf: *std.ArrayListUnmanaged(u8), allocator: Allocator, key: []const u8, value: []const u8) !void {
    try appendJsonKey(buf, allocator, key);
    try appendJsonString(buf, allocator, value);
}

/// Append `"key":123` (JSON-escaped key, integer value) to the buffer.
pub fn appendJsonInt(buf: *std.ArrayListUnmanaged(u8), allocator: Allocator, key: []const u8, value: i64) !void {
    try appendJsonKey(buf, allocator, key);
    var int_buf: [24]u8 = undefined;
    const int_str = std.fmt.bufPrint(&int_buf, "{d}", .{value}) catch unreachable;
    try buf.appendSlice(allocator, int_str);
}

// ── Tests ───────────────────────────────────────────────────────────

test "appendJsonString empty string" {
    var buf: std.ArrayListUnmanaged(u8) = .empty;
    defer buf.deinit(std.testing.allocator);
    try appendJsonString(&buf, std.testing.allocator, "");
    try std.testing.expectEqualStrings("\"\"", buf.items);
}

test "appendJsonString plain ASCII" {
    var buf: std.ArrayListUnmanaged(u8) = .empty;
    defer buf.deinit(std.testing.allocator);
    try appendJsonString(&buf, std.testing.allocator, "hello world");
    try std.testing.expectEqualStrings("\"hello world\"", buf.items);
}

test "appendJsonString escapes quotes" {
    var buf: std.ArrayListUnmanaged(u8) = .empty;
    defer buf.deinit(std.testing.allocator);
    try appendJsonString(&buf, std.testing.allocator, "say \"hi\"");
    try std.testing.expectEqualStrings("\"say \\\"hi\\\"\"", buf.items);
}

test "appendJsonString escapes backslash" {
    var buf: std.ArrayListUnmanaged(u8) = .empty;
    defer buf.deinit(std.testing.allocator);
    try appendJsonString(&buf, std.testing.allocator, "a\\b");
    try std.testing.expectEqualStrings("\"a\\\\b\"", buf.items);
}

test "appendJsonString escapes tabs and newlines" {
    var buf: std.ArrayListUnmanaged(u8) = .empty;
    defer buf.deinit(std.testing.allocator);
    try appendJsonString(&buf, std.testing.allocator, "a\tb\nc\r");
    try std.testing.expectEqualStrings("\"a\\tb\\nc\\r\"", buf.items);
}

test "appendJsonString escapes control chars" {
    var buf: std.ArrayListUnmanaged(u8) = .empty;
    defer buf.deinit(std.testing.allocator);
    try appendJsonString(&buf, std.testing.allocator, &[_]u8{0x01});
    try std.testing.expectEqualStrings("\"\\u0001\"", buf.items);
}

test "appendJsonString preserves Unicode" {
    var buf: std.ArrayListUnmanaged(u8) = .empty;
    defer buf.deinit(std.testing.allocator);
    try appendJsonString(&buf, std.testing.allocator, "Héllo 🌍");
    try std.testing.expectEqualStrings("\"Héllo 🌍\"", buf.items);
}

test "appendJsonKeyValue" {
    var buf: std.ArrayListUnmanaged(u8) = .empty;
    defer buf.deinit(std.testing.allocator);
    try appendJsonKeyValue(&buf, std.testing.allocator, "name", "Alice \"A\"");
    try std.testing.expectEqualStrings("\"name\":\"Alice \\\"A\\\"\"", buf.items);
}

test "appendJsonInt" {
    var buf: std.ArrayListUnmanaged(u8) = .empty;
    defer buf.deinit(std.testing.allocator);
    try appendJsonInt(&buf, std.testing.allocator, "count", 42);
    try std.testing.expectEqualStrings("\"count\":42", buf.items);
}

test "appendJsonInt negative" {
    var buf: std.ArrayListUnmanaged(u8) = .empty;
    defer buf.deinit(std.testing.allocator);
    try appendJsonInt(&buf, std.testing.allocator, "delta", -7);
    try std.testing.expectEqualStrings("\"delta\":-7", buf.items);
}
