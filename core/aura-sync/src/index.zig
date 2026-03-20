//! Index persistence for aura-sync. Zig 0.15.2 + std only.
//! Manifest is stored as a JSON file.

const std = @import("std");
const scanner = @import("scanner.zig");

pub const Index = struct {
    manifest: scanner.Manifest,
    path: []const u8,
    allocator: std.mem.Allocator,

    pub fn load(allocator: std.mem.Allocator, path: []const u8) !Index {
        const file = std.fs.openFileAbsolute(path, .{}) catch |e| switch (e) {
            error.FileNotFound => return Index{
                .manifest = .{ .files = &[_]scanner.FileInfo{} },
                .path = try allocator.dupe(u8, path),
                .allocator = allocator,
            },
            else => return e,
        };
        defer file.close();

        const data = try file.readToEndAlloc(allocator, 10 * 1024 * 1024);
        defer allocator.free(data);

        const parsed = try std.json.parseFromSlice(scanner.Manifest, allocator, data, .{
            .ignore_unknown_fields = true,
        });
        defer parsed.deinit();

        // Deep copy because parseFromSlice's result is owned by parsed.deinit()
        var files = try allocator.alloc(scanner.FileInfo, parsed.value.files.len);
        errdefer allocator.free(files);
        for (parsed.value.files, 0..) |f, i| {
            files[i] = .{
                .path = try allocator.dupe(u8, f.path),
                .hash = f.hash,
                .mtime = f.mtime,
                .size = f.size,
            };
        }

        return Index{
            .manifest = .{ .files = files },
            .path = try allocator.dupe(u8, path),
            .allocator = allocator,
        };
    }

    pub fn save(self: Index) !void {
        const tmp_path = try std.fmt.allocPrint(self.allocator, "{s}.tmp", .{self.path});
        defer self.allocator.free(tmp_path);

        const file = try std.fs.createFileAbsolute(tmp_path, .{ .truncate = true });
        defer file.close();

        // In Zig 0.15.2, stringify is replaced by std.json.fmt
        const json_data = try std.fmt.allocPrint(self.allocator, "{f}", .{std.json.fmt(self.manifest, .{ .whitespace = .indent_2 })});
        defer self.allocator.free(json_data);
        
        try file.writeAll(json_data);
        try std.fs.renameAbsolute(tmp_path, self.path);
    }

    pub fn deinit(self: Index) void {
        self.manifest.deinit(self.allocator);
        self.allocator.free(self.path);
    }
};
