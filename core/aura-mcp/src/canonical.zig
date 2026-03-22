const std = @import("std");

pub const CanonicalFile = struct {
    path: []const u8,
    content: []const u8,
};

pub const Framework = struct {
    allocator: std.mem.Allocator,
    files: std.ArrayListUnmanaged(CanonicalFile),

    pub fn init(allocator: std.mem.Allocator) Framework {
        return .{
            .allocator = allocator,
            .files = .empty,
        };
    }

    pub fn deinit(self: *Framework) void {
        for (self.files.items) |file| {
            self.allocator.free(file.path);
            self.allocator.free(file.content);
        }
        self.files.deinit(self.allocator);
    }

    pub fn loadFromManifest(self: *Framework, root_path: []const u8) !void {
        const manifest_path = try std.fs.path.join(self.allocator, &.{ root_path, "docs/RAG_CORPUS_MANIFEST.md" });
        defer self.allocator.free(manifest_path);

        const manifest_content = try std.fs.cwd().readFileAlloc(self.allocator, manifest_path, 1024 * 1024);
        defer self.allocator.free(manifest_content);

        var lines = std.mem.splitScalar(u8, manifest_content, '\n');
        var in_docs_set = false;
        var in_root_boundary = false;

        while (lines.next()) |line| {
            const trimmed = std.mem.trim(u8, line, " \t\r");
            if (std.mem.startsWith(u8, trimmed, "## 2) Canonical Docs Set")) {
                in_docs_set = true;
                in_root_boundary = false;
                continue;
            }
            if (std.mem.startsWith(u8, trimmed, "## 5) Root Markdown Boundary")) {
                in_docs_set = false;
                in_root_boundary = true;
                continue;
            }
            if (std.mem.startsWith(u8, trimmed, "##")) {
                in_docs_set = false;
                in_root_boundary = false;
                continue;
            }

            if (in_docs_set or in_root_boundary) {
                if (std.mem.startsWith(u8, trimmed, "- `")) {
                    const start = std.mem.indexOf(u8, trimmed, "`").? + 1;
                    const end = std.mem.lastIndexOf(u8, trimmed, "`").?;
                    const rel_path = trimmed[start..end];
                    
                    const full_path = try std.fs.path.join(self.allocator, &.{ root_path, rel_path });
                    defer self.allocator.free(full_path);

                    const content = std.fs.cwd().readFileAlloc(self.allocator, full_path, 1024 * 1024) catch |err| {
                        std.debug.print("Warning: could not read canonical file {s}: {s}\n", .{ rel_path, @errorName(err) });
                        continue;
                    };

                    try self.files.append(self.allocator, .{
                        .path = try self.allocator.dupe(u8, rel_path),
                        .content = content,
                    });
                }
            }
        }
    }

    pub fn formatForAI(self: Framework, writer: anytype) !void {
        try writer.writeAll("<canonical_framework>\n");
        for (self.files.items) |file| {
            try writer.print("  <file path=\"{s}\">\n", .{file.path});
            try writer.writeAll(file.content);
            if (!std.mem.endsWith(u8, file.content, "\n")) try writer.writeAll("\n");
            try writer.writeAll("  </file>\n");
        }
        try writer.writeAll("</canonical_framework>\n");
    }
};
