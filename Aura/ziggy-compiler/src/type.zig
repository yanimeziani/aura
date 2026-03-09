//! Type system — Ziggy compiler. Zig 0.15.2.
//! Phase: type resolution.

const std = @import("std");
const parse = @import("parse.zig");

// ── TypeKind ──────────────────────────────────────────────────────────────────

pub const TypeKind = enum {
    void,
    bool,
    int,
    float,
    str,
    fn_type,
    unknown,
};

// ── Type ──────────────────────────────────────────────────────────────────────

pub const Type = struct {
    kind: TypeKind,
};

// ── Public API ────────────────────────────────────────────────────────────────

/// Resolve a primitive name (e.g. "i32", "bool") to its Type.
pub fn resolvePrimitive(name: []const u8) Type {
    if (std.mem.eql(u8, name, "void")) return .{ .kind = .void };
    if (std.mem.eql(u8, name, "bool")) return .{ .kind = .bool };
    if (std.mem.eql(u8, name, "str"))  return .{ .kind = .str };

    // Integer types: [iu][0-9]+
    if (name.len >= 2) {
        const first = name[0];
        if (first == 'i' or first == 'u') {
            var all_digits = true;
            for (name[1..]) |c| {
                if (!std.ascii.isDigit(c)) {
                    all_digits = false;
                    break;
                }
            }
            if (all_digits) return .{ .kind = .int };
        }
    }

    // Float types: f[0-9]+
    if (name.len >= 2 and name[0] == 'f') {
        var all_digits = true;
        for (name[1..]) |c| {
            if (!std.ascii.isDigit(c)) {
                all_digits = false;
                break;
            }
        }
        if (all_digits) return .{ .kind = .float };
    }

    return .{ .kind = .unknown };
}

/// Resolve the type of an AST node.
pub fn resolveType(ast: *const parse.Ast, node_idx: parse.NodeIndex) Type {
    if (node_idx >= ast.nodes.len) return .{ .kind = .unknown };
    const node = ast.nodes[node_idx];

    switch (node.kind) {
        .identifier => {
            const name = ast.nodeSlice(node);
            return resolvePrimitive(name);
        },
        .int_literal   => return .{ .kind = .int },
        .float_literal => return .{ .kind = .float },
        .str_literal   => return .{ .kind = .str },
        else => return .{ .kind = .unknown },
    }
}

// ── Tests ─────────────────────────────────────────────────────────────────────

test "resolvePrimitive: core types" {
    try std.testing.expectEqual(TypeKind.void, resolvePrimitive("void").kind);
    try std.testing.expectEqual(TypeKind.bool, resolvePrimitive("bool").kind);
    try std.testing.expectEqual(TypeKind.str,  resolvePrimitive("str").kind);
}

test "resolvePrimitive: integers" {
    try std.testing.expectEqual(TypeKind.int, resolvePrimitive("i32").kind);
    try std.testing.expectEqual(TypeKind.int, resolvePrimitive("u8").kind);
    try std.testing.expectEqual(TypeKind.int, resolvePrimitive("i64").kind);
    try std.testing.expectEqual(TypeKind.int, resolvePrimitive("u128").kind);
}

test "resolvePrimitive: floats" {
    try std.testing.expectEqual(TypeKind.float, resolvePrimitive("f32").kind);
    try std.testing.expectEqual(TypeKind.float, resolvePrimitive("f64").kind);
}

test "resolvePrimitive: unknown" {
    try std.testing.expectEqual(TypeKind.unknown, resolvePrimitive("MyType").kind);
    try std.testing.expectEqual(TypeKind.unknown, resolvePrimitive("").kind);
    try std.testing.expectEqual(TypeKind.unknown, resolvePrimitive("i").kind);
}
