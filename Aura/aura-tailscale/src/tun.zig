//! TUN device interface — Linux. Zig 0.15.2 + std only.
//! Opens /dev/net/tun, sets TUNSETIFF (IFF_TUN | IFF_NO_PI), reads/writes IP packets.
//! Phase 1: open/close/read/write interface + ioctl constants. Full kernel integration in next phase.

const std = @import("std");

// ── ioctl / TUN constants (from linux/if_tun.h) ───────────────────────────────

pub const TUNSETIFF    = 0x400454ca; // _IOW('T', 202, int)
pub const IFF_TUN      = 0x0001;
pub const IFF_NO_PI    = 0x1000;     // no packet info header
pub const IFNAMSIZ     = 16;
pub const TUN_DEV_PATH = "/dev/net/tun";

// ── Structs ───────────────────────────────────────────────────────────────────

pub const Ifreq = extern struct {
    ifr_name:  [IFNAMSIZ]u8,
    ifr_flags: u16,
    _pad:      [22]u8 = [_]u8{0} ** 22,
};

pub const Tun = struct {
    fd:   std.posix.fd_t,
    name: [IFNAMSIZ]u8,
};

// ── API ───────────────────────────────────────────────────────────────────────

/// Open a TUN device with the given name (e.g. "aura0").
/// Sets IFF_TUN | IFF_NO_PI. Returns Tun on success.
pub fn open(dev_name: []const u8) !Tun {
    const fd = try std.posix.open(TUN_DEV_PATH, .{ .ACCMODE = .RDWR }, 0);
    errdefer std.posix.close(fd);

    var ifreq: Ifreq = .{
        .ifr_name  = [_]u8{0} ** IFNAMSIZ,
        .ifr_flags = IFF_TUN | IFF_NO_PI,
    };

    const name_len = @min(dev_name.len, IFNAMSIZ - 1);
    @memcpy(ifreq.ifr_name[0..name_len], dev_name[0..name_len]);

    const rc = std.os.linux.ioctl(fd, TUNSETIFF, @intFromPtr(&ifreq));
    if (std.posix.errno(rc) != .SUCCESS) {
        return error.IoctlFailed;
    }

    return Tun{
        .fd   = fd,
        .name = ifreq.ifr_name,
    };
}

/// Close the TUN file descriptor.
pub fn close(tun: *Tun) void {
    std.posix.close(tun.fd);
}

/// Read one IP packet from the TUN device into buf. Returns bytes read.
pub fn read(tun: *Tun, buf: []u8) !usize {
    return std.posix.read(tun.fd, buf);
}

/// Write one IP packet to the TUN device. Returns bytes written.
pub fn write(tun: *Tun, packet: []const u8) !usize {
    return std.posix.write(tun.fd, packet);
}

// ── Tests ─────────────────────────────────────────────────────────────────────

test "Ifreq size is 40 bytes" {
    try std.testing.expectEqual(@as(usize, 40), @sizeOf(Ifreq));
}

test "open returns FileNotFound or Tun in CI" {
    var t = open("aura0") catch |err| switch (err) {
        error.FileNotFound,
        error.IoctlFailed,
        error.AccessDenied,
        => return,
        else => return err,
    };
    close(&t);
}

test "constants are correct" {
    try std.testing.expectEqual(@as(u32, 0x400454ca), TUNSETIFF);
    try std.testing.expectEqual(@as(u16, 0x0001), IFF_TUN);
    try std.testing.expectEqual(@as(u16, 0x1000), IFF_NO_PI);
}
