//! Control plane client — aura-tailscale. Zig 0.15.2 + std only.
//! HTTP/1.1 long-polling for peer sync and key rotation.

const std = @import("std");
const peers = @import("peers.zig");
const wireguard = @import("wireguard.zig");

pub const ControlClient = struct {
    allocator: std.mem.Allocator,
    control_url: []const u8,
    node_key: wireguard.KeyPair,

    pub fn init(allocator: std.mem.Allocator, url: []const u8, key: wireguard.KeyPair) ControlClient {
        return .{
            .allocator = allocator,
            .control_url = url,
            .node_key = key,
        };
    }

    /// Sync peers from control plane. G30 + G31.
    pub fn syncPeers(self: *ControlClient, table: *peers.PeerTable) !void {
        var client = std.http.Client{ .allocator = self.allocator };
        defer client.deinit();

        const uri = try std.Uri.parse(self.control_url);
        var req = try client.request(.GET, uri, .{});
        defer req.deinit();

        try req.sendBodiless();

        var header_buf: [4096]u8 = undefined;
        var response = try req.receiveHead(&header_buf);

        if (response.head.status != .ok) return error.ControlPlaneError;

        var transfer_buf: [4096]u8 = undefined;
        const reader = response.reader(&transfer_buf);
        const body = try reader.allocRemaining(self.allocator, 1024 * 1024);
        defer self.allocator.free(body);

        const parsed = try std.json.parseFromSlice(ControlResponse, self.allocator, body, .{
            .ignore_unknown_fields = true,
        });
        defer parsed.deinit();

        for (parsed.value.peers) |p| {
            var pubkey: [32]u8 = undefined;
            _ = try std.fmt.hexToBytes(&pubkey, p.public_key);

            // Skip ourselves.
            if (std.mem.eql(u8, &pubkey, &self.node_key.public)) continue;

            if (table.get(pubkey)) |existing| {
                // Update existing endpoint if provided.
                if (p.endpoint.len > 0) {
                    const elen = @min(p.endpoint.len, existing.endpoint.len);
                    @memcpy(existing.endpoint[0..elen], p.endpoint[0..elen]);
                    existing.endpoint_len = elen;
                }
                // Update allowed IP if provided.
                if (p.allowed_ips.len > 0) {
                    const alen = @min(p.allowed_ips[0].len, existing.allowed_ip.len);
                    @memcpy(existing.allowed_ip[0..alen], p.allowed_ips[0][0..alen]);
                    existing.allowed_ip_len = alen;
                }
            } else {
                // Add new peer.
                const endpoint = if (p.endpoint.len > 0) p.endpoint else "0.0.0.0:0";
                const allowed_ip = if (p.allowed_ips.len > 0) p.allowed_ips[0] else "0.0.0.0/0";
                try table.add(peers.makeEntry(pubkey, endpoint, allowed_ip, false));
            }
        }
    }

    /// Key rotation mechanism. G32.
    /// Generates a new KeyPair and (ideally) updates control plane.
    pub fn rotateKey(self: *ControlClient) void {
        self.node_key = wireguard.KeyPair.generate();
        std.log.info("Key rotated. New pubkey: {s}", .{std.fmt.fmtSliceHexLower(&self.node_key.public)});
    }
};

const ControlResponse = struct {
    peers: []const PeerInfo,
};

const PeerInfo = struct {
    public_key: []const u8,
    endpoint: []const u8,
    allowed_ips: []const []const u8,
};

test "ControlClient init" {
    const kp = wireguard.KeyPair.generate();
    const client = ControlClient.init(std.testing.allocator, "http://localhost:8080", kp);
    try std.testing.expect(client.node_key.public.len == 32);
}

test "ControlClient parse dummy" {
    const allocator = std.testing.allocator;
    const json = 
        \\{
        \\  "peers": [
        \\    {
        \\      "public_key": "000102030405060708090a0b0c0d0e0f101112131415161718191a1b1c1d1e1f",
        \\      "endpoint": "1.2.3.4:51820",
        \\      "allowed_ips": ["10.0.0.2/32"]
        \\    }
        \\  ]
        \\}
    ;
    const parsed = try std.json.parseFromSlice(ControlResponse, allocator, json, .{});
    defer parsed.deinit();
    try std.testing.expectEqual(@as(usize, 1), parsed.value.peers.len);
    try std.testing.expectEqualStrings("1.2.3.4:51820", parsed.value.peers[0].endpoint);
}
