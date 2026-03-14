const std = @import("std");
const common = @import("common.zig");

pub fn execute(
    allocator: std.mem.Allocator,
    query: []const u8,
    count: usize,
    timeout_secs: u64,
) (common.ProviderSearchError || error{OutOfMemory})!common.ToolResult {
    const encoded_query = try common.urlEncode(allocator, query);
    defer allocator.free(encoded_query);

    const url_str = try std.fmt.allocPrint(
        allocator,
        "https://api.duckduckgo.com/?q={s}&format=json&no_html=1&skip_disambig=1",
        .{encoded_query},
    );
    defer allocator.free(url_str);

    const timeout_str = try common.timeoutToString(allocator, timeout_secs);
    defer allocator.free(timeout_str);

    const headers = [_][]const u8{
        "Accept: application/json",
    };

    const body = common.curlGet(allocator, url_str, &headers, timeout_str) catch |err| {
        common.logRequestError("duckduckgo", query, err);
        return err;
    };
    defer allocator.free(body);

    const result = try formatResults(allocator, body, query, count);
    if (!result.success) return error.InvalidResponse;
    return result;
}

pub fn formatResults(allocator: std.mem.Allocator, json_body: []const u8, query: []const u8, count: usize) !common.ToolResult {
    const parsed = std.json.parseFromSlice(std.json.Value, allocator, json_body, .{}) catch
        return common.ToolResult.fail("Failed to parse search response JSON");
    defer parsed.deinit();

    const root_val = switch (parsed.value) {
        .object => |o| o,
        else => return common.ToolResult.fail("Unexpected search response format"),
    };

    const max_results = @min(count, 10);
    var entries: [10]common.ResultEntry = undefined;
    var entry_len: usize = 0;

    const heading = common.extractString(root_val, "Heading") orelse "";
    const abstract_text = common.extractString(root_val, "AbstractText") orelse "";
    const abstract_url = common.extractString(root_val, "AbstractURL") orelse "";

    if (abstract_url.len > 0 and abstract_text.len > 0 and entry_len < max_results) {
        const title = if (heading.len > 0) heading else common.duckduckgoTitleFromText(abstract_text);
        entries[entry_len] = .{
            .title = title,
            .url = abstract_url,
            .description = abstract_text,
        };
        entry_len += 1;
    }

    if (root_val.get("RelatedTopics")) |related_topics| {
        if (related_topics == .array) {
            collectTopics(related_topics.array.items, &entries, &entry_len, max_results);
        }
    }

    if (entry_len == 0) return common.ToolResult.ok("No web results found.");
    return common.formatResultEntries(allocator, query, entries[0..entry_len]);
}

fn collectTopics(
    topics: []const std.json.Value,
    entries: *[10]common.ResultEntry,
    entry_len: *usize,
    max_results: usize,
) void {
    for (topics) |topic| {
        if (entry_len.* >= max_results) return;

        const topic_obj = switch (topic) {
            .object => |o| o,
            else => continue,
        };

        const text = common.extractString(topic_obj, "Text");
        const first_url = common.extractString(topic_obj, "FirstURL");

        if (text != null and first_url != null and text.?.len > 0 and first_url.?.len > 0) {
            entries[entry_len.*] = .{
                .title = common.duckduckgoTitleFromText(text.?),
                .url = first_url.?,
                .description = text.?,
            };
            entry_len.* += 1;
            continue;
        }

        if (topic_obj.get("Topics")) |nested_topics| {
            if (nested_topics == .array) {
                collectTopics(nested_topics.array.items, entries, entry_len, max_results);
            }
        }
    }
}
