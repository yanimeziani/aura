//! Lint report: addFinding, writeToFile. Ziggy compiler — Zig 0.15.2.
//! See docs/ziggy-compiler.md "Lint report artifact format".

const std = @import("std");

pub const Severity = enum { err, warn, alarm };

const Finding = struct { file: []const u8, line: u32, col: u32, severity: Severity, rule_id: []const u8, message: []const u8 };

pub const LintReport = struct {
    findings: std.array_list.Managed(Finding),
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator) LintReport {
        return .{
            .findings = std.array_list.Managed(Finding).init(allocator),
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *LintReport) void {
        for (self.findings.items) |*f| {
            self.allocator.free(f.file);
            self.allocator.free(f.rule_id);
            self.allocator.free(f.message);
        }
        self.findings.deinit();
    }

    pub fn addFinding(self: *LintReport, file: []const u8, line: u32, col: u32, severity: Severity, rule_id: []const u8, message: []const u8) !void {
        try self.findings.append(.{
            .file = try self.allocator.dupe(u8, file),
            .line = line,
            .col = col,
            .severity = severity,
            .rule_id = try self.allocator.dupe(u8, rule_id),
            .message = try self.allocator.dupe(u8, message),
        });
    }

    fn escapeJsonString(self: *LintReport, f: anytype, s: []const u8) !void {
        _ = self;
        try f.writeAll("\"");
        for (s) |c| {
            switch (c) {
                '\\' => try f.writeAll("\\\\"),
                '"' => try f.writeAll("\\\""),
                '\n' => try f.writeAll("\\n"),
                '\r' => try f.writeAll("\\r"),
                '\t' => try f.writeAll("\\t"),
                else => {
                    var b: [1]u8 = .{c};
                    try f.writeAll(&b);
                },
            }
        }
        try f.writeAll("\"");
    }

    /// Write one JSON object per line (JSON Lines) to path.
    pub fn writeToFile(self: *LintReport, path: []const u8) !void {
        var f = try std.fs.cwd().createFile(path, .{});
        defer f.close();
        for (self.findings.items) |finding| {
            try f.writeAll("{\"file\":");
            try self.escapeJsonString(&f, finding.file);
            var buf: [256]u8 = undefined;
            const mid = std.fmt.bufPrint(&buf, ",\"line\":{},\"col\":{},\"severity\":\"{s}\",\"rule_id\":", .{ finding.line, finding.col, @tagName(finding.severity) }) catch ",\"line\":0,\"col\":0,\"severity\":\"warn\",\"rule_id\":";
            try f.writeAll(mid);
            try self.escapeJsonString(&f, finding.rule_id);
            try f.writeAll(",\"message\":");
            try self.escapeJsonString(&f, finding.message);
            try f.writeAll("}\n");
        }
    }
};
