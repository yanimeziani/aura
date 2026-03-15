//! Semantic analysis — ziggy-compiler. Zig 0.15.2.
//! Phase 1: top-level declaration collection + duplicate detection.
//! Phase 2: basic undeclared identifier detection in function bodies.

const std = @import("std");
const parse = @import("parse.zig");
const lex = @import("lex.zig");

pub const SemaError = struct {
    message: []const u8, // caller-owned; freed by Sema.deinit
    node_idx: parse.NodeIndex,
};

pub const Sema = struct {
    allocator: std.mem.Allocator,
    errors: std.ArrayList(SemaError),

    pub fn init(allocator: std.mem.Allocator) Sema {
        return .{
            .allocator = allocator,
            .errors = std.ArrayList(SemaError).init(allocator),
        };
    }

    pub fn deinit(self: *Sema) void {
        for (self.errors.items) |e| self.allocator.free(e.message);
        self.errors.deinit();
    }

    pub fn check(self: *Sema, ast: *const parse.Ast) !void {
        if (ast.nodes.len == 0) return;
        const root = &ast.nodes[ast.nodes.len - 1];
        if (root.kind != .file) return;

        const start = root.data[0];
        const len = root.data[1];
        const top_children = ast.children[start .. start + len];

        // Phase 1: collect top-level declaration names and detect duplicates.
        var decls = std.StringHashMap(parse.NodeIndex).init(self.allocator);
        defer decls.deinit();

        for (top_children) |idx| {
            if (idx >= ast.nodes.len) continue;
            const node = &ast.nodes[idx];
            const name_opt = self.nodeName(ast, node);
            const name = name_opt orelse continue;

            if (decls.get(name)) |_| {
                const msg = try std.fmt.allocPrint(
                    self.allocator,
                    "duplicate top-level declaration: '{s}'",
                    .{name},
                );
                try self.errors.append(.{ .message = msg, .node_idx = idx });
            } else {
                try decls.put(name, idx);
            }
        }

        // Phase 2: walk function bodies and check that identifiers resolve to
        // something known (top-level decls or block-local names).
        for (top_children) |idx| {
            if (idx >= ast.nodes.len) continue;
            const node = &ast.nodes[idx];
            if (node.kind != .fn_decl) continue;
            try self.checkBlock(ast, node.data[1], &decls);
        }
    }

    pub fn hasErrors(self: *const Sema) bool {
        return self.errors.items.len > 0;
    }

    // ── Internal helpers ─────────────────────────────────────────────────────

    /// Return the source name of a declaration node, or null if not a named decl.
    fn nodeName(self: *Sema, ast: *const parse.Ast, node: *const parse.Node) ?[]const u8 {
        _ = self;
        switch (node.kind) {
            .fn_decl, .const_decl, .var_decl => {
                const name_tok_idx = node.data[0];
                if (name_tok_idx >= ast.tokens.len) return null;
                const tok = ast.tokens[name_tok_idx];
                if (tok.start >= ast.source.len or tok.end > ast.source.len) return null;
                return ast.source[tok.start..tok.end];
            },
            else => return null,
        }
    }

    /// Recursively walk a block's children, checking identifiers against known.
    fn checkBlock(
        self: *Sema,
        ast: *const parse.Ast,
        block_idx: parse.NodeIndex,
        known: *std.StringHashMap(parse.NodeIndex),
    ) !void {
        if (block_idx == parse.NULL_NODE or block_idx >= ast.nodes.len) return;
        const blk = &ast.nodes[block_idx];
        if (blk.kind != .block) return;

        // Collect local const/var names declared in this block.
        var local = std.StringHashMap(parse.NodeIndex).init(self.allocator);
        defer local.deinit();

        const start = blk.data[0];
        const len = blk.data[1];
        for (ast.children[start .. start + len]) |idx| {
            if (idx >= ast.nodes.len) continue;
            const child = &ast.nodes[idx];
            if (child.kind == .const_decl or child.kind == .var_decl) {
                if (self.nodeName(ast, child)) |name| try local.put(name, idx);
            }
        }

        // Check each child expression.
        for (ast.children[start .. start + len]) |idx| {
            if (idx >= ast.nodes.len) continue;
            try self.checkExpr(ast, idx, known, &local);
        }
    }

    fn checkExpr(
        self: *Sema,
        ast: *const parse.Ast,
        idx: parse.NodeIndex,
        known: *std.StringHashMap(parse.NodeIndex),
        local: *std.StringHashMap(parse.NodeIndex),
    ) !void {
        if (idx == parse.NULL_NODE or idx >= ast.nodes.len) return;
        const node = &ast.nodes[idx];
        switch (node.kind) {
            .identifier => {
                const tok_idx = node.tok_start;
                if (tok_idx >= ast.tokens.len) return;
                const tok = ast.tokens[tok_idx];
                if (tok.start >= ast.source.len or tok.end > ast.source.len) return;
                const name = ast.source[tok.start..tok.end];
                // Allow built-in keywords that appear as identifiers and common builtins.
                if (isBuiltin(name)) return;
                if (known.contains(name) or local.contains(name)) return;
                const msg = try std.fmt.allocPrint(
                    self.allocator,
                    "undeclared identifier: '{s}'",
                    .{name},
                );
                try self.errors.append(.{ .message = msg, .node_idx = idx });
            },
            .binary_expr, .postfix_expr => {
                try self.checkExpr(ast, node.data[0], known, local);
                try self.checkExpr(ast, node.data[1], known, local);
            },
            .unary_expr => {
                try self.checkExpr(ast, node.data[0], known, local);
            },
            .if_expr => {
                try self.checkExpr(ast, node.data[0], known, local);
                try self.checkExpr(ast, node.data[1], known, local);
            },
            .while_expr, .for_expr => {
                try self.checkExpr(ast, node.data[0], known, local);
                try self.checkExpr(ast, node.data[1], known, local);
            },
            .block => try self.checkBlock(ast, idx, known),
            else => {},
        }
    }

    fn isBuiltin(name: []const u8) bool {
        const builtins = [_][]const u8{
            "void", "bool", "u8", "u16", "u32", "u64", "usize",
            "i8", "i16", "i32", "i64", "isize", "f32", "f64",
            "true", "false", "null", "undefined", "comptime",
            "std", "mem", "math", "fmt", "io", "fs", "os",
            "self", "Self", "allocator",
        };
        for (builtins) |b| {
            if (std.mem.eql(u8, name, b)) return true;
        }
        return false;
    }
};

// ── Tests ─────────────────────────────────────────────────────────────────────

test "sema: no errors on empty file" {
    const a = std.testing.allocator;
    const src = "";
    const tokens = try lex.tokenize(a, src);
    defer a.free(tokens);
    var ast = try parse.parse(a, tokens, src);
    defer ast.deinit(a);
    var s = Sema.init(a);
    defer s.deinit();
    try s.check(&ast);
    try std.testing.expect(!s.hasErrors());
}

test "sema: two distinct fn decls, no errors" {
    const a = std.testing.allocator;
    const src = "fn foo() void {} fn bar() void {}";
    const tokens = try lex.tokenize(a, src);
    defer a.free(tokens);
    var ast = try parse.parse(a, tokens, src);
    defer ast.deinit(a);
    var s = Sema.init(a);
    defer s.deinit();
    try s.check(&ast);
    try std.testing.expect(!s.hasErrors());
}

test "sema: duplicate fn decl is detected" {
    const a = std.testing.allocator;
    const src = "fn foo() void {} fn foo() void {}";
    const tokens = try lex.tokenize(a, src);
    defer a.free(tokens);
    var ast = try parse.parse(a, tokens, src);
    defer ast.deinit(a);
    var s = Sema.init(a);
    defer s.deinit();
    try s.check(&ast);
    try std.testing.expect(s.hasErrors());
    try std.testing.expect(std.mem.indexOf(u8, s.errors.items[0].message, "duplicate") != null);
}
