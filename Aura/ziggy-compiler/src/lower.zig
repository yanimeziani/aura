//! AST to IR Lowering — Ziggy compiler.

const std = @import("std");
const parse = @import("parse.zig");
const ir = @import("ir.zig");
const types = @import("type.zig");

pub const Lowerer = struct {
    allocator: std.mem.Allocator,
    ast: *const parse.Ast,
    module: ir.IrModule,
    current_fn: ?*ir.IrFunction = null,
    current_blk: ?*ir.BasicBlock = null,

    pub fn init(allocator: std.mem.Allocator, ast: *const parse.Ast) Lowerer {
        return .{ .allocator = allocator, .ast = ast, .module = ir.IrModule.init(allocator) };
    }

    pub fn deinit(self: *Lowerer) void { self.module.deinit(self.allocator); }

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
            .identifier => {
                return .{ .vreg = 0 }; // stub
            },
            else => return .none,
        }
    }
};
