//! IR Dumper — Ziggy compiler.

const std = @import("std");
const ir = @import("ir.zig");

pub fn dumpModule(module: *const ir.IrModule, writer: anytype) !void {
    for (module.functions.items) |f| {
        try writer.print("fn {s}() {
", .{f.name});
        for (f.blocks.items) |blk| {
            try writer.print("  block_{}:
", .{blk.index});
            for (blk.instructions.items) |ins| {
                try writer.print("    ", .{});
                try dumpInstruction(ins, writer);
                try writer.print("
", .{});
            }
            try writer.print("    ", .{});
            try dumpTerminator(blk.terminator, writer);
            try writer.print("
", .{});
        }
        try writer.print("}
", .{});
    }
}

fn dumpValue(val: ir.Value, writer: anytype) !void {
    switch (val) {
        .none => try writer.writeAll("none"),
        .imm_int => |v| try writer.print("{}", .{v}),
        .imm_float => |v| try writer.print("{}", .{v}),
        .vreg => |v| try writer.print("v{}", .{v}),
        .global => |v| try writer.print("g{}", .{v}),
    }
}

fn dumpInstruction(ins: ir.Instruction, writer: anytype) !void {
    try dumpValue(ins.dest, writer);
    try writer.print(" = {s} ", .{@tagName(ins.op)});
    try dumpValue(ins.src1, writer);
    try writer.writeAll(", ");
    try dumpValue(ins.src2, writer);
}

fn dumpTerminator(term: ir.Terminator, writer: anytype) !void {
    switch (term) {
        .ret => |v| {
            try writer.writeAll("ret ");
            try dumpValue(v, writer);
        },
        .br => |b| try writer.print("br block_{}", .{b}),
        .cond_br => |c| {
            try writer.writeAll("cond_br ");
            try dumpValue(c.cond, writer);
            try writer.print(", block_{}, block_{}", .{c.then_blk, c.else_blk});
        },
        .unreachable => try writer.writeAll("unreachable"),
    }
}
