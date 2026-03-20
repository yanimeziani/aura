//! aura-sync — Syncthing equivalent in our fashion our zig.
//! Zig 0.15.2 + std only.

const std = @import("std");
const scanner = @import("scanner.zig");
const index = @import("index.zig");
const sync = @import("sync.zig");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const args = try std.process.argsAlloc(allocator);
    defer std.process.argsFree(allocator, args);

    if (args.len < 2) {
        usage();
        return;
    }

    const cmd = args[1];
    if (std.mem.eql(u8, cmd, "scan")) {
        if (args.len < 3) return usage();
        const root = args[2];
        var manifest = try scanner.scan(allocator, root);
        errdefer manifest.deinit(allocator);

        const idx_path = try getIndexLeaf(allocator);
        defer allocator.free(idx_path);
        
        var idx = try index.Index.load(allocator, idx_path);
        defer idx.deinit();
        
        idx.manifest.deinit(allocator); // Clean up old manifest
        idx.manifest = manifest; // Take ownership
        
        try idx.save();
        std.debug.print("Scanned {d} files. Index saved to {s}\n", .{ idx.manifest.files.len, idx_path });
    } else if (std.mem.eql(u8, cmd, "status")) {
        const idx_path = try getIndexLeaf(allocator);
        defer allocator.free(idx_path);
        const idx = try index.Index.load(allocator, idx_path);
        defer idx.deinit();
        std.debug.print("Index: {s}\nFiles: {d}\n", .{ idx_path, idx.manifest.files.len });
        for (idx.manifest.files) |f| {
            std.debug.print("  {s} ({d} bytes, {x})\n", .{ f.path, f.size, f.hash });
        }
    } else if (std.mem.eql(u8, cmd, "daemon")) {
        if (args.len < 3) return usage();
        const root = args[2];
        std.debug.print("aura-sync daemon starting on {s}...\n", .{root});
        while (true) {
            var manifest = try scanner.scan(allocator, root);
            errdefer manifest.deinit(allocator);
            
            const idx_path = try getIndexLeaf(allocator);
            defer allocator.free(idx_path);
            var idx = try index.Index.load(allocator, idx_path);
            defer idx.deinit();
            
            idx.manifest.deinit(allocator);
            idx.manifest = manifest;
            
            try idx.save();
            
            std.debug.print("[{d}] Scanned {d} files.\n", .{ std.time.timestamp(), idx.manifest.files.len });
            std.Thread.sleep(std.time.ns_per_s * 60);
        }
    } else {
        usage();
    }
}

fn usage() void {
    std.debug.print("aura-sync — Syncthing equivalent in our fashion\n", .{});
    std.debug.print("Usage: aura-sync <command> [args]\n", .{});
    std.debug.print("Commands:\n", .{});
    std.debug.print("  scan <path>    Scan directory and update index\n", .{});
    std.debug.print("  status         Show current index status\n", .{});
    std.debug.print("  daemon <path>  Run continuous scan every 60s\n", .{});
}

fn getIndexLeaf(allocator: std.mem.Allocator) ![]u8 {
    const root = std.posix.getenv("AURA_ROOT") orelse "/opt/aura";
    const dir = try std.fmt.allocPrint(allocator, "{s}/var/aura-sync", .{root});
    defer allocator.free(dir);
    
    // Ensure dir exists
    std.fs.makeDirAbsolute(dir) catch |e| switch (e) {
        error.PathAlreadyExists => {},
        else => return e,
    };
    
    return try std.fmt.allocPrint(allocator, "{s}/index.json", .{dir});
}
