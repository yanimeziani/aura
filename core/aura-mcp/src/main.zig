//! Sovereign MCP server in Zig — Vinext-style: same capability as public MCPs, zero external runtime.
//! Full internal private platform: code, test, repeat in Zig only.
//! Transport: stdio, newline-delimited JSON (MCP).

const std = @import("std");
const canonical = @import("canonical.zig");

const ServerName = "aura-mcp";
const ServerVersion = "0.1.1";

fn writeResponse(allocator: std.mem.Allocator, file: std.fs.File, id: std.json.Value, result: anytype) !void {
    const s = try std.json.Stringify.valueAlloc(allocator, .{
        .jsonrpc = "2.0",
        .id = id,
        .result = result,
    }, .{});
    defer allocator.free(s);
    try file.writeAll(s);
    try file.writeAll("\n");
}

fn writeError(allocator: std.mem.Allocator, file: std.fs.File, id: std.json.Value, code: i64, message: []const u8) !void {
    const s = try std.json.Stringify.valueAlloc(allocator, .{
        .jsonrpc = "2.0",
        .id = id,
        .@"error" = .{
            .code = code,
            .message = message,
        },
    }, .{});
    defer allocator.free(s);
    try file.writeAll(s);
    try file.writeAll("\n");
}

fn getAllowedRoot(allocator: std.mem.Allocator) []const u8 {
    const root_opt = std.process.getEnvVarOwned(allocator, "AURA_ROOT") catch null;
    if (root_opt) |root| {
        return root; // Caller must free
    }
    return allocator.dupe(u8, ".") catch ".";
}

/// Resolve path: must be under allowed root (no escape).
fn resolvePath(allocator: std.mem.Allocator, root: []const u8, path: []const u8) ![]const u8 {
    const full_path = if (std.fs.path.isAbsolute(path))
        path
    else
        try std.fs.path.join(allocator, &.{ root, path });
    defer if (!std.fs.path.isAbsolute(path)) allocator.free(full_path);
    var buf: [std.fs.max_path_bytes]u8 = undefined;
    var root_buf: [std.fs.max_path_bytes]u8 = undefined;
    const resolved = try std.fs.realpath(full_path, &buf);
    const root_resolved = try std.fs.realpath(root, &root_buf);
    if (!std.mem.startsWith(u8, resolved, root_resolved)) {
        return error.PathNotAllowed;
    }
    return allocator.dupe(u8, resolved);
}

fn handleInitialize(allocator: std.mem.Allocator, file: std.fs.File, id: std.json.Value) !void {
    try writeResponse(allocator, file, id, .{
        .serverInfo = .{
            .name = ServerName,
            .version = ServerVersion,
        },
        .capabilities = .{
            .tools = .{},
        },
    });
}

fn handleToolsList(allocator: std.mem.Allocator, file: std.fs.File, id: std.json.Value) !void {
    try writeResponse(allocator, file, id, .{
        .tools = .{
            .{
                .name = "read_file",
                .description = "Read a file under AURA_ROOT. Sovereign Zig implementation; no external runtime.",
                .inputSchema = .{
                    .type = "object",
                    .properties = .{
                        .path = .{
                            .type = "string",
                            .description = "Path relative to AURA_ROOT or absolute under AURA_ROOT",
                        },
                    },
                    .required = .{"path"},
                },
            },
            .{
                .name = "list_dir",
                .description = "List directory under AURA_ROOT. Sovereign Zig implementation.",
                .inputSchema = .{
                    .type = "object",
                    .properties = .{
                        .path = .{
                            .type = "string",
                            .description = "Directory path relative to AURA_ROOT or absolute under AURA_ROOT",
                        },
                    },
                    .required = .{"path"},
                },
            },
            .{
                .name = "get_canonical_framework",
                .description = "FORCE ALIGNMENT: Returns the full content of all canonical documentation defined in the RAG manifest. Use this tool immediately to understand the project architecture, governance, and operating invariants.",
                .inputSchema = .{ .type = "object", .properties = .{}, .required = .{} },
            },
            .{
                .name = "ping",
                .description = "Liveness check; returns pong.",
                .inputSchema = .{ .type = "object", .properties = .{}, .required = .{} },
            },
        },
    });
}

fn handleToolsCall(allocator: std.mem.Allocator, file: std.fs.File, id: std.json.Value, name: []const u8, arguments: std.json.Value) !void {
    if (std.mem.eql(u8, name, "ping")) {
        try writeResponse(allocator, file, id, .{
            .content = .{
                .{ .type = "text", .text = "pong" },
            },
        });
        return;
    }

    const root = getAllowedRoot(allocator);
    defer allocator.free(root);

    if (std.mem.eql(u8, name, "get_canonical_framework")) {
        var fw = canonical.Framework.init(allocator);
        defer fw.deinit();
        try fw.loadFromManifest(root);
        
        var out: std.ArrayListUnmanaged(u8) = .empty;
        defer out.deinit(allocator);
        try fw.formatForAI(out.writer(allocator));
        
        try writeResponse(allocator, file, id, .{
            .content = .{
                .{
                    .type = "text",
                    .text = out.items,
                },
            },
        });
        return;
    }

    if (std.mem.eql(u8, name, "read_file")) {
        const path_val = (if (arguments == .object) arguments.object.get("path") else null) orelse {
            try writeError(allocator, file, id, -32602, "Missing argument: path");
            return;
        };
        const path = switch (path_val) {
            .string => |s| s,
            else => {
                try writeError(allocator, file, id, -32602, "path must be a string");
                return;
            },
        };
        const full = resolvePath(allocator, root, path) catch |e| {
            if (e == error.PathNotAllowed) {
                try writeError(allocator, file, id, -32602, "Path not under AURA_ROOT");
            } else {
                try writeError(allocator, file, id, -32603, "Resolve failed");
            }
            return;
        };
        defer allocator.free(full);
        const content = std.fs.cwd().readFileAlloc(allocator, full, 1024 * 1024) catch |err| {
            try writeError(allocator, file, id, -32603, std.fmt.allocPrint(allocator, "Read failed: {s}", .{@errorName(err)}) catch "Read failed");
            return;
        };
        defer allocator.free(content);
        try writeResponse(allocator, file, id, .{
            .content = .{
                .{
                    .type = "text",
                    .text = content,
                },
            },
        });
        return;
    }

    if (std.mem.eql(u8, name, "list_dir")) {
        const path_val = (if (arguments == .object) arguments.object.get("path") else null) orelse {
            try writeError(allocator, file, id, -32602, "Missing argument: path");
            return;
        };
        const path = switch (path_val) {
            .string => |s| s,
            else => {
                try writeError(allocator, file, id, -32602, "path must be a string");
                return;
            },
        };
        const full = resolvePath(allocator, root, path) catch |e| {
            if (e == error.PathNotAllowed) {
                try writeError(allocator, file, id, -32602, "Path not under AURA_ROOT");
            } else {
                try writeError(allocator, file, id, -32603, "Resolve failed");
            }
            return;
        };
        defer allocator.free(full);
        var dir = std.fs.openDirAbsolute(full, .{ .iterate = true }) catch |err| {
            try writeError(allocator, file, id, -32603, std.fmt.allocPrint(allocator, "Open dir failed: {s}", .{@errorName(err)}) catch "Open failed");
            return;
        };
        defer dir.close();
        var iter = dir.iterate();
        var out: std.ArrayListUnmanaged(u8) = .empty;
        defer out.deinit(allocator);
        try out.writer(allocator).print("{s}\n", .{full});
        while (iter.next() catch null) |entry| {
            const kind_char: []const u8 = if (entry.kind == .directory) "d" else " ";
            try out.writer(allocator).print("  {s}  {s}\n", .{ kind_char, entry.name });
        }
        try writeResponse(allocator, file, id, .{
            .content = .{
                .{
                    .type = "text",
                    .text = out.items,
                },
            },
        });
        return;
    }

    try writeError(allocator, file, id, -32601, "Unknown tool");
}

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    // Check for --framework flag to use as a standalone plugin/CLI
    var args = try std.process.argsWithAllocator(allocator);
    defer args.deinit();
    _ = args.next(); // skip exe name
    if (args.next()) |arg| {
        if (std.mem.eql(u8, arg, "--framework")) {
            const root = getAllowedRoot(allocator);
            defer allocator.free(root);
            var fw = canonical.Framework.init(allocator);
            defer fw.deinit();
            try fw.loadFromManifest(root);
            try fw.formatForAI(std.fs.File.stdout().deprecatedWriter());
            return;
        }
    }

    const stdin_file = std.fs.File.stdin();
    const stdout_file = std.fs.File.stdout();
    var line_buf: [1024 * 1024]u8 = undefined;

    while (true) {
        const line = stdin_file.deprecatedReader().readUntilDelimiter(line_buf[0..], '\n') catch |e| {
            if (e == error.EndOfStream) break;
            return e;
        };
        if (line.len == 0) break;

        var parsed = std.json.parseFromSlice(std.json.Value, allocator, line, .{}) catch {
            try writeError(allocator, stdout_file, std.json.Value{ .integer = 0 }, -32700, "Parse error");
            continue;
        };
        defer parsed.deinit();
        const root = parsed.value;

        if (root != .object) {
            try writeError(allocator, stdout_file, std.json.Value{ .integer = 0 }, -32600, "Root must be object");
            continue;
        }
        const method_val = root.object.get("method") orelse {
            const id = root.object.get("id") orelse std.json.Value{ .integer = 0 };
            try writeError(allocator, stdout_file, id, -32600, "Missing method");
            continue;
        };
        const method = switch (method_val) {
            .string => |s| s,
            else => {
                const id = root.object.get("id") orelse std.json.Value{ .integer = 0 };
                try writeError(allocator, stdout_file, id, -32600, "method must be string");
                continue;
            },
        };
        const id = root.object.get("id") orelse std.json.Value{ .integer = 0 };
        const params_val = root.object.get("params");
        const params = params_val orelse std.json.Value{ .object = std.json.ObjectMap.init(allocator) };

        if (std.mem.eql(u8, method, "initialize")) {
            try handleInitialize(allocator, stdout_file, id);
        } else if (std.mem.eql(u8, method, "tools/list")) {
            try handleToolsList(allocator, stdout_file, id);
        } else if (std.mem.eql(u8, method, "tools/call")) {
            const name_val = (if (params == .object) params.object.get("name") else null) orelse {
                try writeError(allocator, stdout_file, id, -32602, "Missing name");
                continue;
            };
            const name = switch (name_val) { .string => |s| s, else => "" };
            const args_val = if (params == .object) params.object.get("arguments") else null;
            const arguments = args_val orelse std.json.Value{ .object = std.json.ObjectMap.init(allocator) };
            try handleToolsCall(allocator, stdout_file, id, name, arguments);
        } else {
            try writeError(allocator, stdout_file, id, -32601, "Method not found");
        }
    }
}

test "allowed root" {
    const a = std.testing.allocator;
    const r = getAllowedRoot(a);
    defer a.free(r);
    try std.testing.expect(r.len > 0);
}
