//! Ziggy compiler — our own. Zig 0.15.2.

const std = @import("std");
const lex = @import("lex.zig");
const parse = @import("parse.zig");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var args = try std.process.argsWithAllocator(allocator);
    defer args.deinit();
    _ = args.next();

    const arg = args.next() orelse {
        std.debug.print("Usage: ziggyc <file>\n", .{});
        return;
    };

    const source = try std.fs.cwd().readFileAlloc(allocator, arg, 1024 * 1024);
    defer allocator.free(source);

    const tokens = try lex.tokenize(allocator, source);
    defer allocator.free(tokens);

    var ast = try parse.parse(allocator, tokens, source);
    defer ast.deinit(allocator);

    std.debug.print("ziggyc: parsed {d} nodes\n", .{ast.nodes.len});
}
