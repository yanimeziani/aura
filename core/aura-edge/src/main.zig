const std = @import("std");
const net = std.net;
const mem = std.mem;
const Config = @import("config.zig").Config;
const ProtectionLayer = @import("protection.zig").ProtectionLayer;
const EgressMonitor = @import("egress.zig").EgressMonitor;
const Request = @import("http.zig").Request;

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();
    defer _ = gpa.deinit();

    var config = Config.init(allocator);
    defer config.deinit();

    // Example upstream setup
    try config.addUpstream("localhost", "127.0.0.1:8081");
    try config.addUpstream("example.com", "127.0.0.1:8082");

    var protection = ProtectionLayer.init(allocator, &config);
    defer protection.deinit();

    var egress = EgressMonitor.init(allocator, &config);
    defer egress.deinit();
    
    const address = try net.Address.parseIp("0.0.0.0", 8080);
    var server = try address.listen(.{
        .reuse_address = true,
    });
    defer server.deinit();

    std.debug.print("🚀 Aura Edge: Sovereignty Active at http://0.0.0.0:8080\n", .{});
    std.debug.print("🛡️  Protection: Dynamic filtering enabled\n", .{});
    std.debug.print("🌐 Egress: Outbound monitoring enabled\n", .{});

    while (true) {
        const conn = try server.accept();
        
        // Spawn a thread for each connection to handle proxying
        const thread = std.Thread.spawn(.{}, handleConnectionThread, .{ allocator, conn, &protection, &egress, &config }) catch |err| {
            std.debug.print("Failed to spawn thread: {}\n", .{err});
            conn.stream.close();
            continue;
        };
        thread.detach();
    }
}

fn formatClientIp(addr: net.Address, buf: []u8) []const u8 {
    var fbs = std.io.fixedBufferStream(buf);
    std.fmt.format(fbs.writer(), "{f}", .{addr}) catch return "unknown";
    const full = fbs.getWritten();
    if (full.len == 0) return "unknown";
    if (full[0] == '[') {
        const bracket = mem.lastIndexOfScalar(u8, full, ']') orelse return full;
        return full[0 .. bracket + 1];
    }
    const colon = mem.lastIndexOfScalar(u8, full, ':') orelse return full;
    return full[0..colon];
}

fn handleConnectionThread(allocator: mem.Allocator, conn: net.Server.Connection, protection: *ProtectionLayer, egress: *EgressMonitor, config: *const Config) void {
    defer conn.stream.close();

    var ip_buf: [64]u8 = undefined;
    const client_ip = formatClientIp(conn.address, &ip_buf);

    const allowed = protection.checkConnection(client_ip) catch false;
    if (!allowed) {
        const response = "HTTP/1.1 429 Too Many Requests\r\nContent-Length: 26\r\nConnection: close\r\n\r\n🛡️ Aura: Rate Limit Exceeded";
        _ = conn.stream.write(response) catch {};
        return;
    }
    defer protection.closeConnection(client_ip);

    // Read the initial chunk of the request
    var buf: [8192]u8 = undefined;
    const n = conn.stream.read(&buf) catch return;
    if (n == 0) return;

    const request_data = buf[0..n];

    // Extract Host header
    var host_header: ?[]const u8 = null;
    var lines = mem.splitSequence(u8, request_data, "\r\n");
    _ = lines.next(); // Skip request line
    while (lines.next()) |line| {
        if (line.len == 0) break; // End of headers
        if (mem.startsWith(u8, line, "Host: ")) {
            host_header = mem.trim(u8, line[6..], " \r");
            break;
        }
    }

    if (host_header) |host| {
        // Strip port from host header if present
        const colon = mem.indexOfScalar(u8, host, ':');
        const clean_host = if (colon) |c| host[0..c] else host;

        if (config.upstreams.get(clean_host)) |target| {
            proxyRequest(allocator, conn, request_data, target, clean_host, egress) catch |err| {
                std.debug.print("Proxy error for {s}: {}\n", .{clean_host, err});
                sendError(conn, 502, "Bad Gateway");
            };
            return;
        }
    }

    // Default static response if no upstream found
    const response = 
        "HTTP/1.1 200 OK\r\n" ++
        "Content-Type: text/html; charset=utf-8\r\n" ++
        "Connection: close\r\n" ++
        "Server: AuraEdge/0.2 (Zig)\r\n" ++
        "\r\n" ++
        "<html><head><style>body{background:#0a0a0a;color:#ededed;font-family:sans-serif;display:flex;justify-content:center;align-items:center;height:100vh;margin:0}h1{font-size:3rem;background:linear-gradient(to right,#fff,#888);-webkit-background-clip:text;-webkit-text-fill-color:transparent}</style></head>" ++
        "<body><div><h1>Aura Sovereign Edge</h1><p>Served via Zig &middot; Low-latency &middot; Cloudflare Replacement</p></div></body></html>";
    _ = conn.stream.write(response) catch {};
}

fn sendError(conn: net.Server.Connection, code: u32, msg: []const u8) void {
    var buf: [512]u8 = undefined;
    const response = std.fmt.bufPrint(&buf, "HTTP/1.1 {d} {s}\r\nContent-Length: {d}\r\nConnection: close\r\n\r\n{s}", .{code, msg, msg.len, msg}) catch return;
    _ = conn.stream.write(response) catch {};
}

fn proxyRequest(allocator: mem.Allocator, client_conn: net.Server.Connection, initial_data: []const u8, target: []const u8, host: []const u8, egress: *EgressMonitor) !void {
    _ = allocator;
    var target_it = mem.splitScalar(u8, target, ':');
    const target_ip = target_it.next() orelse return error.InvalidTarget;
    const target_port_str = target_it.next() orelse return error.InvalidTarget;
    const target_port = try std.fmt.parseInt(u16, target_port_str, 10);

    const target_addr = try net.Address.parseIp(target_ip, target_port);
    const upstream_stream = try net.tcpConnectToAddress(target_addr);
    defer upstream_stream.close();

    // Send initial data to upstream
    try upstream_stream.writeAll(initial_data);
    try egress.recordEgress(host, initial_data.len);

    // Spawn thread to pipe upstream -> client
    const PipeArgs = struct {
        client: net.Stream,
        upstream: net.Stream,
    };
    
    const pipe_thread = try std.Thread.spawn(.{}, struct {
        fn run(args: PipeArgs) void {
            var buf: [8192]u8 = undefined;
            while (true) {
                const n = args.upstream.read(&buf) catch 0;
                if (n == 0) break;
                args.client.writeAll(buf[0..n]) catch break;
            }
        }
    }.run, .{ PipeArgs{ .client = client_conn.stream, .upstream = upstream_stream } });

    // Pipe client -> upstream in current thread
    var buf: [8192]u8 = undefined;
    while (true) {
        const n = client_conn.stream.read(&buf) catch 0;
        if (n == 0) break;
        upstream_stream.writeAll(buf[0..n]) catch break;
        egress.recordEgress(host, n) catch {};
    }

    pipe_thread.join();
}
