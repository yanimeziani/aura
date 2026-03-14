const std = @import("std");
const common = @import("common.zig");

pub fn execute(
    allocator: std.mem.Allocator,
    query: []const u8,
    count: usize,
    api_key: []const u8,
    timeout_secs: u64,
) (common.ProviderSearchError || error{OutOfMemory})!common.ToolResult {
    const timeout_str = try common.timeoutToString(allocator, timeout_secs);
    defer allocator.free(timeout_str);

    const endpoint = "https://api.exa.ai/search";
    const key_header = try std.fmt.allocPrint(allocator, "x-api-key: {s}", .{api_key});
    defer allocator.free(key_header);

    const payload = .{
        .query = query,
        .numResults = count,
    };
    const body_json = try std.json.Stringify.valueAlloc(allocator, payload, .{});
    defer allocator.free(body_json);

    const headers = [_][]const u8{
        key_header,
        "Content-Type: application/json",
        "Accept: application/json",
    };

    const body = common.curlPostJson(allocator, endpoint, body_json, &headers, timeout_str) catch |err| {
        common.logRequestError("exa", query, err);
        return err;
    };
    defer allocator.free(body);

    const parsed = std.json.parseFromSlice(std.json.Value, allocator, body, .{}) catch return error.InvalidResponse;
    defer parsed.deinit();

    const root_val = switch (parsed.value) {
        .object => |o| o,
        else => return error.InvalidResponse,
    };

    const results = root_val.get("results") orelse return error.InvalidResponse;
    const results_arr = switch (results) {
        .array => |a| a,
        else => return error.InvalidResponse,
    };

    if (results_arr.items.len == 0) return common.ToolResult.ok("No web results found.");
    return common.formatResultsArray(allocator, results_arr.items, query, "summary", "text");
}
