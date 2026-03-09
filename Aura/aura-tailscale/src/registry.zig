//! Peer Registry — aura-tailscale. Zig 0.15.2 + std only.
//! Manages peer records and their associated handshake states.

const std = @import("std");
const peers = @import("peers.zig");
const wireguard = @import("wireguard.zig");

pub const PeerRegistry = struct {
    table:     peers.PeerTable,
    /// Handshake state for each peer. Fixed size, maps 1:1 to table.peers.
    handshakes: [peers.MAX_PEERS]?wireguard.SessionKeys,

    pub fn init() PeerRegistry {
        return .{
            .table = peers.PeerTable.init(),
            .handshakes = [_]?wireguard.SessionKeys{null} ** peers.MAX_PEERS,
        };
    }

    /// Add a peer to the registry.
    pub fn addPeer(self: *PeerRegistry, entry: peers.PeerEntry) !void {
        try self.table.add(entry);
    }

    /// Find a peer by public key.
    pub fn getPeer(self: *PeerRegistry, pubkey: [32]u8) ?*peers.PeerEntry {
        return self.table.get(pubkey);
    }

    /// Handle an incoming initiation message.
    /// In a real impl, this would return a ResponseMsg or error.
    pub fn processInitiation(
        self: *PeerRegistry,
        our_static: *const wireguard.KeyPair,
        msg: *const wireguard.InitiationMsg,
    ) !struct { response: wireguard.ResponseMsg, peer: *peers.PeerEntry } {
        // 1. Recover initiator public key? (Requires decrypting the message static pubkey)
        // For now, we use a simplified responder logic that assumes we know who is calling
        // or we iterate over peers to find a match after decryption.
        
        // Real WireGuard: we don't know who it is yet. we must decrypt with our static private.
        // responseCreate does this.
        
        // We need a way to verify the recovered pubkey belongs to a known peer.
        // Iterate over all peers and try to match (naive for now).
        for (self.table.peers[0..self.table.len], 0..) |*peer, i| {
            const result = wireguard.responseCreate(our_static, &peer.pubkey, msg, 0x1234) catch |err| {
                if (err == error.AuthenticationFailure) continue;
                return err;
            };
            
            // Found a match!
            self.handshakes[i] = result.keys;
            peer.has_session = true;
            return .{ .response = result.response, .peer = peer };
        }

        return error.UnknownPeer;
    }
};

test "PeerRegistry.init is empty" {
    var r = PeerRegistry.init();
    try std.testing.expectEqual(@as(usize, 0), r.table.count());
}

test "PeerRegistry: process initiation with known peer" {
    const initiator = wireguard.KeyPair.generate();
    const responder = wireguard.KeyPair.generate();
    
    var r = PeerRegistry.init();
    const peer_entry = peers.makeEntry(initiator.public, "10.0.0.1:51820", "10.0.0.1/32", false);
    try r.addPeer(peer_entry);

    const init_msg = try wireguard.initiationCreate(&initiator, &responder.public, 0x1111);
    
    const result = try r.processInitiation(&responder, &init_msg);
    try std.testing.expect(result.peer != null);
    try std.testing.expectEqual(initiator.public, result.peer.pubkey);
    try std.testing.expect(result.peer.has_session == true);
    try std.testing.expectEqual(@as(u8, 2), result.response.message_type);
}

test "G90: aura-tailscale packet fuzzing" {
    const kp = wireguard.KeyPair.generate();
    var reg = PeerRegistry.init();
    var rand = std.crypto.random;
    var i: usize = 0;
    while (i < 100) : (i += 1) {
        var bad_pkt: [148]u8 = undefined;
        rand.bytes(&bad_pkt);
        // Should fail gracefully
        _ = reg.processInitiation(&kp, @ptrCast(&bad_pkt)) catch {};
    }
}
