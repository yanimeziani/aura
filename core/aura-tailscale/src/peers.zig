//! Peer table — fixed-size registry of known WireGuard peers.
//! No heap allocation: backed by a [64]PeerEntry array.
//! Part of the Aura sovereign network stack (aura-tailscale).

const std = @import("std");

pub const MAX_PEERS = 64;

/// A single peer record.
pub const PeerEntry = struct {
    /// WireGuard public key (32 bytes).
    pubkey: [32]u8,
    /// Endpoint string (e.g. "1.2.3.4:51820"), stored in a fixed buffer.
    endpoint: [64]u8,
    endpoint_len: usize,
    /// Allowed-IP CIDR string (e.g. "10.0.0.2/32"), stored in a fixed buffer.
    allowed_ip: [45]u8,
    allowed_ip_len: usize,
    /// Whether a live session exists for this peer.
    has_session: bool,
};

pub const PeerTableError = error{TableFull};

/// Fixed-capacity peer table (max 64 entries, no allocator).
pub const PeerTable = struct {
    peers: [MAX_PEERS]PeerEntry,
    len: usize,

    /// Return an empty PeerTable.
    pub fn init() PeerTable {
        return .{
            .peers = undefined,
            .len   = 0,
        };
    }

    /// Add a peer. Returns error.TableFull when capacity is reached.
    pub fn add(self: *PeerTable, entry: PeerEntry) !void {
        if (self.len >= MAX_PEERS) return PeerTableError.TableFull;
        self.peers[self.len] = entry;
        self.len += 1;
    }

    /// Remove the peer with the given pubkey. Returns true if found and removed.
    pub fn remove(self: *PeerTable, pubkey: [32]u8) bool {
        for (self.peers[0..self.len], 0..) |*p, i| {
            if (std.mem.eql(u8, &p.pubkey, &pubkey)) {
                // Swap with last to avoid shifting.
                self.peers[i] = self.peers[self.len - 1];
                self.len -= 1;
                return true;
            }
        }
        return false;
    }

    /// Return a pointer to the peer with the given pubkey, or null.
    pub fn get(self: *PeerTable, pubkey: [32]u8) ?*PeerEntry {
        for (self.peers[0..self.len]) |*p| {
            if (std.mem.eql(u8, &p.pubkey, &pubkey)) return p;
        }
        return null;
    }

    /// Number of peers currently in the table.
    pub fn count(self: *PeerTable) usize {
        return self.len;
    }
};

// ── Helpers ───────────────────────────────────────────────────────────────────

/// Build a PeerEntry from comptime-known strings. Strings must fit their buffers.
pub fn makeEntry(
    pubkey:      [32]u8,
    endpoint:    []const u8,
    allowed_ip:  []const u8,
    has_session: bool,
) PeerEntry {
    var e: PeerEntry = undefined;
    e.pubkey      = pubkey;
    e.endpoint    = [_]u8{0} ** 64;
    e.allowed_ip  = [_]u8{0} ** 45;
    @memcpy(e.endpoint[0..endpoint.len], endpoint);
    e.endpoint_len   = endpoint.len;
    @memcpy(e.allowed_ip[0..allowed_ip.len], allowed_ip);
    e.allowed_ip_len = allowed_ip.len;
    e.has_session = has_session;
    return e;
}

// ── Unit tests ────────────────────────────────────────────────────────────────

test "PeerTable.init is empty" {
    var t = PeerTable.init();
    try std.testing.expectEqual(@as(usize, 0), t.count());
}

test "PeerTable.add increases count" {
    var t = PeerTable.init();
    const key = [_]u8{0xAB} ** 32;
    const entry = makeEntry(key, "10.0.0.1:51820", "10.0.0.1/32", false);
    try t.add(entry);
    try std.testing.expectEqual(@as(usize, 1), t.count());
}

test "PeerTable.get returns correct entry" {
    var t = PeerTable.init();
    const key = [_]u8{0xCD} ** 32;
    const entry = makeEntry(key, "192.168.1.1:51820", "192.168.1.1/32", true);
    try t.add(entry);

    const found = t.get(key);
    try std.testing.expect(found != null);
    try std.testing.expect(found.?.has_session == true);
    try std.testing.expectEqual(@as(usize, 17), found.?.endpoint_len);
}

test "PeerTable.remove returns true and shrinks count" {
    var t = PeerTable.init();
    const key1 = [_]u8{0x01} ** 32;
    const key2 = [_]u8{0x02} ** 32;
    try t.add(makeEntry(key1, "1.2.3.4:51820", "10.1.0.1/32", false));
    try t.add(makeEntry(key2, "5.6.7.8:51820", "10.1.0.2/32", false));

    const removed = t.remove(key1);
    try std.testing.expect(removed == true);
    try std.testing.expectEqual(@as(usize, 1), t.count());
    try std.testing.expect(t.get(key1) == null);
    try std.testing.expect(t.get(key2) != null);
}

test "PeerTable.remove returns false for unknown key" {
    var t = PeerTable.init();
    const unknown = [_]u8{0xFF} ** 32;
    try std.testing.expect(t.remove(unknown) == false);
}

test "PeerTable.add returns TableFull at capacity" {
    var t = PeerTable.init();
    var i: usize = 0;
    while (i < MAX_PEERS) : (i += 1) {
        var key = [_]u8{0} ** 32;
        key[0] = @intCast(i & 0xFF);
        key[1] = @intCast((i >> 8) & 0xFF);
        try t.add(makeEntry(key, "0.0.0.0:0", "0.0.0.0/0", false));
    }
    const overflow_key = [_]u8{0xEE} ** 32;
    const result = t.add(makeEntry(overflow_key, "0.0.0.0:0", "0.0.0.0/0", false));
    try std.testing.expectError(PeerTableError.TableFull, result);
}
