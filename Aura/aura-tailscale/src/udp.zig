const std = @import("std");

pub const UdpSocket = struct {
    fd: std.posix.fd_t,

    pub fn bind(address: std.net.Address) !UdpSocket {
        const fd = try std.posix.socket(
            address.any.family,
            std.posix.SOCK.DGRAM | std.posix.SOCK.CLOEXEC,
            0,
        );
        errdefer std.posix.close(fd);

        try std.posix.bind(fd, &address.any, address.getOsSockLen());

        return UdpSocket{ .fd = fd };
    }

    pub fn close(self: *UdpSocket) void {
        std.posix.close(self.fd);
    }

    pub fn sendTo(self: UdpSocket, address: std.net.Address, buf: []const u8) !usize {
        return std.posix.sendto(
            self.fd,
            buf,
            0,
            &address.any,
            address.getOsSockLen(),
        );
    }

    pub fn recvFrom(self: UdpSocket, buf: []u8) !struct { n: usize, sender: std.net.Address } {
        var addr: std.posix.sockaddr.storage = undefined;
        var addrlen: std.posix.socklen_t = @sizeOf(std.posix.sockaddr.storage);
        const n = try std.posix.recvfrom(
            self.fd,
            buf,
            0,
            @ptrCast(&addr),
            &addrlen,
        );
        return .{
            .n = n,
            .sender = std.net.Address.initPosix(@ptrCast(&addr)),
        };
    }

    pub fn getLocalAddress(self: UdpSocket) !std.net.Address {
        var addr: std.posix.sockaddr.storage = undefined;
        var addrlen: std.posix.socklen_t = @sizeOf(std.posix.sockaddr.storage);
        try std.posix.getsockname(self.fd, @ptrCast(&addr), &addrlen);
        return std.net.Address.initPosix(@ptrCast(&addr));
    }
};

test "udp bind and send/recv" {
    const localhost = try std.net.Address.parseIp("127.0.0.1", 0);
    var s1 = try UdpSocket.bind(localhost);
    defer s1.close();

    const s1_addr = try s1.getLocalAddress();
    const dest = try std.net.Address.parseIp("127.0.0.1", s1_addr.getPort());

    var s2 = try UdpSocket.bind(localhost);
    defer s2.close();

    const msg = "hello aura";
    _ = try s2.sendTo(dest, msg);

    var buf: [1024]u8 = undefined;
    const res = try s1.recvFrom(&buf);
    try std.testing.expectEqualStrings(msg, buf[0..res.n]);
}
