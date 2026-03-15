const std = @import("std");

pub const ResearchRenderer = struct {
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator) ResearchRenderer {
        return .{ .allocator = allocator };
    }

    pub fn renderManifesto(self: *ResearchRenderer, source_path: []const u8, out_path: []const u8) !void {
        const source = try std.fs.cwd().readFileAlloc(self.allocator, source_path, 1024 * 1024);
        defer self.allocator.free(source);

        const file = try std.fs.cwd().createFile(out_path, .{});
        defer file.close();

        try file.writeAll("%%PDF-1.4\n");
        try file.writeAll("%%\xE2\xE3\xCF\xD3\n");
        try file.writeAll("1 0 obj\n<< /Type /Catalog /Pages 2 0 R >>\nendobj\n");
        try file.writeAll("2 0 obj\n<< /Type /Pages /Kids [3 0 R] /Count 1 >>\nendobj\n");
        try file.writeAll("3 0 obj\n<< /Type /Page /Parent 2 0 R /MediaBox [0 0 612 792] /Contents 4 0 R /Resources << /Font << /F1 5 0 R >> >> >>\nendobj\n");

        const text = "Aura: Sovereign AI Research - aura.meziani.org";
        const content = try std.fmt.allocPrint(self.allocator, "BT /F1 24 Tf 50 700 Td ({s}) Tj ET", .{text});
        defer self.allocator.free(content);
        
        var stream_header: [64]u8 = undefined;
        const header = try std.fmt.bufPrint(&stream_header, "4 0 obj\n<< /Length {d} >>\nstream\n", .{content.len});
        try file.writeAll(header);
        try file.writeAll(content);
        try file.writeAll("\nendstream\nendobj\n");

        try file.writeAll("5 0 obj\n<< /Type /Font /Subtype /Type1 /BaseFont /Helvetica >>\nendobj\n");
        try file.writeAll("xref\n0 6\n0000000000 65535 f \n");
        try file.writeAll("trailer\n<< /Size 6 /Root 1 0 R >>\nstartxref\n450\n%%EOF\n");
    }
};
