//! Parser — Ziggy compiler. Zig 0.15.2.
//! Produces a flat AST from the token stream emitted by lex.zig.

const std = @import("std");
const lex = @import("lex.zig");
const Token    = lex.Token;
const TokenKind = lex.TokenKind;

// ── AST node kinds ────────────────────────────────────────────────────────────

pub const NodeKind = enum {
    file,
    const_decl,
    var_decl,
    fn_decl,
    test_decl,
    struct_decl,
    enum_decl,
    block,
    expr_stub,
    binary_expr,
    unary_expr,
    postfix_expr,
    if_expr,
    while_expr,
    for_expr,
    identifier,
    int_literal,
    float_literal,
    str_literal,
    error_node,
};

// ── AST node ──────────────────────────────────────────────────────────────────

pub const NodeIndex = u32;
pub const NULL_NODE: NodeIndex = std.math.maxInt(NodeIndex);

pub const Node = struct {
    kind:        NodeKind,
    tok_start:   u32,
    tok_end:     u32,
    data:        [2]u32 = .{ 0, 0 },
};

// ── AST ───────────────────────────────────────────────────────────────────────

pub const Ast = struct {
    nodes:    []Node,
    children: []NodeIndex,
    source:   []const u8,
    tokens:   []const Token,

    pub fn deinit(self: *Ast, allocator: std.mem.Allocator) void {
        allocator.free(self.nodes);
        allocator.free(self.children);
    }

    pub fn nodeSlice(self: *const Ast, node: Node) []const u8 {
        if (node.tok_start >= self.tokens.len) return "";
        const t_start = self.tokens[node.tok_start];
        const t_end   = if (node.tok_end > node.tok_start and node.tok_end <= self.tokens.len)
            self.tokens[node.tok_end - 1]
        else
            t_start;
        return self.source[t_start.start..t_end.end];
    }
};

// ── Precedence ────────────────────────────────────────────────────────────────

const Precedence = enum(u8) {
    none,
    lowest,
    equality,   // == !=
    comparison, // < > <= >=
    term,       // + -
    factor,     // * /
    unary,      // ! -
    call,       // . ()
};

fn getPrecedence(kind: TokenKind) Precedence {
    return switch (kind) {
        .eq_eq, .bang_eq => .equality,
        .lt, .gt, .lt_eq, .gt_eq => .comparison,
        .plus, .minus => .term,
        .star, .slash => .factor,
        .dot, .lparen => .call,
        else => .none,
    };
}

// ── Parser ────────────────────────────────────────────────────────────────────

pub const Parser = struct {
    tokens:    []const Token,
    source:    []const u8,
    pos:       u32,
    nodes:     std.array_list.Managed(Node),
    children:  std.array_list.Managed(NodeIndex),
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator, tokens: []const Token, source: []const u8) Parser {
        return .{
            .tokens    = tokens,
            .source    = source,
            .pos       = 0,
            .nodes     = std.array_list.Managed(Node).init(allocator),
            .children  = std.array_list.Managed(NodeIndex).init(allocator),
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *Parser) void {
        self.nodes.deinit();
        self.children.deinit();
    }

    fn peek(self: *Parser) TokenKind {
        if (self.pos >= self.tokens.len) return .eof;
        return self.tokens[self.pos].kind;
    }

    fn current(self: *Parser) Token {
        if (self.pos >= self.tokens.len) return self.tokens[self.tokens.len - 1];
        return self.tokens[self.pos];
    }

    fn advance(self: *Parser) Token {
        const t = self.current();
        if (self.pos + 1 < self.tokens.len) self.pos += 1;
        return t;
    }

    fn eat(self: *Parser, kind: TokenKind) bool {
        if (self.peek() == kind) { _ = self.advance(); return true; }
        return false;
    }

    fn expect(self: *Parser, kind: TokenKind) !void {
        if (self.peek() == kind) { _ = self.advance(); return; }
        return error.ParseError;
    }

    fn syncTopLevel(self: *Parser) void {
        while (true) {
            switch (self.peek()) {
                .eof, .kw_pub, .kw_const, .kw_var, .kw_fn, .kw_test, .kw_struct, .kw_enum => return,
                else => _ = self.advance(),
            }
        }
    }

    fn addNode(self: *Parser, node: Node) !NodeIndex {
        const idx: NodeIndex = @intCast(self.nodes.items.len);
        try self.nodes.append(node);
        return idx;
    }

    pub fn parseFile(self: *Parser) !NodeIndex {
        const file_start: u32 = self.pos;
        const children_start: u32 = @intCast(self.children.items.len);
        while (self.peek() != .eof) {
            while (self.peek() == .line_comment or self.peek() == .doc_comment or self.peek() == .container_doc_comment) _ = self.advance();
            if (self.peek() == .eof) break;
            const child = self.parseTopLevelDecl() catch |err| blk: {
                if (err == error.ParseError) {
                    const bad_start = self.pos;
                    self.syncTopLevel();
                    break :blk try self.addNode(.{ .kind = .error_node, .tok_start = bad_start, .tok_end = self.pos });
                }
                return err;
            };
            try self.children.append(child);
        }
        return self.addNode(.{ .kind = .file, .tok_start = file_start, .tok_end = self.pos, .data = .{ children_start, @intCast(self.children.items.len - children_start) } });
    }

    fn parseTopLevelDecl(self: *Parser) !NodeIndex {
        const start = self.pos;
        if (self.peek() == .kw_pub) _ = self.advance();
        return switch (self.peek()) {
            .kw_const => self.parseConstVar(start, .const_decl),
            .kw_var => self.parseConstVar(start, .var_decl),
            .kw_fn => self.parseFn(start),
            .kw_test => self.parseTest(start),
            .kw_struct => self.parseStruct(start),
            .kw_enum => self.parseEnum(start),
            else => error.ParseError,
        };
    }

    fn parseConstVar(self: *Parser, start: u32, kind: NodeKind) !NodeIndex {
        _ = self.advance();
        const name_tok = self.pos;
        _ = self.eat(.ident);
        var type_idx: NodeIndex = NULL_NODE;
        if (self.eat(.colon)) type_idx = try self.parseTypeExpr();
        _ = self.eat(.eq);
        _ = try self.parseExpr(.lowest);
        _ = self.eat(.semicolon);
        return self.addNode(.{ .kind = kind, .tok_start = start, .tok_end = self.pos, .data = .{ name_tok, type_idx } });
    }

    fn parseFn(self: *Parser, start: u32) !NodeIndex {
        _ = self.advance();
        const name_tok = self.pos;
        _ = self.eat(.ident);
        if (self.eat(.lparen)) { while (self.peek() != .rparen and self.peek() != .eof) _ = self.advance(); _ = self.eat(.rparen); }
        _ = try self.parseTypeExpr();
        const body_idx = try self.parseBlock();
        return self.addNode(.{ .kind = .fn_decl, .tok_start = start, .tok_end = self.pos, .data = .{ name_tok, body_idx } });
    }

    fn parseTest(self: *Parser, start: u32) !NodeIndex {
        _ = self.advance();
        _ = self.eat(.str_lit);
        const body_idx = try self.parseBlock();
        return self.addNode(.{ .kind = .test_decl, .tok_start = start, .tok_end = self.pos, .data = .{ 0, body_idx } });
    }

    fn parseStruct(self: *Parser, start: u32) !NodeIndex {
        _ = self.advance();
        try self.expect(.lbrace);
        while (self.peek() != .rbrace and self.peek() != .eof) {
            _ = self.advance();
        }
        try self.expect(.rbrace);
        return self.addNode(.{ .kind = .struct_decl, .tok_start = start, .tok_end = self.pos });
    }

    fn parseEnum(self: *Parser, start: u32) !NodeIndex {
        _ = self.advance();
        if (self.peek() == .lparen) { _ = self.advance(); _ = try self.parseTypeExpr(); try self.expect(.rparen); }
        try self.expect(.lbrace);
        while (self.peek() != .rbrace and self.peek() != .eof) {
            _ = self.advance();
        }
        try self.expect(.rbrace);
        return self.addNode(.{ .kind = .enum_decl, .tok_start = start, .tok_end = self.pos });
    }

    fn parseBlock(self: *Parser) !NodeIndex {
        const start = self.pos;
        if (!self.eat(.lbrace)) return NULL_NODE;
        const children_start: u32 = @intCast(self.children.items.len);
        while (self.peek() != .rbrace and self.peek() != .eof) {
            const child = try self.parseStatement();
            try self.children.append(child);
        }
        _ = self.eat(.rbrace);
        return self.addNode(.{ .kind = .block, .tok_start = start, .tok_end = self.pos, .data = .{ children_start, @intCast(self.children.items.len - children_start) } });
    }

    fn parseStatement(self: *Parser) !NodeIndex {
        const start = self.pos;
        return switch (self.peek()) {
            .kw_const => self.parseConstVar(start, .const_decl),
            .kw_var => self.parseConstVar(start, .var_decl),
            .kw_if => self.parseIf(),
            .kw_while => self.parseWhile(),
            .kw_for => self.parseFor(),
            else => {
                const expr = try self.parseExpr(.lowest);
                _ = self.eat(.semicolon);
                return expr;
            },
        };
    }

    fn parseIf(self: *Parser) !NodeIndex {
        const start = self.pos;
        _ = self.advance();
        try self.expect(.lparen);
        const cond = try self.parseExpr(.lowest);
        try self.expect(.rparen);
        const then_body = try self.parseExpr(.lowest);
        var else_body: NodeIndex = NULL_NODE;
        if (self.eat(.kw_else)) {
            else_body = try self.parseExpr(.lowest);
        }
        return self.addNode(.{ .kind = .if_expr, .tok_start = start, .tok_end = self.pos, .data = .{ cond, then_body } });
    }

    fn parseWhile(self: *Parser) !NodeIndex {
        const start = self.pos;
        _ = self.advance();
        try self.expect(.lparen);
        const cond = try self.parseExpr(.lowest);
        try self.expect(.rparen);
        const body = try self.parseExpr(.lowest);
        return self.addNode(.{ .kind = .while_expr, .tok_start = start, .tok_end = self.pos, .data = .{ cond, body } });
    }

    fn parseFor(self: *Parser) !NodeIndex {
        const start = self.pos;
        _ = self.advance();
        try self.expect(.lparen);
        const iterable = try self.parseExpr(.lowest);
        try self.expect(.rparen);
        if (self.eat(.pipe)) { _ = self.eat(.ident); try self.expect(.pipe); }
        const body = try self.parseExpr(.lowest);
        return self.addNode(.{ .kind = .for_expr, .tok_start = start, .tok_end = self.pos, .data = .{ iterable, body } });
    }

    fn parseTypeExpr(self: *Parser) anyerror!NodeIndex {
        const start = self.pos;
        if (self.peek() == .ident or self.peek() == .kw_struct or self.peek() == .kw_enum) {
            _ = self.advance();
            return self.addNode(.{ .kind = .expr_stub, .tok_start = start, .tok_end = self.pos });
        }
        while (self.peek() != .eq and self.peek() != .lbrace and self.peek() != .semicolon and self.peek() != .eof) _ = self.advance();
        return self.addNode(.{ .kind = .expr_stub, .tok_start = start, .tok_end = self.pos });
    }

    pub fn parseExpr(self: *Parser, precedence: Precedence) anyerror!NodeIndex {
        var left = try self.parsePrefix();
        while (@intFromEnum(precedence) < @intFromEnum(getPrecedence(self.peek()))) {
            const op_tok = self.pos;
            const op_kind = self.peek();
            if (op_kind == .lparen) {
                _ = self.advance();
                const children_start: u32 = @intCast(self.children.items.len);
                while (self.peek() != .rparen and self.peek() != .eof) {
                    try self.children.append(try self.parseExpr(.lowest));
                    if (!self.eat(.comma)) break;
                }
                try self.expect(.rparen);
                left = try self.addNode(.{ .kind = .postfix_expr, .tok_start = self.nodes.items[left].tok_start, .tok_end = self.pos, .data = .{ left, children_start } });
            } else if (op_kind == .dot) {
                _ = self.advance();
                const field = try self.parsePrimary();
                left = try self.addNode(.{ .kind = .binary_expr, .tok_start = self.nodes.items[left].tok_start, .tok_end = self.pos, .data = .{ left, field } });
            } else {
                const op = self.advance().kind;
                const right = try self.parseExpr(getPrecedence(op));
                left = try self.addNode(.{ .kind = .binary_expr, .tok_start = self.nodes.items[left].tok_start, .tok_end = self.pos, .data = .{ left, right } });
            }
            _ = op_tok;
        }
        return left;
    }

    fn parsePrefix(self: *Parser) !NodeIndex {
        const start = self.pos;
        switch (self.peek()) {
            .bang, .minus, .amp, .star => {
                _ = self.advance();
                const right = try self.parseExpr(.unary);
                return self.addNode(.{ .kind = .unary_expr, .tok_start = start, .tok_end = self.pos, .data = .{ right, 0 } });
            },
            else => return self.parsePrimary(),
        }
    }

    fn parsePrimary(self: *Parser) anyerror!NodeIndex {
        const start = self.pos;
        return switch (self.peek()) {
            .int_lit => { _ = self.advance(); return self.addNode(.{ .kind = .int_literal, .tok_start = start, .tok_end = self.pos }); },
            .float_lit => { _ = self.advance(); return self.addNode(.{ .kind = .float_literal, .tok_start = start, .tok_end = self.pos }); },
            .str_lit => { _ = self.advance(); return self.addNode(.{ .kind = .str_literal, .tok_start = start, .tok_end = self.pos }); },
            .ident => { _ = self.advance(); return self.addNode(.{ .kind = .identifier, .tok_start = start, .tok_end = self.pos }); },
            .lparen => { _ = self.advance(); const expr = try self.parseExpr(.lowest); try self.expect(.rparen); return expr; },
            .lbrace => self.parseBlock(),
            .kw_if => self.parseIf(),
            .kw_while => self.parseWhile(),
            .kw_for => self.parseFor(),
            else => error.ParseError,
        };
    }
};

pub fn parse(allocator: std.mem.Allocator, tokens: []const Token, source: []const u8) !Ast {
    var parser = Parser.init(allocator, tokens, source);
    errdefer parser.deinit();
    _ = try parser.parseFile();
    return Ast{ .nodes = try parser.nodes.toOwnedSlice(), .children = try parser.children.toOwnedSlice(), .source = source, .tokens = tokens };
}

test "binary expression parsing" {
    const a = std.testing.allocator;
    const src = "const x = 1 + 2 * 3;";
    const tokens = try lex.tokenize(a, src);
    defer a.free(tokens);
    var ast = try parse(a, tokens, src);
    defer ast.deinit(a);
    var found = false;
    for (ast.nodes) |n| { if (n.kind == .binary_expr) found = true; }
    try std.testing.expect(found);
}
