//! AST to IR Lowering — Ziggy compiler.
//! Phase 1: fn_decl lowering with per-function symbol table.

const std = @import("std");
const parse = @import("parse.zig");
const ir = @import("ir.zig");

pub const Lowerer = struct {
    allocator: std.mem.Allocator,
    ast: *const parse.Ast,
    module: ir.IrModule,
    current_fn: ?*ir.IrFunction = null,
    current_blk: ?*ir.BasicBlock = null,
    /// Maps identifier name → virtual register Value for the current function scope.
    symbol_table: std.StringHashMap(ir.Value),

    pub fn init(allocator: std.mem.Allocator, ast: *const parse.Ast) Lowerer {
        return .{
            .allocator = allocator,
            .ast = ast,
            .module = ir.IrModule.init(allocator),
            .symbol_table = std.StringHashMap(ir.Value).init(allocator),
        };
    }

    pub fn deinit(self: *Lowerer) void {
        self.symbol_table.deinit();
        self.module.deinit(self.allocator);
    }

    pub fn lower(self: *Lowerer) !*ir.IrModule {
        const root = &self.ast.nodes[self.ast.nodes.len - 1];
        if (root.kind != .file) return error.InvalidAst;
        const start = root.data[0];
        const len = root.data[1];
        for (self.ast.children[start .. start + len]) |idx| {
            const node = self.ast.nodes[idx];
            if (node.kind == .fn_decl) try self.lowerFn(idx);
        }
        return &self.module;
    }

    fn lowerFn(self: *Lowerer, idx: parse.NodeIndex) !void {
        const node = self.ast.nodes[idx];
        const name = self.ast.nodeSlice(self.ast.nodes[node.data[0]]);
        var ir_fn = try ir.IrFunction.init(self.allocator, name);
        try self.module.functions.append(ir_fn);
        self.current_fn = &self.module.functions.items[self.module.functions.items.len - 1];

        // Clear symbol table for this function's scope.
        self.symbol_table.clearRetainingCapacity();

        const entry = try self.addBlock();
        self.current_blk = entry;
        try self.lowerBlock(node.data[1]);
        if (self.current_blk.?.terminator == .unreachable) {
            self.current_blk.?.terminator = .{ .ret = .none };
        }
    }

    fn addBlock(self: *Lowerer) !*ir.BasicBlock {
        const idx: u32 = @intCast(self.current_fn.?.blocks.items.len);
        try self.current_fn.?.blocks.append(ir.BasicBlock.init(self.allocator, idx));
        return &self.current_fn.?.blocks.items[idx];
    }

    fn lowerBlock(self: *Lowerer, idx: parse.NodeIndex) !void {
        if (idx == parse.NULL_NODE) return;
        const node = self.ast.nodes[idx];
        const start = node.data[0];
        const len = node.data[1];
        for (self.ast.children[start .. start + len]) |child_idx| {
            _ = try self.lowerExpr(child_idx);
        }
    }

    fn lowerExpr(self: *Lowerer, idx: parse.NodeIndex) !ir.Value {
        if (idx == parse.NULL_NODE or idx >= self.ast.nodes.len) return .none;
        const node = self.ast.nodes[idx];
        switch (node.kind) {
            .int_literal => {
                const val = std.fmt.parseInt(i64, self.ast.nodeSlice(node), 10) catch 0;
                return .{ .imm_int = val };
            },
            .binary_expr => {
                const lhs = try self.lowerExpr(node.data[0]);
                const rhs = try self.lowerExpr(node.data[1]);
                const dest = self.current_fn.?.nextVreg();
                try self.current_blk.?.instructions.append(.{ .op = .add, .dest = dest, .src1 = lhs, .src2 = rhs });
                return dest;
            },
            .const_decl, .var_decl => {
                // Allocate a vreg for this name and register it in the symbol table.
                const name_tok_idx = node.data[0];
                const dest = self.current_fn.?.nextVreg();
                if (name_tok_idx < self.ast.tokens.len) {
                    const tok = self.ast.tokens[name_tok_idx];
                    if (tok.start < self.ast.source.len and tok.end <= self.ast.source.len) {
                        const name = self.ast.source[tok.start..tok.end];
                        try self.symbol_table.put(name, dest);
                    }
                }
                return dest;
            },
            .identifier => {
                // Look up in symbol table; fall back gracefully for builtins/unknowns.
                const tok_idx = node.tok_start;
                if (tok_idx < self.ast.tokens.len) {
                    const tok = self.ast.tokens[tok_idx];
                    if (tok.start < self.ast.source.len and tok.end <= self.ast.source.len) {
                        const name = self.ast.source[tok.start..tok.end];
                        if (self.symbol_table.get(name)) |v| return v;
                    }
                }
                return .none; // unknown identifier (builtin or unresolved)
            },
            else => return .none,
        }
    }
};
