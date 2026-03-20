//! Sync engine for aura-sync. Zig 0.15.2 + std only.
//! Compare local and remote manifests, determine actions.

const std = @import("std");
const scanner = @import("scanner.zig");

pub const Action = union(enum) {
    download: scanner.FileInfo,
    upload: scanner.FileInfo,
    delete: []const u8, // relative path
    noop: []const u8,
};

pub fn compare(allocator: std.mem.Allocator, local: scanner.Manifest, remote: scanner.Manifest) ![]Action {
    var actions: std.ArrayList(Action) = .empty;
    errdefer actions.deinit(allocator);

    var local_map = std.StringHashMap(scanner.FileInfo).init(allocator);
    defer local_map.deinit();
    for (local.files) |f| try local_map.put(f.path, f);

    var remote_map = std.StringHashMap(scanner.FileInfo).init(allocator);
    defer remote_map.deinit();
    for (remote.files) |f| try remote_map.put(f.path, f);

    // Identify downloads and updates from remote
    for (remote.files) |rf| {
        if (local_map.get(rf.path)) |lf| {
            if (!std.mem.eql(u8, &lf.hash, &rf.hash)) {
                // Conflict resolution: latest mtime wins (simple fashion)
                if (rf.mtime > lf.mtime) {
                    try actions.append(allocator, .{ .download = rf });
                } else {
                    try actions.append(allocator, .{ .upload = lf });
                }
            } else {
                try actions.append(allocator, .{ .noop = rf.path });
            }
        } else {
            // Not in local, download
            try actions.append(allocator, .{ .download = rf });
        }
    }

    // Identify uploads or deletes (local files not in remote)
    var it = local_map.iterator();
    while (it.next()) |entry| {
        const lp = entry.key_ptr.*;
        const lf = entry.value_ptr.*;
        if (!remote_map.contains(lp)) {
            // Local file not in remote. 
            // In a real Syncthing, we'd know if it was deleted or newly created.
            // For "our fashion" simple v1, we assume it needs to be uploaded.
            try actions.append(allocator, .{ .upload = lf });
        }
    }

    return try actions.toOwnedSlice(allocator);
}
