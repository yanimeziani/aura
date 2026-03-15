//! AST dump — Ziggy compiler. Zig 0.15.2.
//! Prints the AST produced by parse.zig to a writer in indented tree form.
//! Used by --dump-ast CLI flag for debugging the parser.

const std = @import("std");
const parse = @import("parse.zig");
const lex   = @import("lex.zig");

const Ast       = parse.Ast;
const Node      = parse.Node;
const NodeKind  = parse.NodeKind;
const NodeIndex = parse.NodeIndex;

// ── Public API ────────────────────────────────────────────────────────────────

/// Dump the entire AST to `writer`. Prints a tree rooted at the file node.
pub fn dumpAst(ast: *const Ast, writer: anytype) !void {
    if (ast.nodes.len == 0) {
        try writer.writeAll("(empty ast)\n");
        return;
    }
    // Root is always the last node (parseFile appends it last).
    const root_idx: NodeIndex = @intCast(ast.nodes.len - 1);
    try dumpNode(ast, root_idx, 0, writer);
}

// ── Internal ──────────────────────────────────────────────────────────────────

fn dumpNode(ast: *const Ast, idx: NodeIndex, depth: u32, writer: anytype) !void {
    if (idx >= ast.nodes.len) return;
    const node = ast.nodes[idx];

    try writeIndent(writer, depth);
    try writer.print("[{s}]", .{@tagName(node.kind)});

    // Print source slice for leaf/named nodes.
    switch (node.kind) {
        .const_decl, .var_decl, .fn_decl, .test_decl => {
            if (node.data[0] < ast.tokens.len) {
                const name_tok = ast.tokens[node.data[0]];
                const name = name_tok.slice(ast.source);
                try writer.print(" name={s}", .{name});
            }
        },
        .identifier, .int_literal, .float_literal, .str_literal => {
            const s = ast.nodeSlice(node);
            try writer.print(" `{s}`", .{s});
        },
        .error_node => {
            const s = ast.nodeSlice(node);
            try writer.print(" ERR`{s}`", .{s});
        },
        else => {},
    }

    try writer.print("  toks=[{d},{d})\n", .{ node.tok_start, node.tok_end });

    // Recurse into children.
    switch (node.kind) {
        .file => {
            const child_start = node.data[0];
            const child_count = node.data[1];
            var i: u32 = 0;
            while (i < child_count) : (i += 1) {
                const child_idx_idx = child_start + i;
                if (child_idx_idx < ast.children.len) {
                    try dumpNode(ast, ast.children[child_idx_idx], depth + 1, writer);
                }
            }
        },
        .fn_decl, .test_decl => {
            // data[1] = body node index
            const body_idx = node.data[1];
            if (body_idx < ast.nodes.len) {
                try dumpNode(ast, body_idx, depth + 1, writer);
            }
        },
        else => {},
    }
}

fn writeIndent(writer: anytype, depth: u32) !void {
    var i: u32 = 0;
    while (i < depth) : (i += 1) try writer.writeAll("  ");
}

// ── Tests ─────────────────────────────────────────────────────────────────────

test "dump empty file produces output" {
    const a = std.testing.allocator;
    const tokens = try lex.tokenize(a, "");
    defer a.free(tokens);
    var ast = try parse.parse(a, tokens, "");
    defer ast.deinit(a);

    var buf = std.array_list.Managed(u8).init(a);
    defer buf.deinit();
    try dumpAst(&ast, buf.writer());
    try std.testing.expect(buf.items.len > 0);
    try std.testing.expect(std.mem.indexOf(u8, buf.items, "file") != null);
}

test "dump fn_decl shows name" {
    const a = std.testing.allocator;
    const src = "pub fn hello() void {}";
    const tokens = try lex.tokenize(a, src);
    defer a.free(tokens);
    var ast = try parse.parse(a, tokens, src);
    defer ast.deinit(a);

    var buf = std.array_list.Managed(u8).init(a);
    defer buf.deinit();
    try dumpAst(&ast, buf.writer());
    try std.testing.expect(std.mem.indexOf(u8, buf.items, "fn_decl") != null);
    try std.testing.expect(std.mem.indexOf(u8, buf.items, "hello") != null);
}
