//! Semantic analysis — ziggy-compiler. Zig 0.15.2.
//! Type resolution and checking.

const std = @import("std");
const parse = @import("parse.zig");

pub const Sema = struct {
    allocator: std.mem.Allocator,
    pub fn init(allocator: std.mem.Allocator) Sema { return .{ .allocator = allocator }; }
    pub fn check(self: *Sema, ast: *const parse.Ast) !void { _ = self; _ = ast; }
};
