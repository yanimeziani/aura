//! aura-flow — minimal ops automation webhook receiver (Zig).
//! Purpose: accept high-volume webhook fanout (e.g., Stripe events) and spool to disk fast.
//! This replaces "n8n sleeping" for the critical ingestion path.

const std = @import("std");
const net = std.net;

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const port_str = std.posix.getenv("AURA_FLOW_PORT") orelse "9100";
    const port = std.fmt.parseInt(u16, port_str, 10) catch 9100;
    const spool_dir = std.posix.getenv("AURA_FLOW_SPOOL_DIR") orelse "/home/yani/Aura/var/aura-flow/spool";
    const enable_worker = (std.posix.getenv("AURA_FLOW_WORKER") orelse "1");
    const payment_cmd = std.posix.getenv("AURA_FLOW_PAYMENT_CMD") orelse "/bin/bash /home/yani/Aura/ai_agency_wealth/automation_master.sh";
    const min_interval_str = std.posix.getenv("AURA_FLOW_PAYMENT_MIN_INTERVAL_SEC") orelse "300";
    const min_interval_sec = std.fmt.parseInt(i64, min_interval_str, 10) catch 300;

    try ensureDir(spool_dir);

    const address = try net.Address.parseIp("0.0.0.0", port);
    var server = try address.listen(.{ .reuse_address = true });
    defer server.deinit();

    std.debug.print("aura-flow listening on http://0.0.0.0:{}\n", .{port});
    std.debug.print("spool_dir: {s}\n", .{spool_dir});

    if (std.mem.eql(u8, enable_worker, "1") or std.mem.eql(u8, enable_worker, "true")) {
        const ctx = try allocator.create(WorkerCtx);
        ctx.* = .{
            .allocator = allocator,
            .spool_dir = try allocator.dupe(u8, spool_dir),
            .payment_cmd = try allocator.dupe(u8, payment_cmd),
            .payment_min_interval_sec = min_interval_sec,
        };
        _ = try std.Thread.spawn(.{}, workerMain, .{ctx});
        std.debug.print("worker: enabled\n", .{});
    } else {
        std.debug.print("worker: disabled\n", .{});
    }

    while (true) {
        const conn = try server.accept();
        handleConnection(allocator, conn, spool_dir) catch |err| {
            std.debug.print("Connection error: {}\n", .{err});
        };
    }
}

fn handleConnection(allocator: std.mem.Allocator, conn: net.Server.Connection, spool_dir: []const u8) !void {
    defer conn.stream.close();

    // Read request (best-effort, bounded).
    var buf: [1024 * 1024]u8 = undefined; // 1MiB cap per request
    const n = conn.stream.read(&buf) catch return;
    if (n == 0) return;
    const req = buf[0..n];

    const method = parseMethod(req);
    const path = parsePath(req);

    // Health endpoints (GET).
    if (std.mem.eql(u8, path, "/health") or std.mem.eql(u8, path, "/")) {
        if (!std.mem.eql(u8, method, "GET")) return writePlain(conn, 405, "Method Not Allowed");
        return writeJson(conn, 200, "{\"status\":\"ok\",\"service\":\"aura-flow\"}");
    }

    // Stripe-specific ingestion (POST).
    if (std.mem.eql(u8, path, "/ops/stripe")) {
        if (!std.mem.eql(u8, method, "POST")) return writePlain(conn, 405, "Method Not Allowed");
        const body = parseBody(req) orelse "";
        try spoolNdjson(allocator, spool_dir, "stripe.ndjson", body);
        return writeJson(conn, 200, "{\"status\":\"accepted\",\"source\":\"stripe\"}");
    }

    // Generic webhook ingestion (POST /ops/webhook or /ops/webhook/{source}).
    // Content-type routing: JSON → spool as-is with source tag;
    //   form-urlencoded → wrap as {raw:…,source:…}; other → same.
    if (std.mem.startsWith(u8, path, "/ops/webhook")) {
        if (!std.mem.eql(u8, method, "POST")) return writePlain(conn, 405, "Method Not Allowed");
        // Extract optional source from path: /ops/webhook/{source}
        const prefix = "/ops/webhook";
        const source: []const u8 = if (path.len > prefix.len + 1)
            path[prefix.len + 1 ..]
        else
            "generic";
        const body = parseBody(req) orelse "";
        const ct   = parseHeader(req, "Content-Type");
        try spoolWebhook(allocator, spool_dir, source, body, ct);
        var resp_buf: [128]u8 = undefined;
        const resp = try std.fmt.bufPrint(&resp_buf,
            \\{{"status":"accepted","source":"{s}"}}
        , .{source});
        return writeJson(conn, 200, resp);
    }

    return writePlain(conn, 404, "Not Found");
}

const WorkerCtx = struct {
    allocator: std.mem.Allocator,
    spool_dir: []u8,
    payment_cmd: []u8,
    payment_min_interval_sec: i64,
};

fn workerMain(ctx: *WorkerCtx) void {
    defer ctx.allocator.free(ctx.spool_dir);
    defer ctx.allocator.free(ctx.payment_cmd);
    defer ctx.allocator.destroy(ctx);

    const stripe_file = "stripe.ndjson";
    const offset_file = "stripe.offset";
    const state_file = "worker.state";

    while (true) {
        workerTick(ctx, stripe_file, offset_file, state_file) catch |err| {
            std.debug.print("worker error: {}\n", .{err});
        };
        std.Thread.sleep(500 * std.time.ns_per_ms);
    }
}

fn workerTick(ctx: *WorkerCtx, stripe_file: []const u8, offset_file: []const u8, state_file: []const u8) !void {
    var dir = try std.fs.openDirAbsolute(ctx.spool_dir, .{});
    defer dir.close();

    const offset = readOffset(dir, offset_file) catch 0;
    var file = dir.openFile(stripe_file, .{ .mode = .read_only }) catch |err| switch (err) {
        error.FileNotFound => return,
        else => return err,
    };
    defer file.close();

    const size = try file.getEndPos();
    if (offset >= size) return;
    try file.seekTo(offset);

    // Read the new chunk (bounded). If huge backlog, next tick will continue.
    const max_read: usize = 256 * 1024;
    const remaining = @min(max_read, @as(usize, @intCast(size - offset)));
    var buf = try ctx.allocator.alloc(u8, remaining);
    defer ctx.allocator.free(buf);

    const n = try file.readAll(buf);
    if (n == 0) return;
    const chunk = buf[0..n];

    var it = std.mem.splitScalar(u8, chunk, '\n');
    var consumed: u64 = 0;
    while (it.next()) |line_raw| {
        consumed += @as(u64, @intCast(line_raw.len)) + 1; // + '\n'
        const line = std.mem.trim(u8, line_raw, " \r\t");
        if (line.len == 0) continue;
        processStripeLine(ctx, dir, state_file, line) catch |err| {
            std.debug.print("worker: failed line: {} (len={})\n", .{ err, line.len });
        };
    }

    const new_offset = offset + @min(consumed, size - offset);
    try writeOffset(dir, offset_file, new_offset);
}

fn processStripeLine(ctx: *WorkerCtx, dir: std.fs.Dir, state_file: []const u8, line: []const u8) !void {
    var parsed = try std.json.parseFromSlice(std.json.Value, ctx.allocator, line, .{});
    defer parsed.deinit();

    const root = parsed.value;
    if (root != .object) return;
    const obj = root.object;

    const event_type = jsonString(obj.get("event_type"));
    const event_id = jsonString(obj.get("event_id"));
    if (event_type.len == 0 or event_id.len == 0) return;

    // Primary ops trigger: payment success.
    if (std.mem.eql(u8, event_type, "checkout.session.completed") or std.mem.eql(u8, event_type, "payment_intent.succeeded")) {
        try maybeRunPaymentAutomation(ctx, dir, state_file, event_id, event_type);
        return;
    }

    // Refund/dispute hooks can be expanded; for now we just keep ingestion durable.
    if (std.mem.eql(u8, event_type, "charge.refunded") or std.mem.eql(u8, event_type, "charge.refund.updated") or std.mem.eql(u8, event_type, "charge.dispute.created")) {
        std.debug.print("worker: ops noted {s} ({s})\n", .{ event_type, event_id });
        return;
    }
}

fn jsonString(v_opt: ?std.json.Value) []const u8 {
    if (v_opt) |v| {
        if (v == .string) return v.string;
    }
    return "";
}

fn maybeRunPaymentAutomation(ctx: *WorkerCtx, dir: std.fs.Dir, state_file: []const u8, event_id: []const u8, event_type: []const u8) !void {
    const now = std.time.timestamp();
    const last = readLastRun(dir, state_file) catch 0;
    if ((now - last) < ctx.payment_min_interval_sec) {
        std.debug.print("worker: payment automation rate-limited (event={s}, type={s})\n", .{ event_id, event_type });
        return;
    }

    // Fire-and-forget: run the configured payment automation command.
    // This is safe under retries because upstream already dedupes and downstream work should be idempotent.
    var argv = [_][]const u8{ "/bin/sh", "-lc", ctx.payment_cmd };
    var child = std.process.Child.init(&argv, ctx.allocator);
    child.stdout_behavior = .Ignore;
    child.stderr_behavior = .Ignore;
    _ = child.spawn() catch |err| {
        std.debug.print("worker: failed spawning payment cmd: {}\n", .{err});
        return;
    };

    try writeLastRun(dir, state_file, now);
    std.debug.print("worker: payment automation started (event={s}, type={s})\n", .{ event_id, event_type });
}

fn readOffset(dir: std.fs.Dir, filename: []const u8) !u64 {
    var f = try dir.openFile(filename, .{ .mode = .read_only });
    defer f.close();
    var buf: [64]u8 = undefined;
    const n = try f.readAll(&buf);
    const s = std.mem.trim(u8, buf[0..n], " \r\n\t");
    if (s.len == 0) return 0;
    return std.fmt.parseInt(u64, s, 10);
}

fn writeOffset(dir: std.fs.Dir, filename: []const u8, off: u64) !void {
    var f = try dir.createFile(filename, .{ .truncate = true });
    defer f.close();
    var buf: [64]u8 = undefined;
    const s = try std.fmt.bufPrint(&buf, "{d}\n", .{off});
    try f.writeAll(s);
}

fn readLastRun(dir: std.fs.Dir, filename: []const u8) !i64 {
    var f = try dir.openFile(filename, .{ .mode = .read_only });
    defer f.close();
    var buf: [64]u8 = undefined;
    const n = try f.readAll(&buf);
    const s = std.mem.trim(u8, buf[0..n], " \r\n\t");
    if (s.len == 0) return 0;
    return std.fmt.parseInt(i64, s, 10);
}

fn writeLastRun(dir: std.fs.Dir, filename: []const u8, ts: i64) !void {
    var f = try dir.createFile(filename, .{ .truncate = true });
    defer f.close();
    var buf: [64]u8 = undefined;
    const s = try std.fmt.bufPrint(&buf, "{d}\n", .{ts});
    try f.writeAll(s);
}

/// Extract a header value from a raw HTTP request (case-sensitive key match).
fn parseHeader(request: []const u8, header_name: []const u8) []const u8 {
    var lines = std.mem.splitScalar(u8, request, '\n');
    _ = lines.next(); // skip request line
    while (lines.next()) |line| {
        const l = std.mem.trimRight(u8, line, "\r");
        if (l.len == 0) break; // end of headers
        const colon = std.mem.indexOfScalar(u8, l, ':') orelse continue;
        const name = std.mem.trim(u8, l[0..colon], " ");
        if (std.ascii.eqlIgnoreCase(name, header_name)) {
            return std.mem.trim(u8, l[colon + 1 ..], " \t");
        }
    }
    return "";
}

/// Spool a generic webhook body as a tagged NDJSON record.
/// Wraps with {"_source":"…","_ct":"…",…body fields or "raw":…}.
fn spoolWebhook(allocator: std.mem.Allocator, dir_path: []const u8, source: []const u8, body: []const u8, content_type: []const u8) !void {
    const trimmed = std.mem.trimRight(u8, body, "\r\n");
    const is_json = std.mem.startsWith(u8, std.mem.trimLeft(u8, trimmed, " \t"), "{") or
                    std.mem.startsWith(u8, std.mem.trimLeft(u8, trimmed, " \t"), "[");

    // Build filename: webhooks-{source}.ndjson
    var fname_buf: [128]u8 = undefined;
    const fname = try std.fmt.bufPrint(&fname_buf, "webhook-{s}.ndjson", .{source});

    var dir = try std.fs.openDirAbsolute(dir_path, .{});
    defer dir.close();

    var file = dir.openFile(fname, .{ .mode = .write_only }) catch |err| switch (err) {
        error.FileNotFound => try dir.createFile(fname, .{ .truncate = false }),
        else => return err,
    };
    defer file.close();
    try file.seekFromEnd(0);

    if (is_json and trimmed.len > 2) {
        // Inject _source and _ct into the JSON object.
        // Strategy: strip trailing }, append our fields, close.
        const obj = std.mem.trimRight(u8, trimmed, "} \t\r\n");
        const needs_comma = obj.len > 1 and obj[obj.len - 1] != '{';
        try file.writeAll(obj);
        if (needs_comma) try file.writeAll(",");
        var tag_buf: [256]u8 = undefined;
        const tag = try std.fmt.bufPrint(&tag_buf,
            \\"_source":"{s}","_ct":"{s}"}}
        , .{ source, content_type });
        try file.writeAll(tag);
        try file.writeAll("\n");
    } else {
        // Non-JSON: wrap entirely.
        _ = allocator;
        try file.writeAll("{\"_source\":\"");
        try file.writeAll(source);
        try file.writeAll("\",\"raw\":\"");
        for (trimmed) |c| {
            switch (c) {
                '\\' => try file.writeAll("\\\\"),
                '"'  => try file.writeAll("\\\""),
                '\n' => try file.writeAll("\\n"),
                '\r' => try file.writeAll("\\r"),
                '\t' => try file.writeAll("\\t"),
                else => { var one: [1]u8 = .{c}; try file.writeAll(&one); },
            }
        }
        try file.writeAll("\"}\n");
    }
}

fn spoolNdjson(allocator: std.mem.Allocator, dir_path: []const u8, filename: []const u8, line: []const u8) !void {
    var dir = try std.fs.openDirAbsolute(dir_path, .{});
    defer dir.close();

    var file = dir.openFile(filename, .{ .mode = .write_only }) catch |err| switch (err) {
        error.FileNotFound => try dir.createFile(filename, .{ .truncate = false }),
        else => return err,
    };
    defer file.close();
    try file.seekFromEnd(0);

    // Ensure each record is a single line.
    const trimmed = std.mem.trimRight(u8, line, "\r\n");
    if (trimmed.len == 0) {
        // Still record the event, but as empty object for traceability.
        try file.writeAll("{}\n");
        return;
    }

    // If body is JSON, append directly; otherwise, wrap as {"raw": "..."}.
    const first = trimmed[0];
    if (first == '{' or first == '[') {
        try file.writeAll(trimmed);
        try file.writeAll("\n");
        return;
    }

    _ = allocator; // keep signature stable; no allocations needed for escaping
    try file.writeAll("{\"raw\":\"");
    for (trimmed) |c| {
        switch (c) {
            '\\' => try file.writeAll("\\\\"),
            '"' => try file.writeAll("\\\""),
            '\n' => try file.writeAll("\\n"),
            '\r' => try file.writeAll("\\r"),
            '\t' => try file.writeAll("\\t"),
            else => {
                var one: [1]u8 = .{c};
                try file.writeAll(&one);
            },
        }
    }
    try file.writeAll("\"}\n");
}

fn ensureDir(path: []const u8) !void {
    // Recursive mkdir -p for absolute paths.
    if (path.len == 0) return;
    if (path[0] != '/') return error.InvalidArgument;

    var buf: [std.fs.max_path_bytes]u8 = undefined;
    var fbs = std.io.fixedBufferStream(&buf);
    const w = fbs.writer();

    // Start at root.
    try w.writeByte('/');
    var it = std.mem.splitScalar(u8, path[1..], '/');
    while (it.next()) |part| {
        if (part.len == 0) continue;
        if (fbs.pos > 1) try w.writeByte('/');
        try w.writeAll(part);
        const cur = fbs.getWritten();
        std.fs.makeDirAbsolute(cur) catch |err| switch (err) {
            error.PathAlreadyExists => {},
            else => return err,
        };
    }
}

fn parseMethod(request: []const u8) []const u8 {
    const space1 = std.mem.indexOfScalar(u8, request, ' ') orelse return "GET";
    return request[0..space1];
}

fn parsePath(request: []const u8) []const u8 {
    const space1 = std.mem.indexOfScalar(u8, request, ' ') orelse return "/";
    var rest = request[space1 + 1 ..];
    const space2 = std.mem.indexOfScalar(u8, rest, ' ') orelse return "/";
    const path = rest[0..space2];
    const q = std.mem.indexOfScalar(u8, path, '?');
    return if (q) |i| path[0..i] else path;
}

fn parseBody(request: []const u8) ?[]const u8 {
    const sep = "\r\n\r\n";
    const idx = std.mem.indexOf(u8, request, sep) orelse return null;
    return request[idx + sep.len ..];
}

fn writePlain(conn: net.Server.Connection, status: u16, body: []const u8) !void {
    const status_text = switch (status) {
        200 => "200 OK",
        404 => "404 Not Found",
        405 => "405 Method Not Allowed",
        else => "500 Internal Server Error",
    };
    var header_buf: [256]u8 = undefined;
    const hdr = try std.fmt.bufPrint(
        &header_buf,
        "HTTP/1.1 {s}\r\nContent-Type: text/plain\r\nConnection: close\r\nContent-Length: {}\r\n\r\n",
        .{ status_text, body.len },
    );
    _ = try conn.stream.write(hdr);
    _ = try conn.stream.write(body);
}

fn writeJson(conn: net.Server.Connection, status: u16, body: []const u8) !void {
    const status_text = switch (status) {
        200 => "200 OK",
        404 => "404 Not Found",
        405 => "405 Method Not Allowed",
        else => "500 Internal Server Error",
    };
    var header_buf: [256]u8 = undefined;
    const hdr = try std.fmt.bufPrint(
        &header_buf,
        "HTTP/1.1 {s}\r\nContent-Type: application/json\r\nConnection: close\r\nContent-Length: {}\r\n\r\n",
        .{ status_text, body.len },
    );
    _ = try conn.stream.write(hdr);
    _ = try conn.stream.write(body);
}

