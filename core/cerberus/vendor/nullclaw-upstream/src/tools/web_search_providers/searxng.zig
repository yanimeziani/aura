const std = @import("std");
const common = @import("common.zig");

pub fn execute(
    allocator: std.mem.Allocator,
    query: []const u8,
    count: usize,
    base_url: []const u8,
    timeout_secs: u64,
) (common.ProviderSearchError || error{OutOfMemory})!common.ToolResult {
    const encoded_query = try common.urlEncode(allocator, query);
    defer allocator.free(encoded_query);

    const url_str = common.buildSearxngSearchUrl(allocator, base_url, encoded_query, count) catch |err| switch (err) {
        error.InvalidSearchBaseUrl => return error.InvalidSearchBaseUrl,
        else => return err,
    };
    defer allocator.free(url_str);

    const timeout_str = try common.timeoutToString(allocator, timeout_secs);
    defer allocator.free(timeout_str);

    const headers = [_][]const u8{
        "Accept: application/json",
        "User-Agent: nullclaw/0.1 (web_search)",
    };

    const body = common.curlGet(allocator, url_str, &headers, timeout_str) catch |err| {
        common.logRequestError("searxng", query, err);
        return err;
    };
    defer allocator.free(body);

    const result = try formatResults(allocator, body, query);
    if (!result.success) return error.InvalidResponse;
    return result;
}

pub fn formatResults(allocator: std.mem.Allocator, json_body: []const u8, query: []const u8) !common.ToolResult {
    const parsed = std.json.parseFromSlice(std.json.Value, allocator, json_body, .{}) catch
        return common.ToolResult.fail("Failed to parse search response JSON");
    defer parsed.deinit();

    const root_val = switch (parsed.value) {
        .object => |o| o,
        else => return common.ToolResult.fail("Unexpected search response format"),
    };

    const results = root_val.get("results") orelse
        return common.ToolResult.ok("No web results found.");

    const results_arr = switch (results) {
        .array => |a| a,
        else => return common.ToolResult.ok("No web results found."),
    };

    if (results_arr.items.len == 0)
        return common.ToolResult.ok("No web results found.");

    return common.formatResultsArray(allocator, results_arr.items, query, "content", null);
}
