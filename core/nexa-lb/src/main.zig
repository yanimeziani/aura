//! nexa-lb — TCP load balancer (Zig 0.13, std only).
//! Layer-4 proxy: round-robin (default) or random across upstream host:port targets.

const std = @import("std");
const net = std.net;
const mem = std.mem;
const posix = std.posix;

const Backend = struct {
    host: []const u8,
    port: u16,
};

const Policy = enum { round_robin, random };

var rr_counter = std.atomic.Value(usize).init(0);

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const args = try std.process.argsAlloc(allocator);
    defer std.process.argsFree(allocator, args);

    const listen_spec = blk: {
        if (args.len >= 2) break :blk args[1];
        break :blk std.posix.getenv("NEXA_LB_LISTEN") orelse "0.0.0.0:9650";
    };

    const upstreams_spec = blk: {
        if (args.len >= 3) {
            var list = std.ArrayList(Backend).init(allocator);
            errdefer list.deinit();
            var i: usize = 2;
            while (i < args.len) : (i += 1) {
                const b = parseHostPort(args[i]) orelse {
                    std.debug.print("bad upstream (want host:port): {s}\n", .{args[i]});
                    return error.BadArg;
                };
                try list.append(b);
            }
            if (list.items.len == 0) {
                std.debug.print("need at least one upstream\n", .{});
                return error.BadArg;
            }
            break :blk try list.toOwnedSlice();
        }
        const env = std.posix.getenv("NEXA_LB_UPSTREAMS") orelse {
            std.debug.print(
                \\usage: nexa-lb <listen host:port> <upstream> [upstream ...]
                \\   or: NEXA_LB_LISTEN=0.0.0.0:9650 NEXA_LB_UPSTREAMS=h1:8765,h2:8765 nexa-lb
                \\
            , .{});
            return error.BadEnv;
        };
        break :blk try parseUpstreamList(allocator, env);
    };
    defer allocator.free(upstreams_spec);

    const policy: Policy = policy: {
        const s = std.posix.getenv("NEXA_LB_POLICY") orelse "round_robin";
        if (mem.eql(u8, s, "round_robin")) break :policy .round_robin;
        if (mem.eql(u8, s, "random")) break :policy .random;
        std.debug.print("unknown NEXA_LB_POLICY={s} (use round_robin|random)\n", .{s});
        return error.BadEnv;
    };

    const listen_addr = parseHostPort(listen_spec) orelse {
        std.debug.print("bad listen address: {s}\n", .{listen_spec});
        return error.BadArg;
    };

    const address = try resolveListenAddress(listen_addr.host, listen_addr.port);
    var server = try address.listen(.{ .reuse_address = true });
    defer server.deinit();

    std.debug.print("nexa-lb listen {s}:{d} -> {d} upstream(s) policy={s}\n", .{
        listen_addr.host,
        listen_addr.port,
        upstreams_spec.len,
        @tagName(policy),
    });
    for (upstreams_spec, 0..) |u, k| {
        std.debug.print("  [{d}] {s}:{d}\n", .{ k, u.host, u.port });
    }

    while (true) {
        const conn = try server.accept();
        const thread = try std.Thread.spawn(.{}, proxySession, .{ allocator, conn, upstreams_spec, policy });
        thread.detach();
    }
}

fn resolveListenAddress(host: []const u8, port: u16) !net.Address {
    if (mem.eql(u8, host, "0.0.0.0") or mem.eql(u8, host, "*")) {
        return net.Address.parseIp("0.0.0.0", port);
    }
    const resolved = try std.net.getAddressList(std.heap.page_allocator, host, port);
    defer resolved.deinit();
    if (resolved.addrs.len == 0) return error.UnknownHostName;
    return resolved.addrs[0];
}

fn parseHostPort(spec: []const u8) ?Backend {
    const colon = mem.lastIndexOfScalar(u8, spec, ':') orelse return null;
    if (colon == 0 or colon + 1 >= spec.len) return null;
    const host = spec[0..colon];
    const port_str = spec[colon + 1 ..];
    const port = std.fmt.parseInt(u16, port_str, 10) catch return null;
    return .{ .host = host, .port = port };
}

fn parseUpstreamList(allocator: mem.Allocator, spec: []const u8) ![]const Backend {
    var out = std.ArrayList(Backend).init(allocator);
    errdefer out.deinit();

    var rest = spec;
    while (rest.len > 0) {
        const end = mem.indexOfScalar(u8, rest, ',') orelse rest.len;
        const part = mem.trim(u8, rest[0..end], " \t");
        if (part.len > 0) {
            const b = parseHostPort(part) orelse return error.BadUpstream;
            try out.append(b);
        }
        rest = if (end >= rest.len) "" else rest[end + 1 ..];
    }
    if (out.items.len == 0) return error.BadUpstream;
    return try out.toOwnedSlice();
}

fn pickBackend(backends: []const Backend, policy: Policy) usize {
    return switch (policy) {
        .round_robin => blk: {
            const n = rr_counter.fetchAdd(1, .monotonic);
            break :blk n % backends.len;
        },
        .random => blk: {
            var buf: [8]u8 = undefined;
            std.posix.getrandom(&buf) catch {
                const n = rr_counter.fetchAdd(1, .monotonic);
                break :blk n % backends.len;
            };
            const r = std.mem.readInt(u64, buf[0..8], .little);
            break :blk @as(usize, @intCast(r % backends.len));
        },
    };
}

fn proxySession(allocator: mem.Allocator, client: net.Server.Connection, backends: []const Backend, policy: Policy) void {
    defer client.stream.close();

    const idx = pickBackend(backends, policy);
    const b = backends[idx];

    const upstream = net.tcpConnectToHost(allocator, b.host, b.port) catch |err| {
        std.debug.print("upstream {s}:{d} connect failed: {}\n", .{ b.host, b.port, err });
        return;
    };
    defer upstream.close();

    const t = std.Thread.spawn(.{}, pump, .{ client.stream, upstream }) catch return;
    defer {
        posix.shutdown(upstream.handle, .both) catch {};
        t.join();
    }
    pump(upstream, client.stream);
}

fn pump(from: net.Stream, to: net.Stream) void {
    var buf: [65536]u8 = undefined;
    while (true) {
        const n = from.read(&buf) catch break;
        if (n == 0) break;
        to.writeAll(buf[0..n]) catch break;
    }
}
