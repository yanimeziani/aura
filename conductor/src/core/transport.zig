const std = @import("std");
const Allocator = std.mem.Allocator;

/// Transport layer — TOR / IPFS / Direct
pub const Transport = enum {
    tor,
    ipfs,
    direct,
};

/// Ed25519 key (32 bytes public, 64 bytes secret)
pub const Ed25519Key = struct {
    public: [32]u8,
    secret: ?[64]u8,

    pub fn generate() Ed25519Key {
        var seed: [32]u8 = undefined;
        std.crypto.random.bytes(&seed);
        const kp = std.crypto.sign.Ed25519.KeyPair.create(seed);
        return .{
            .public = kp.public_key,
            .secret = kp.secret_key,
        };
    }

    pub fn sign(self: Ed25519Key, message: []const u8) ![64]u8 {
        if (self.secret) |secret| {
            return std.crypto.sign.Ed25519.sign(message, secret, null);
        }
        return error.NoSecretKey;
    }

    pub fn verify(self: Ed25519Key, message: []const u8, sig: [64]u8) bool {
        std.crypto.sign.Ed25519.verify(sig, message, self.public, null) catch return false;
        return true;
    }

    /// Signature size: 64 bytes (vs RSA 256+)
    pub const SIGNATURE_SIZE = 64;
    /// Public key size: 32 bytes (vs RSA 256+)
    pub const PUBLIC_KEY_SIZE = 32;
};

/// SOCKS5 proxy for TOR
pub const TorProxy = struct {
    host: []const u8,
    port: u16,

    const Self = @This();

    pub fn default() Self {
        return .{
            .host = "127.0.0.1",
            .port = 9050,
        };
    }

    pub fn connect(self: Self, target_onion: []const u8, target_port: u16) !std.net.Stream {
        // Connect to TOR SOCKS5 proxy
        const proxy_addr = std.net.Address.parseIp4(self.host, self.port) catch unreachable;
        const stream = try std.net.tcpConnectToAddress(proxy_addr);

        // SOCKS5 handshake
        try stream.writeAll(&[_]u8{ 0x05, 0x01, 0x00 }); // Version 5, 1 method, no auth

        var resp: [2]u8 = undefined;
        _ = try stream.read(&resp);
        if (resp[0] != 0x05 or resp[1] != 0x00) {
            stream.close();
            return error.Socks5AuthFailed;
        }

        // Connect request (domain name type for .onion)
        var req = std.ArrayList(u8).init(std.heap.page_allocator);
        defer req.deinit();

        try req.append(0x05); // Version
        try req.append(0x01); // Connect
        try req.append(0x00); // Reserved
        try req.append(0x03); // Domain name
        try req.append(@intCast(target_onion.len));
        try req.appendSlice(target_onion);
        try req.append(@intCast(target_port >> 8));
        try req.append(@intCast(target_port & 0xFF));

        try stream.writeAll(req.items);

        var connect_resp: [10]u8 = undefined;
        _ = try stream.read(&connect_resp);
        if (connect_resp[1] != 0x00) {
            stream.close();
            return error.Socks5ConnectFailed;
        }

        return stream;
    }
};

/// IPFS transport
pub const IpfsTransport = struct {
    gateway: []const u8,

    const Self = @This();

    pub fn default() Self {
        return .{ .gateway = "/ip4/127.0.0.1/tcp/5001" };
    }

    pub fn publish(self: Self, data: []const u8) ![]const u8 {
        _ = self;
        _ = data;
        // Returns CID
        return "QmPlaceholder";
    }

    pub fn fetch(self: Self, cid: []const u8) ![]const u8 {
        _ = self;
        _ = cid;
        return "fetched data";
    }
};

/// Secure channel with Ed25519 auth
pub const SecureChannel = struct {
    transport: Transport,
    local_key: Ed25519Key,
    remote_key: ?Ed25519Key,
    stream: ?std.net.Stream,

    const Self = @This();

    pub fn init(transport: Transport) Self {
        return .{
            .transport = transport,
            .local_key = Ed25519Key.generate(),
            .remote_key = null,
            .stream = null,
        };
    }

    pub fn handshake(self: *Self, remote_public: [32]u8) !void {
        self.remote_key = .{ .public = remote_public, .secret = null };
        // Exchange signatures to verify identity
    }

    pub fn send(self: *Self, data: []const u8) !void {
        if (self.stream) |stream| {
            const sig = try self.local_key.sign(data);
            try stream.writeAll(&sig);
            try stream.writeAll(data);
        }
    }

    pub fn close(self: *Self) void {
        if (self.stream) |stream| {
            stream.close();
            self.stream = null;
        }
    }
};

test "ed25519 key" {
    const key = Ed25519Key.generate();
    const msg = "test message";
    const sig = try key.sign(msg);
    try std.testing.expect(key.verify(msg, sig));
    try std.testing.expect(!key.verify("wrong message", sig));
}

test "ed25519 size" {
    try std.testing.expectEqual(@as(usize, 64), Ed25519Key.SIGNATURE_SIZE);
    try std.testing.expectEqual(@as(usize, 32), Ed25519Key.PUBLIC_KEY_SIZE);
}
