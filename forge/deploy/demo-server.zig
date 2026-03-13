const std = @import("std");

/// Forge Demo Server — Simple web playground
/// Serves static HTML + handles /run endpoint for sandbox execution
const LISTEN_PORT = 3000;

pub fn main() !void {
    const stdout = std.io.getStdOut().writer();
    try stdout.print("Forge Demo Server starting on port {d}...\n", .{LISTEN_PORT});

    const address = std.net.Address.parseIp4("0.0.0.0", LISTEN_PORT) catch unreachable;
    var server = try address.listen(.{ .reuse_address = true });
    defer server.deinit();

    try stdout.print("Listening on http://127.0.0.1:{d}\n", .{LISTEN_PORT});

    while (true) {
        const conn = server.accept() catch |err| {
            try stdout.print("Accept error: {}\n", .{err});
            continue;
        };
        handleConnection(conn) catch |err| {
            try stdout.print("Handler error: {}\n", .{err});
        };
    }
}

fn handleConnection(conn: std.net.Server.Connection) !void {
    defer conn.stream.close();

    var buf: [8192]u8 = undefined;
    const n = try conn.stream.read(&buf);
    if (n == 0) return;

    const request = buf[0..n];

    if (std.mem.startsWith(u8, request, "GET / ") or std.mem.startsWith(u8, request, "GET /index")) {
        try sendHtml(conn.stream, INDEX_HTML);
    } else if (std.mem.startsWith(u8, request, "POST /run")) {
        try handleRun(conn.stream, request);
    } else if (std.mem.startsWith(u8, request, "GET /health")) {
        try sendJson(conn.stream, "200 OK", "{\"status\":\"ok\"}");
    } else {
        try sendJson(conn.stream, "404 Not Found", "{\"error\":\"not found\"}");
    }
}

fn handleRun(stream: std.net.Stream, request: []const u8) !void {
    // Find body after \r\n\r\n
    const body_start = std.mem.indexOf(u8, request, "\r\n\r\n");
    if (body_start == null) {
        try sendJson(stream, "400 Bad Request", "{\"error\":\"no body\"}");
        return;
    }

    const code = request[body_start.? + 4 ..];

    // Run through sandbox (exec forge-sandbox)
    var child = std.process.Child.init(&[_][]const u8{"/usr/local/bin/forge-sandbox"}, std.heap.page_allocator);
    child.stdin_behavior = .Pipe;
    child.stdout_behavior = .Pipe;
    child.stderr_behavior = .Pipe;

    try child.spawn();

    if (child.stdin) |stdin| {
        try stdin.writeAll(code);
        stdin.close();
        child.stdin = null;
    }

    const result = try child.wait();
    _ = result;

    var output_buf: [4096]u8 = undefined;
    const output_len = child.stdout.?.readAll(&output_buf) catch 0;
    const output = output_buf[0..output_len];

    // Escape for JSON
    var json_buf: [8192]u8 = undefined;
    const json = std.fmt.bufPrint(&json_buf, "{{\"output\":\"{s}\"}}", .{output}) catch "{\"output\":\"error\"}";

    try sendJson(stream, "200 OK", json);
}

fn sendJson(stream: std.net.Stream, status: []const u8, body: []const u8) !void {
    var writer = stream.writer();
    try writer.print("HTTP/1.1 {s}\r\n", .{status});
    try writer.print("Content-Type: application/json\r\n", .{});
    try writer.print("Content-Length: {d}\r\n", .{body.len});
    try writer.print("Connection: close\r\n\r\n", .{});
    try writer.writeAll(body);
}

fn sendHtml(stream: std.net.Stream, body: []const u8) !void {
    var writer = stream.writer();
    try writer.print("HTTP/1.1 200 OK\r\n", .{});
    try writer.print("Content-Type: text/html; charset=utf-8\r\n", .{});
    try writer.print("Content-Length: {d}\r\n", .{body.len});
    try writer.print("Connection: close\r\n\r\n", .{});
    try writer.writeAll(body);
}

const INDEX_HTML =
    \\<!DOCTYPE html>
    \\<html lang="en">
    \\<head>
    \\  <meta charset="UTF-8">
    \\  <meta name="viewport" content="width=device-width, initial-scale=1.0">
    \\  <title>Forge Playground</title>
    \\  <style>
    \\    * { box-sizing: border-box; margin: 0; padding: 0; }
    \\    body { font-family: system-ui, sans-serif; background: #0a0a0a; color: #e0e0e0; min-height: 100vh; padding: 2rem; }
    \\    .container { max-width: 1000px; margin: 0 auto; }
    \\    h1 { color: #f97316; margin-bottom: 0.5rem; }
    \\    .subtitle { color: #888; margin-bottom: 2rem; }
    \\    .editor { display: grid; grid-template-columns: 1fr 1fr; gap: 1rem; }
    \\    textarea, pre { background: #1a1a1a; border: 1px solid #333; border-radius: 8px; padding: 1rem; font-family: monospace; font-size: 14px; min-height: 400px; resize: vertical; }
    \\    textarea { color: #e0e0e0; width: 100%; }
    \\    pre { color: #22c55e; overflow: auto; }
    \\    button { background: #f97316; color: #000; border: none; padding: 0.75rem 2rem; border-radius: 6px; font-weight: bold; cursor: pointer; margin-top: 1rem; }
    \\    button:hover { background: #ea580c; }
    \\    .info { margin-top: 2rem; padding: 1rem; background: #1a1a1a; border-radius: 8px; border-left: 4px solid #f97316; }
    \\    @media (max-width: 768px) { .editor { grid-template-columns: 1fr; } }
    \\  </style>
    \\</head>
    \\<body>
    \\  <div class="container">
    \\    <h1>Forge Playground</h1>
    \\    <p class="subtitle">Systems language with Aura memory regions</p>
    \\    <div class="editor">
    \\      <div>
    \\        <textarea id="code" placeholder="// Write Forge code here...
    \\fn main() void {
    \\    // Your code
    \\}"></textarea>
    \\        <button onclick="run()">Run</button>
    \\      </div>
    \\      <pre id="output">// Output will appear here...</pre>
    \\    </div>
    \\    <div class="info">
    \\      <strong>Aura System:</strong> Tag memory regions with lifetime info at compile time. Zero runtime cost.
    \\    </div>
    \\  </div>
    \\  <script>
    \\    async function run() {
    \\      const code = document.getElementById('code').value;
    \\      const output = document.getElementById('output');
    \\      output.textContent = 'Running...';
    \\      try {
    \\        const res = await fetch('/run', { method: 'POST', body: code });
    \\        const data = await res.json();
    \\        output.textContent = data.output || data.error || 'No output';
    \\      } catch (e) {
    \\        output.textContent = 'Error: ' + e.message;
    \\      }
    \\    }
    \\  </script>
    \\</body>
    \\</html>
;
