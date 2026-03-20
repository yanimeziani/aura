//! Scanner for aura-sync. Zig 0.15.2 + std only.
//! Recursively walks a directory and hashes files.

const std = @import("std");
const crypto = std.crypto;

pub const FileInfo = struct {
    path: []const u8,
    hash: [32]u8,
    mtime: i128,
    size: u64,

    pub fn deinit(self: FileInfo, allocator: std.mem.Allocator) void {
        allocator.free(self.path);
    }
};

pub const Manifest = struct {
    files: []FileInfo,

    pub fn deinit(self: Manifest, allocator: std.mem.Allocator) void {
        for (self.files) |file| {
            file.deinit(allocator);
        }
        allocator.free(self.files);
    }
};

/// Scan the given directory (absolute path) and return a Manifest.
pub fn scan(allocator: std.mem.Allocator, root_path: []const u8) !Manifest {
    var files: std.ArrayList(FileInfo) = .empty;
    errdefer {
        for (files.items) |f| f.deinit(allocator);
        files.deinit(allocator);
    }

    var dir = try std.fs.openDirAbsolute(root_path, .{ .iterate = true });
    defer dir.close();

    var walker = try dir.walk(allocator);
    defer walker.deinit();

    while (try walker.next()) |entry| {
        if (entry.kind != .file) continue;

        const path = try allocator.dupe(u8, entry.path);
        errdefer allocator.free(path);

        const stat = try entry.dir.statFile(entry.basename);
        
        // Hash the file
        var hash_buf: [32]u8 = undefined;
        try hashFile(entry.dir, entry.basename, &hash_buf);

        try files.append(allocator, .{
            .path = path,
            .hash = hash_buf,
            .mtime = stat.mtime,
            .size = stat.size,
        });
    }

    return Manifest{
        .files = try files.toOwnedSlice(allocator),
    };
}

fn hashFile(dir: std.fs.Dir, basename: []const u8, out: *[32]u8) !void {
    const file = try dir.openFile(basename, .{});
    defer file.close();

    var h = crypto.hash.blake2.Blake2s256.init(.{});
    var buf: [64 * 1024]u8 = undefined;
    while (true) {
        const n = try file.read(&buf);
        if (n == 0) break;
        h.update(buf[0..n]);
    }
    h.final(out);
}
