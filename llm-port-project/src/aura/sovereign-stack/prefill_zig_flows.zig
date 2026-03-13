// Prefill Zig flows for n8n integration
const std = @import("std");
const log = std.log.info;

const api_key = std.process.getEnv("N8N_API_KEY").?;
const base_url = std.process.getEnv("N8N_BASE_URL").?;

pub fn main() void {
    const flows = findDefaultFlows();
    for (flows) |flow_path| {
        upsertWorkflow(flow_path) catch |err| {
            log.err("Failed to process {s}: {any}", .{ flow_path, err });
            return err;
        };
    }
}

fn findDefaultFlows() []const []const u8 {
    return &[_][]const u8 {
        "./ai_agency_wealth/n8n_micro_saas_fulfillment.json",
        "./vault/n8n_zero_inbox_blueprint.json",
    };
}

fn normalizeWorkflow(allowlist: []const []const u8, workflow: std.json.Value) !std.json.Value {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();

    var filtered = std.json.Object{
        .allocator = arena.allocator(),
    };

    for (allowlist) |key| {
        if (workflow.object.get(key)) |value| {
            try filtered.put(key, value);
        }
    }

    try filtered.put("active", std.json.Value{ .bool = false });

    if (filtered.get("settings") == null) {
        try filtered.put("settings", std.json.Value{ .empty_object = {} });
    }

    return filtered;
}

fn makeRequest(allocator: *std.mem.Allocator, method: []const u8, endpoint: []const u8, body: ?[]const u8) !std.json.Value {
    var resolver = try std.http.Resolver.init(.{ .allocator = allocator });
    defer resolver.deinit();

    var transport = try std.http.Transport.init(.{ .allocator = allocator });
    defer transport.deinit();

    var client = std.http.Client.init(&resolver, &transport, allocator);
    defer client.deinit();

    try client.open();

    const full_url = try std.fmt.allocPrint(allocator, "{s}{s}", .{ base_url, endpoint });
    defer allocator.free(full_url);

    var req = try client.request(.{ .method = method, .uri = full_url }, body);

    try req.headers.set("X-N8N-API-KEY", api_key);
    try req.headers.set("Content-Type", "application/json");
    
    try req.send();

    if (req.getResponseCode() != 200) {
        return error.ApiError;
    }


    const response = req.readBody(allocator) catch unreachable;
    defer allocator.free(response);

    return std.json.parse(response, .{}, allocator) catch unreachable;
}


fn upsertWorkflow(flow_path: []const u8) !void {
    const file = try std.fs.openReadOnlyFile(flow_path);
    defer file.close();

    const content = try file.readToEndAlloc(std.heap.page_allocator, std.math.maxInt(usize));
    defer std.heap.page_allocator.free(content);

    const workflow = try std.json.parseFromStringAlloc(
        std.json.Parser,
        content,
        .{},
        std.heap.page_allocator
    );

    const normalized = try normalizeWorkflow(
        &.{ "name", "nodes", "connections", "settings", "staticData", "pinData", "meta", "active" },
        workflow
    );


    const workflows = try makeRequest(std.heap.page_allocator, "GET", "/api/v1/workflows?limit=100", null);
    var workflow_exists: ?[]const u8 = null;

    if (workflows.object) |data| {
        const items = data.get("data") orelse return;
        if (items.array) |list| {
            for (list) |item| {
                if (item.object) |obj| {
                    if (obj.get("name") == normalized.object.get("name")) |match| {
                        workflow_exists = match.string orelse continue;
                    }
                }
            }
        }
    }

    if (workflow_exists) {
        const workflow_id = try makeRequest(std.heap.page_allocator, "PATCH", "/api/v1/workflows/", &.{
            .{ "workflow" = normalized },
        });
    } else {
        const workflow_id = try makeRequest(std.heap.page_allocator, "POST", "/api/v1/workflows", &.{
            .{ "workflow" = normalized },
        });
    }

    log("Processed: {s}", .{ workflow_path });
}
