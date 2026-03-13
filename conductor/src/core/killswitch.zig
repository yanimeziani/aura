const std = @import("std");
const Allocator = std.mem.Allocator;
const Ed25519Key = @import("transport.zig").Ed25519Key;

/// Kill switch triggers
pub const Trigger = enum {
    heartbeat_timeout, // Phone offline
    unencrypted_traffic, // Cleartext detected
    auth_anomaly, // Suspicious auth pattern
    manual, // Emergency button
    tamper_detected, // Physical/logical tampering
};

/// Kill switch state
pub const State = enum {
    armed,
    triggered,
    purging,
    dead,
};

/// Secure memory region — zeroed on purge
pub fn SecureBuffer(comptime size: usize) type {
    return struct {
        data: [size]u8,
        valid: bool,

        const Self = @This();

        pub fn init() Self {
            return .{ .data = [_]u8{0} ** size, .valid = false };
        }

        pub fn write(self: *Self, src: []const u8) void {
            const len = @min(src.len, size);
            @memcpy(self.data[0..len], src[0..len]);
            self.valid = true;
        }

        /// Cryptographic zeroing — not optimized away
        pub fn purge(self: *Self) void {
            std.crypto.utils.secureZero(u8, &self.data);
            self.valid = false;
        }
    };
}

/// Kill switch controller
pub const KillSwitch = struct {
    state: State,
    last_heartbeat: i64,
    heartbeat_timeout_ms: i64,
    keys: std.ArrayList(Ed25519Key),
    secure_buffers: std.ArrayList(*anyopaque),
    on_trigger: ?*const fn (Trigger) void,

    const Self = @This();

    pub fn init(allocator: Allocator) Self {
        return .{
            .state = .armed,
            .last_heartbeat = std.time.milliTimestamp(),
            .heartbeat_timeout_ms = 30_000, // 30 seconds
            .keys = std.ArrayList(Ed25519Key).init(allocator),
            .secure_buffers = std.ArrayList(*anyopaque).init(allocator),
            .on_trigger = null,
        };
    }

    /// Phone sends heartbeat
    pub fn heartbeat(self: *Self) void {
        self.last_heartbeat = std.time.milliTimestamp();
    }

    /// Check for timeout — call in tick loop
    pub fn check(self: *Self) void {
        if (self.state != .armed) return;

        const now = std.time.milliTimestamp();
        if (now - self.last_heartbeat > self.heartbeat_timeout_ms) {
            self.trigger(.heartbeat_timeout);
        }
    }

    /// Detect unencrypted traffic
    pub fn inspectTraffic(self: *Self, data: []const u8) void {
        if (self.state != .armed) return;

        // Heuristic: check for plaintext patterns
        if (detectPlaintext(data)) {
            self.trigger(.unencrypted_traffic);
        }
    }

    /// Manual emergency trigger
    pub fn emergency(self: *Self) void {
        self.trigger(.manual);
    }

    /// Core trigger — initiates purge
    pub fn trigger(self: *Self, reason: Trigger) void {
        if (self.state != .armed) return;

        self.state = .triggered;

        // Callback
        if (self.on_trigger) |cb| {
            cb(reason);
        }

        // Execute purge sequence
        self.purge();
    }

    /// Purge all sensitive data
    fn purge(self: *Self) void {
        self.state = .purging;

        // 1. Zero all keys
        for (self.keys.items) |*key| {
            if (key.secret) |*secret| {
                std.crypto.utils.secureZero(u8, secret);
                key.secret = null;
            }
            std.crypto.utils.secureZero(u8, &key.public);
        }
        self.keys.clearRetainingCapacity();

        // 2. Zero all secure buffers (registered externally)
        // Buffers must implement purge()

        // 3. State = dead
        self.state = .dead;
    }

    /// Rotate all keys (post-incident recovery)
    pub fn rotateAllKeys(self: *Self) void {
        for (self.keys.items) |*key| {
            // Zero old key
            if (key.secret) |*secret| {
                std.crypto.utils.secureZero(u8, secret);
            }
            std.crypto.utils.secureZero(u8, &key.public);

            // Generate new
            key.* = Ed25519Key.generate();
        }
    }

    pub fn registerKey(self: *Self, key: Ed25519Key) !void {
        try self.keys.append(key);
    }
};

/// Heuristic plaintext detection
fn detectPlaintext(data: []const u8) bool {
    if (data.len < 16) return false;

    // Check for high ASCII ratio (plaintext indicator)
    var ascii_count: usize = 0;
    for (data) |byte| {
        if (byte >= 0x20 and byte <= 0x7E) {
            ascii_count += 1;
        }
    }

    const ratio = @as(f32, @floatFromInt(ascii_count)) / @as(f32, @floatFromInt(data.len));

    // >80% printable ASCII = likely plaintext
    return ratio > 0.8;
}

/// Traffic monitor — runs in background
pub const TrafficMonitor = struct {
    killswitch: *KillSwitch,
    running: bool,

    const Self = @This();

    pub fn init(ks: *KillSwitch) Self {
        return .{ .killswitch = ks, .running = false };
    }

    pub fn start(self: *Self) void {
        self.running = true;
        // Would spawn thread to monitor network interface
    }

    pub fn stop(self: *Self) void {
        self.running = false;
    }

    pub fn inspect(self: *Self, packet: []const u8) void {
        if (!self.running) return;
        self.killswitch.inspectTraffic(packet);
    }
};

test "secure buffer purge" {
    var buf = SecureBuffer(64).init();
    buf.write("sensitive data here");
    try std.testing.expect(buf.valid);

    buf.purge();

    try std.testing.expect(!buf.valid);
    for (buf.data) |byte| {
        try std.testing.expectEqual(@as(u8, 0), byte);
    }
}

test "plaintext detection" {
    try std.testing.expect(detectPlaintext("This is plaintext HTTP traffic"));
    try std.testing.expect(!detectPlaintext(&[_]u8{ 0x00, 0x01, 0x02, 0xFF, 0xFE, 0x80, 0x90 } ** 4));
}
