//! Main event loop — Linux epoll. Zig 0.15.2 + std only.
//! Monitors UDP socket and TUN device for incoming packets.

const std = @import("std");
const posix = std.posix;
const linux = std.os.linux;
const udp = @import("udp.zig");
const tun = @import("tun.zig");
const registry = @import("registry.zig");
const wireguard = @import("wireguard.zig");

pub const EventLoop = struct {
    epoll_fd: posix.fd_t,
    udp_sock: udp.UdpSocket,
    tun_dev:  tun.Tun,
    registry: *registry.PeerRegistry,

    pub fn init(udp_sock: udp.UdpSocket, tun_dev: tun.Tun, reg: *registry.PeerRegistry) !EventLoop {
        const epoll_fd = try posix.epoll_create1(0);
        errdefer posix.close(epoll_fd);

        var udp_event = linux.epoll_event{
            .events = linux.EPOLL.IN,
            .data = .{ .fd = udp_sock.fd },
        };
        try posix.epoll_ctl(epoll_fd, linux.EPOLL.CTL_ADD, udp_sock.fd, &udp_event);

        var tun_event = linux.epoll_event{
            .events = linux.EPOLL.IN,
            .data = .{ .fd = tun_dev.fd },
        };
        try posix.epoll_ctl(epoll_fd, linux.EPOLL.CTL_ADD, tun_dev.fd, &tun_event);

        return EventLoop{
            .epoll_fd = epoll_fd,
            .udp_sock = udp_sock,
            .tun_dev  = tun_dev,
            .registry = reg,
        };
    }

    fn handleTunPacket(self: *EventLoop, buf: []u8) !void {
        if (buf.len < 20) return;
        const dest_ip = buf[16..20];
        _ = dest_ip;
        // TODO: find peer in registry by IP
        // For now, G27 stub log:
        std.debug.print("TUN -> UDP: routing packet to {d}.{d}.{d}.{d}\n", .{buf[16], buf[17], buf[18], buf[19]});
    }

    fn handleUdpPacket(self: *EventLoop, buf: []u8, sender: std.net.Address) !void {
        _ = sender;
        if (buf.len < 16) return;
        // G28 stub log:
        std.debug.print("UDP -> TUN: received transport packet, decrypting...\n");
        // TODO: decrypt using peer session key and write to tun
    }

    pub fn deinit(self: *EventLoop) void {
        posix.close(self.epoll_fd);
    }

    pub fn run(self: *EventLoop) !void {
        var events: [16]linux.epoll_event = undefined;
        var buf: [2048]u8 = undefined;

        while (true) {
            const num_events = posix.epoll_wait(&events, -1);
            for (events[0..num_events]) |event| {
                if (event.data.fd == self.udp_sock.fd) {
                    const res = try self.udp_sock.recvFrom(const res = try self.udp_sock.recvFrom(&buf);buf);
                    try self.handleUdpPacket(buf[0..res.n], res.sender);
                    std.debug.print("UDP: received {d} bytes from {any}\n", .{ res.n, res.sender });
                } else if (event.data.fd == self.tun_dev.fd) {
                    const n = try self.tun_dev.read(const n = try self.tun_dev.read(&buf);buf);
                    try self.handleTunPacket(buf[0..n]);
                    std.debug.print("TUN: received {d} bytes\n", .{n});
                }
            }
        }
    }
};

test "EventLoop init and deinit" {
    const localhost = try std.net.Address.parseIp("127.0.0.1", 0);
    var s = try udp.UdpSocket.bind(localhost);
    defer s.close();

    var t = tun.open("aura_test") catch |err| switch (err) {
        error.FileNotFound, error.IoctlFailed, error.AccessDenied => return,
        else => return err,
    };
    defer tun.close(&t);

    var loop = try EventLoop.init(s, t, undefined);
    loop.deinit();
}
