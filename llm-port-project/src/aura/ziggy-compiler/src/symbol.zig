//! Symbols — Ziggy compiler. Zig 0.15.2.
//! Symbol table and scope tracking.

const std = @import("std");

pub const SymbolKind = enum {
    variable,
    constant,
    function,
    type,
};

pub const Symbol = struct {
    name: []const u8,
    kind: SymbolKind,
    // type: *Type, // Will add when G48 is ready
};

pub const Scope = struct {
    parent: ?*Scope = null,
    symbols: std.StringArrayMap(Symbol),
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator, parent: ?*Scope) Scope {
        return .{
            .parent = parent,
            .symbols = std.StringArrayMap(Symbol).init(allocator),
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *Scope) void {
        self.symbols.deinit();
    }

    pub fn put(self: *Scope, name: []const u8, symbol: Symbol) !void {
        try self.symbols.put(name, symbol);
    }

    pub fn get(self: *const Scope, name: []const u8) ?Symbol {
        if (self.symbols.get(name)) |s| return s;
        if (self.parent) |p| return p.get(name);
        return null;
    }
};

pub const SymbolTable = struct {
    allocator: std.mem.Allocator,
    root: *Scope,

    pub fn init(allocator: std.mem.Allocator) !SymbolTable {
        const root = try allocator.create(Scope);
        root.* = Scope.init(allocator, null);
        return .{
            .allocator = allocator,
            .root = root,
        };
    }

    pub fn deinit(self: *SymbolTable) void {
        // Recursive deinit would be better but for now:
        self.root.deinit();
        self.allocator.destroy(self.root);
    }
};

test "symbol table and scoping" {
    const a = std.testing.allocator;
    var st = try SymbolTable.init(a);
    defer st.deinit();

    try st.root.put("x", .{ .name = "x", .kind = .variable });
    
    var child = Scope.init(a, st.root);
    defer child.deinit();
    
    try child.put("y", .{ .name = "y", .kind = .constant });

    try std.testing.expect(child.get("x") != null);
    try std.testing.expect(child.get("y") != null);
    try std.testing.expect(st.root.get("y") == null);
}
