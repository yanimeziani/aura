//! TCP reverse proxy — aura-edge. Zig 0.15.2 + std only.
//! Basic bind, accept, and bi-directional stream forward.

const std = @import("std");
const posix = std.posix;
const net = std.net;

pub const Proxy = struct {
    allocator: std.mem.Allocator,
    listen_addr: net.Address,

    pub fn init(allocator: std.mem.Allocator, addr: net.Address) Proxy {
        return .{ .allocator = allocator, .listen_addr = addr };
    }

    pub fn run(self: *Proxy) !void {
        const sockfd = try posix.socket(posix.AF.INET, posix.SOCK.STREAM, 0);
        defer posix.close(sockfd);
        try posix.setsockopt(sockfd, posix.SOL.SOCKET, posix.SO.REUSEADDR, &std.mem.toBytes(@as(c_int, 1)));
        try posix.bind(sockfd, &self.listen_addr.any, self.listen_addr.getOsSockLen());
        try posix.listen(sockfd, 128);
        std.debug.print("aura-edge: proxy listening on {any}\n", .{self.listen_addr});
        while (true) {
            const conn = try posix.accept(sockfd, null, null, 0);
            _ = try std.Thread.spawn(.{}, handleConnection, .{self.allocator, conn});
        }
    }
};

fn handleConnection(allocator: std.mem.Allocator, client_fd: posix.fd_t) !void {
    defer posix.close(client_fd);
    _ = allocator;
    // TODO: G33 skeleton - forward to real target based on SNI/Host
    std.debug.print("aura-edge: accepted connection on fd {d}\n", .{client_fd});
}
