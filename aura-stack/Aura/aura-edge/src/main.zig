const std = @import("std");
const net = std.net;
const mem = std.mem;

/// Aura Protection Layer: Mimics Cloudflare DDoS protection
const ProtectionLayer = struct {
    const RateLimit = struct {
        count: u32,
        last_reset: i64,
    };

    const LIMIT_PER_MINUTE: u32 = 100;
    
    // In-memory IP registry (simplified for first sweep)
    registry: std.StringHashMap(RateLimit),
    allocator: mem.Allocator,

    pub fn init(allocator: mem.Allocator) ProtectionLayer {
        return .{
            .registry = std.StringHashMap(RateLimit).init(allocator),
            .allocator = allocator,
        };
    }

    pub fn isAllowed(self: *ProtectionLayer, ip: []const u8) !bool {
        const now = std.time.timestamp();
        var entry = self.registry.get(ip) orelse RateLimit{ .count = 0, .last_reset = now };

        if (now - entry.last_reset > 60) {
            entry.count = 0;
            entry.last_reset = now;
        }

        entry.count += 1;
        try self.registry.put(ip, entry);

        return entry.count <= LIMIT_PER_MINUTE;
    }
};

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();
    defer _ = gpa.deinit();

    var protection = ProtectionLayer.init(allocator);
    
    const address = try net.Address.parseIp("0.0.0.0", 8080);
    var server = try address.listen(.{
        .reuse_address = true,
    });
    defer server.deinit();

    std.debug.print("🚀 Aura Edge: Sovereignty Active at http://0.0.0.0:8080\n", .{});
    std.debug.print("🛡️  Protection: Rate-limiting enabled (First Sweep)\n", .{});

    while (true) {
        const conn = try server.accept();
        handleConnection(conn, &protection) catch |err| {
            std.debug.print("Error handling connection: {}\n", .{err});
        };
    }
}

/// Extract just the IP (no port) from a net.Address into buf. Returns a slice of buf.
fn formatClientIp(addr: net.Address, buf: []u8) []const u8 {
    var fbs = std.io.fixedBufferStream(buf);
    std.fmt.format(fbs.writer(), "{f}", .{addr}) catch return "unknown";
    const full = fbs.getWritten();
    if (full.len == 0) return "unknown";
    if (full[0] == '[') {
        // IPv6: [::1]:port — strip :port after the closing bracket
        const bracket = mem.lastIndexOfScalar(u8, full, ']') orelse return full;
        return full[0 .. bracket + 1];
    }
    // IPv4: 1.2.3.4:port — strip :port
    const colon = mem.lastIndexOfScalar(u8, full, ':') orelse return full;
    return full[0..colon];
}

fn handleConnection(conn: net.Server.Connection, protection: *ProtectionLayer) !void {
    defer conn.stream.close();

    var ip_buf: [64]u8 = undefined;
    const client_ip = formatClientIp(conn.address, &ip_buf);

    if (!try protection.isAllowed(client_ip)) {
        const response = "HTTP/1.1 429 Too Many Requests\r\nContent-Length: 26\r\n\r\n🛡️ Aura: Rate Limit Exceeded";
        _ = try conn.stream.write(response);
        return;
    }

    var buf: [1024]u8 = undefined;
    const n = try conn.stream.read(&buf);
    _ = n;

    const response = 
        "HTTP/1.1 200 OK\r\n" ++
        "Content-Type: text/html; charset=utf-8\r\n" ++
        "Connection: close\r\n" ++
        "Server: AuraEdge/0.1 (Zig)\r\n" ++
        "\r\n" ++
        "<html><head><style>body{background:#0a0a0a;color:#ededed;font-family:sans-serif;display:flex;justify-content:center;align-items:center;height:100vh;margin:0}h1{font-size:3rem;background:linear-gradient(to right,#fff,#888);-webkit-background-clip:text;-webkit-text-fill-color:transparent}</style></head>" ++
        "<body><div><h1>Aura Sovereign Edge</h1><p>Served via Zig &middot; Low-latency &middot; Cloudflare Replacement (First Sweep)</p></div></body></html>";

    _ = try conn.stream.write(response);
}
