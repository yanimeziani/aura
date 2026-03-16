const std = @import("std");
const net = std.net;

const html =
    \\<!doctype html>
    \\<html lang="en">
    \\<head>
    \\  <meta charset="utf-8" />
    \\  <meta name="viewport" content="width=device-width, initial-scale=1" />
    \\  <title>Nexa Lite</title>
    \\  <link rel="stylesheet" href="/assets/design-system.css" />
    \\</head>
    \\<body>
    \\  <div id="app"></div>
    \\  <script src="/assets/main.js"></script>
    \\</body>
    \\</html>
;

const css = @embedFile("design-system.css");
const js = @embedFile("main.js");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();

    const port_text = std.posix.getenv("NEXA_GATEWAY_PORT") orelse "9080";
    const port = std.fmt.parseInt(u16, port_text, 10) catch 9080;
    const address = try net.Address.parseIp("0.0.0.0", port);
    var server = try address.listen(.{ .reuse_address = true });
    defer server.deinit();

    std.debug.print("nexa-gateway listening on http://0.0.0.0:{d}\n", .{port});

    while (true) {
        const conn = try server.accept();
        handleConnection(conn) catch |err| {
            std.debug.print("nexa-gateway connection error: {}\n", .{err});
        };
    }
}

fn handleConnection(conn: net.Server.Connection) !void {
    defer conn.stream.close();

    var buf: [8192]u8 = undefined;
    const n = conn.stream.read(&buf) catch return;
    if (n == 0) return;

    const request = buf[0..n];
    const method = parseMethod(request);
    const path = parsePath(request);

    if (std.mem.eql(u8, method, "GET") and std.mem.eql(u8, path, "/")) {
        return writeResponse(conn, 200, "text/html; charset=utf-8", html);
    }
    if (std.mem.eql(u8, method, "GET") and std.mem.eql(u8, path, "/assets/design-system.css")) {
        return writeResponse(conn, 200, "text/css; charset=utf-8", css);
    }
    if (std.mem.eql(u8, method, "GET") and std.mem.eql(u8, path, "/assets/main.js")) {
        return writeResponse(conn, 200, "application/javascript; charset=utf-8", js);
    }
    if (std.mem.eql(u8, method, "GET") and std.mem.eql(u8, path, "/api/health")) {
        return writeResponse(conn, 200, "application/json; charset=utf-8",
            \\{"status":"ok","service":"nexa-gateway","zig":"0.15.2","surface":"minimal"}
        );
    }
    if (std.mem.eql(u8, method, "GET") and std.mem.eql(u8, path, "/api/routes")) {
        return writeResponse(conn, 200, "application/json; charset=utf-8",
            \\{"routes":["/","/api/health","/api/routes","/api/status","/health/services","/providers","/v1/models","/telemetry/regions","/assets/design-system.css","/assets/main.js"]}
        );
    }
    if (std.mem.eql(u8, method, "GET") and std.mem.eql(u8, path, "/api/status")) {
        return writeResponse(conn, 200, "application/json; charset=utf-8",
            \\{"control_plane":"standby","mesh":"isolated","frontend":"nexa-lite","risk_mode":"supply-chain-reduced"}
        );
    }
    if (std.mem.eql(u8, method, "GET") and std.mem.eql(u8, path, "/health/services")) {
        return writeResponse(conn, 200, "application/json; charset=utf-8",
            \\{"services":[{"name":"Nexa Gateway","port":9080,"status":"online"},{"name":"Cerberus","port":3000,"status":"offline"},{"name":"Ollama","port":11434,"status":"offline"},{"name":"Mesh Control","port":9443,"status":"standby"}]}
        );
    }
    if (std.mem.eql(u8, method, "GET") and std.mem.eql(u8, path, "/providers")) {
        return writeResponse(conn, 200, "application/json; charset=utf-8",
            \\{"providers":[{"id":"local-oss","enabled":true,"openai_compatible":false},{"id":"mesh","enabled":true,"openai_compatible":false}]}
        );
    }
    if (std.mem.eql(u8, method, "GET") and std.mem.eql(u8, path, "/v1/models")) {
        return writeResponse(conn, 200, "application/json; charset=utf-8",
            \\{"data":[{"id":"nexa-ops-local","source":"embedded"},{"id":"qwen2.5:14b-instruct","source":"ollama"},{"id":"deterministic-local","source":"builtin"}]}
        );
    }
    if (std.mem.eql(u8, method, "GET") and std.mem.eql(u8, path, "/telemetry/regions")) {
        return writeResponse(conn, 200, "application/json; charset=utf-8",
            \\{"clusters":[{"country":"US","locale":"en-US","visits":12},{"country":"CA","locale":"en-CA","visits":4},{"country":"DZ","locale":"fr-DZ","visits":2}]}
        );
    }

    return writeResponse(conn, 404, "text/plain; charset=utf-8", "not found");
}

fn parseMethod(request: []const u8) []const u8 {
    const space = std.mem.indexOfScalar(u8, request, ' ') orelse request.len;
    return request[0..space];
}

fn parsePath(request: []const u8) []const u8 {
    const first_space = std.mem.indexOfScalar(u8, request, ' ') orelse return "/";
    const rest = request[first_space + 1 ..];
    const second_space = std.mem.indexOfScalar(u8, rest, ' ') orelse return "/";
    return rest[0..second_space];
}

fn statusText(status: u16) []const u8 {
    return switch (status) {
        200 => "OK",
        404 => "Not Found",
        else => "OK",
    };
}

fn writeResponse(conn: net.Server.Connection, status: u16, content_type: []const u8, body: []const u8) !void {
    var header_buf: [512]u8 = undefined;
    const header = try std.fmt.bufPrint(
        &header_buf,
        "HTTP/1.1 {d} {s}\r\nContent-Type: {s}\r\nContent-Length: {d}\r\nCache-Control: no-store\r\nConnection: close\r\n\r\n",
        .{ status, statusText(status), content_type, body.len },
    );
    try conn.stream.writeAll(header);
    try conn.stream.writeAll(body);
}
