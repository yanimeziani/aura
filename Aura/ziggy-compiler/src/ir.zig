//! Intermediate Representation (IR) — Ziggy compiler.

const std = @import("std");

pub const Value = union(enum) {
    none,
    imm_int: i64,
    imm_float: f64,
    vreg: u32,
    global: u32,
};

pub const Opcode = enum {
    copy, add, sub, mul, div, cmp_eq, cmp_ne, cmp_lt, cmp_le, cmp_gt, cmp_ge, load, store, call, addr_of,
};

pub const Instruction = struct {
    op: Opcode,
    dest: Value,
    src1: Value,
    src2: Value,
};

pub const Terminator = union(enum) {
    ret: Value,
    br: u32,
    cond_br: struct { cond: Value, then_blk: u32, else_blk: u32 },
    unreachable,
};

pub const BasicBlock = struct {
    instructions: std.ArrayList(Instruction),
    terminator: Terminator,
    index: u32,
    pub fn init(allocator: std.mem.Allocator, index: u32) BasicBlock {
        return .{ .instructions = std.ArrayList(Instruction).init(allocator), .terminator = .unreachable, .index = index };
    }
    pub fn deinit(self: *BasicBlock) void { self.instructions.deinit(); }
};

pub const IrFunction = struct {
    name: []const u8,
    blocks: std.ArrayList(BasicBlock),
    vreg_count: u32,
    pub fn init(allocator: std.mem.Allocator, name: []const u8) !IrFunction {
        return .{ .name = try allocator.dupe(u8, name), .blocks = std.ArrayList(BasicBlock).init(allocator), .vreg_count = 0 };
    }
    pub fn deinit(self: *IrFunction, allocator: std.mem.Allocator) void {
        allocator.free(self.name); for (self.blocks.items) |*blk| blk.deinit(); self.blocks.deinit();
    }
    pub fn nextVreg(self: *IrFunction) Value {
        const v = Value{ .vreg = self.vreg_count }; self.vreg_count += 1; return v;
    }
};

pub const IrModule = struct {
    functions: std.ArrayList(IrFunction),
    globals: std.ArrayList([]const u8),
    pub fn init(allocator: std.mem.Allocator) IrModule {
        return .{ .functions = std.ArrayList(IrFunction).init(allocator), .globals = std.ArrayList([]const u8).init(allocator) };
    }
    pub fn deinit(self: *IrModule, allocator: std.mem.Allocator) void {
        for (self.functions.items) |*f| f.deinit(allocator); self.functions.deinit();
        for (self.globals.items) |g| allocator.free(g); self.globals.deinit();
    }
};
