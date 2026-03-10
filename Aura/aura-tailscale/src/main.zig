const std = @import("std");
const aura_tailscale = @import("aura_tailscale");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var args = try std.process.argsWithAllocator(allocator);
    defer args.deinit();
    _ = args.next();

    const cmd = args.next() orelse "status";
    if (std.mem.eql(u8, cmd, "up")) {
        return runUp(allocator, &args);
    }
    if (std.mem.eql(u8, cmd, "down")) {
        return runDown(allocator);
    }
    if (std.mem.eql(u8, cmd, "status")) {
        return runStatus(allocator);
    }
    if (std.mem.eql(u8, cmd, "daemon")) {
        return runDaemon(allocator);
    }
    if (std.mem.eql(u8, cmd, "help") or std.mem.eql(u8, cmd, "-h")) {
        printHelp();
        return;
    }
    std.log.err("Unknown command: {s}", .{cmd});
    std.process.exit(1);
}

fn runUp(allocator: std.mem.Allocator, args: *std.process.ArgIterator) !void {
    _ = args;
    try aura_tailscale.setState(allocator, .up);
}

fn runDown(allocator: std.mem.Allocator) !void {
    try aura_tailscale.setState(allocator, .down);
}

fn runStatus(allocator: std.mem.Allocator) !void {
    const state = aura_tailscale.getState(allocator);
    std.debug.print("Aura mesh: {s}\n", .{@tagName(state)});
}

fn runDaemon(allocator: std.mem.Allocator) !void {
    std.debug.print("aura-tailscale: starting initiator daemon...\n", .{});
    var reg = aura_tailscale.registry.PeerRegistry.init();
    const our_static = aura_tailscale.wireguard.KeyPair.generate();
    const hex_pub = std.fmt.bytesToHex(our_static.public, .lower);
    std.debug.print("Node pubkey: {s}\n", .{&hex_pub});
    var sender_idx: u32 = 1;
    while (true) {
        for (reg.table.peers[0..reg.table.len]) |*peer| {
            if (!peer.has_session) {
                const p_hex = std.fmt.bytesToHex(peer.pubkey, .lower);
                std.debug.print("Initiating handshake with peer {s}...\n", .{&p_hex});
                const init_msg = aura_tailscale.wireguard.initiationCreate(
                    &our_static,
                    &peer.pubkey,
                    sender_idx,
                ) catch |err| {
                    std.debug.print("  handshake create error: {}\n", .{err});
                    continue;
                };
                sender_idx +%= 1;
                sendHandshakeInitiation(allocator, peer, &init_msg) catch |err| {
                    std.debug.print("  handshake send error: {}\n", .{err});
                };
            }
        }
        std.Thread.sleep(5 * std.time.ns_per_s);
    }
}

/// Send an InitiationMsg as a UDP datagram to peer.endpoint.
fn sendHandshakeInitiation(
    allocator: std.mem.Allocator,
    peer: *aura_tailscale.peers.PeerEntry,
    msg: *const aura_tailscale.wireguard.InitiationMsg,
) !void {
    _ = allocator;
    const endpoint_str = peer.endpoint[0..peer.endpoint_len];
    // Parse "ip:port" — last colon separates host from port (handles IPv4).
    const colon = std.mem.lastIndexOfScalar(u8, endpoint_str, ':') orelse return error.InvalidEndpoint;
    const ip_str = endpoint_str[0..colon];
    const port_str = endpoint_str[colon + 1 ..];
    const port = std.fmt.parseInt(u16, port_str, 10) catch return error.InvalidEndpoint;
    const addr = try std.net.Address.parseIp(ip_str, port);

    const sock = try std.posix.socket(addr.any.family, std.posix.SOCK.DGRAM, 0);
    defer std.posix.close(sock);

    const msg_bytes = std.mem.asBytes(msg);
    const sent = try std.posix.sendto(sock, msg_bytes, 0, &addr.any, addr.getOsSockLen());
    std.debug.print("  sent {d} bytes to {s}\n", .{ sent, endpoint_str });
}

fn printHelp() void {
    std.debug.print("Aura mesh (Zig)\n\nCommands:\n  up, down, status, daemon, help\n", .{});
}
