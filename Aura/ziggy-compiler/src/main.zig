//! Ziggy compiler — our own. Zig 0.15.2.

const std = @import("std");
const alarms = @import("alarms.zig");
const artifacts = @import("artifacts.zig");
const ast_dump = @import("dump.zig");
const lex = @import("lex.zig");
const lint = @import("lint.zig");
const parse = @import("parse.zig");

const Version = "0.1.0";

const Mode = enum {
    compile,
    lint_only,
    dump_ast,
};

fn logPhase(phase: []const u8, name: []const u8) void {
    std.debug.print("level=progress phase={s} name={s}\n", .{ phase, name });
}

fn showUsage() void {
    std.debug.print(
        "ziggyc — Ziggy compiler\nUsage: ziggyc [--version] [--dump-ast <file>] [--lint-only <file>] <file>\n",
        .{},
    );
}

fn readSource(allocator: std.mem.Allocator, path: []const u8) ![]u8 {
    logPhase("start", "read");
    const source = std.fs.cwd().readFileAlloc(allocator, path, 1024 * 1024) catch |err| {
        logPhase("error", "read");
        var buf = std.array_list.Managed(u8).init(allocator);
        defer buf.deinit();
        alarms.emitAlarm(buf.writer(), .syntax, @errorName(err)) catch {};
        std.debug.print("{s}", .{buf.items});
        return err;
    };
    logPhase("end", "read");
    return source;
}

fn writeLintStub(allocator: std.mem.Allocator, source_path: []const u8) !void {
    logPhase("start", "lint");
    try artifacts.ensureOutDir(allocator, "out");

    var report = lint.LintReport.init(allocator);
    defer report.deinit();

    if (std.mem.endsWith(u8, source_path, ".zig")) {
        try report.addFinding(source_path, 1, 1, .warn, "stub.lint", "lint pipeline stub active");
    }

    try report.writeToFile("out/lint/report.jsonl");
    logPhase("end", "lint");
}

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var args = try std.process.argsWithAllocator(allocator);
    defer args.deinit();
    _ = args.next();

    const first = args.next() orelse {
        std.debug.print("ziggyc: no input provided\n", .{});
        showUsage();
        return;
    };

    if (std.mem.eql(u8, first, "--version")) {
        std.debug.print("ziggyc {s}\n", .{Version});
        return;
    }

    var mode: Mode = .compile;
    var source_path = first;

    if (std.mem.eql(u8, first, "--lint-only")) {
        mode = .lint_only;
        source_path = args.next() orelse {
            showUsage();
            return;
        };
    } else if (std.mem.eql(u8, first, "--dump-ast")) {
        mode = .dump_ast;
        source_path = args.next() orelse {
            showUsage();
            return;
        };
    }

    const source = try readSource(allocator, source_path);
    defer allocator.free(source);

    if (mode == .lint_only) {
        try writeLintStub(allocator, source_path);
        return;
    }

    logPhase("start", "lex");
    const tokens = try lex.tokenize(allocator, source);
    defer allocator.free(tokens);
    logPhase("end", "lex");

    logPhase("start", "parse");
    var ast = try parse.parse(allocator, tokens, source);
    defer ast.deinit(allocator);
    logPhase("end", "parse");

    if (mode == .dump_ast) {
        var buf = std.array_list.Managed(u8).init(allocator);
        defer buf.deinit();
        try ast_dump.dumpAst(&ast, buf.writer());
        std.debug.print("{s}", .{buf.items});
        return;
    }

    std.debug.print("ziggyc: parsed {d} nodes\n", .{ast.nodes.len});
}
