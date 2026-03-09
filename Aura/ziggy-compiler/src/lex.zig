//! Lexer — Ziggy compiler. Zig 0.15.2.
//! Produces a flat token stream from Ziggy/Zig source.

const std = @import("std");

// ── Token kinds ──────────────────────────────────────────────────────────────

pub const TokenKind = enum {
    // Literals
    int_lit,
    float_lit,
    str_lit,
    char_lit,
    // Keywords (full Zig 0.15 set)
    kw_addrspace, kw_align, kw_allowzero, kw_and, kw_anyframe, kw_anytype,
    kw_asm, kw_async, kw_await, kw_break, kw_callconv, kw_catch,
    kw_comptime, kw_const, kw_continue, kw_defer, kw_else, kw_enum,
    kw_errdefer, kw_error, kw_export, kw_extern, kw_false, kw_fn,
    kw_for, kw_if, kw_inline, kw_linksection, kw_noalias, kw_noinline,
    kw_nosuspend, kw_null, kw_opaque, kw_or, kw_orelse, kw_packed,
    kw_pub, kw_resume, kw_return, kw_struct, kw_suspend, kw_switch,
    kw_test, kw_threadlocal, kw_true, kw_try, kw_undefined, kw_union,
    kw_unreachable, kw_usingnamespace, kw_var, kw_volatile, kw_while,
    // Identifier / builtin
    ident,
    builtin, // @name
    // Single-char punctuation
    at, bang, percent, amp, lparen, rparen, star, plus, comma, minus,
    dot, slash, colon, semicolon, lt, eq, gt, question,
    lbracket, rbracket, caret, lbrace, rbrace, pipe, tilde,
    // Multi-char operators
    dot_dot, dot_dot_dot, dot_star, dot_question,
    bang_eq, percent_eq,
    amp_amp, amp_eq,
    star_star, star_eq, star_percent, star_percent_eq, star_pipe, star_pipe_eq,
    plus_plus, plus_eq, plus_percent, plus_percent_eq, plus_pipe, plus_pipe_eq,
    minus_gt, minus_eq, minus_percent, minus_percent_eq, minus_pipe, minus_pipe_eq,
    slash_eq,
    lt_lt, lt_lt_eq, lt_lt_pipe, lt_lt_pipe_eq, lt_eq,
    eq_eq, eq_gt,
    gt_eq, gt_gt, gt_gt_eq,
    caret_eq,
    pipe_pipe, pipe_eq,
    // Comments
    line_comment, doc_comment, container_doc_comment,
    // Control
    eof, invalid,
};

// ── Token ────────────────────────────────────────────────────────────────────

pub const Token = struct {
    kind: TokenKind,
    start: u32,
    end: u32,

    pub fn slice(self: Token, source: []const u8) []const u8 {
        return source[self.start..self.end];
    }
};

// ── Keyword table ─────────────────────────────────────────────────────────────

const keywords = std.StaticStringMap(TokenKind).initComptime(.{
    .{ "addrspace", .kw_addrspace }, .{ "align", .kw_align },
    .{ "allowzero", .kw_allowzero }, .{ "and", .kw_and },
    .{ "anyframe", .kw_anyframe },   .{ "anytype", .kw_anytype },
    .{ "asm", .kw_asm },             .{ "async", .kw_async },
    .{ "await", .kw_await },         .{ "break", .kw_break },
    .{ "callconv", .kw_callconv },   .{ "catch", .kw_catch },
    .{ "comptime", .kw_comptime },   .{ "const", .kw_const },
    .{ "continue", .kw_continue },   .{ "defer", .kw_defer },
    .{ "else", .kw_else },           .{ "enum", .kw_enum },
    .{ "errdefer", .kw_errdefer },   .{ "error", .kw_error },
    .{ "export", .kw_export },       .{ "extern", .kw_extern },
    .{ "false", .kw_false },         .{ "fn", .kw_fn },
    .{ "for", .kw_for },             .{ "if", .kw_if },
    .{ "inline", .kw_inline },       .{ "linksection", .kw_linksection },
    .{ "noalias", .kw_noalias },     .{ "noinline", .kw_noinline },
    .{ "nosuspend", .kw_nosuspend }, .{ "null", .kw_null },
    .{ "opaque", .kw_opaque },       .{ "or", .kw_or },
    .{ "orelse", .kw_orelse },       .{ "packed", .kw_packed },
    .{ "pub", .kw_pub },             .{ "resume", .kw_resume },
    .{ "return", .kw_return },       .{ "struct", .kw_struct },
    .{ "suspend", .kw_suspend },     .{ "switch", .kw_switch },
    .{ "test", .kw_test },           .{ "threadlocal", .kw_threadlocal },
    .{ "true", .kw_true },           .{ "try", .kw_try },
    .{ "undefined", .kw_undefined }, .{ "union", .kw_union },
    .{ "unreachable", .kw_unreachable }, .{ "usingnamespace", .kw_usingnamespace },
    .{ "var", .kw_var },             .{ "volatile", .kw_volatile },
    .{ "while", .kw_while },
});

// ── Lexer struct ──────────────────────────────────────────────────────────────

pub const Lexer = struct {
    source: []const u8,
    pos: u32,

    pub fn init(source: []const u8) Lexer {
        return .{ .source = source, .pos = 0 };
    }

    pub fn next(self: *Lexer) Token {
        self.skipWhitespace();
        if (self.pos >= self.source.len)
            return .{ .kind = .eof, .start = self.pos, .end = self.pos };

        const start = self.pos;
        const c = self.advance();

        switch (c) {
            '(' => return tok(start, self.pos, .lparen),
            ')' => return tok(start, self.pos, .rparen),
            '{' => return tok(start, self.pos, .lbrace),
            '}' => return tok(start, self.pos, .rbrace),
            '[' => return tok(start, self.pos, .lbracket),
            ']' => return tok(start, self.pos, .rbracket),
            ',' => return tok(start, self.pos, .comma),
            ';' => return tok(start, self.pos, .semicolon),
            '~' => return tok(start, self.pos, .tilde),
            ':' => return tok(start, self.pos, .colon),

            '@' => {
                if (self.peek()) |nc| {
                    if (isIdentStart(nc)) {
                        self.pos += 1;
                        while (self.peek()) |nc2| {
                            if (isIdentCont(nc2)) self.pos += 1 else break;
                        }
                        return tok(start, self.pos, .builtin);
                    }
                }
                return tok(start, self.pos, .at);
            },
            '!' => {
                if (self.match('=')) return tok(start, self.pos, .bang_eq);
                return tok(start, self.pos, .bang);
            },
            '?' => return tok(start, self.pos, .question),
            '%' => {
                if (self.match('=')) return tok(start, self.pos, .percent_eq);
                return tok(start, self.pos, .percent);
            },
            '&' => {
                if (self.match('&')) return tok(start, self.pos, .amp_amp);
                if (self.match('=')) return tok(start, self.pos, .amp_eq);
                return tok(start, self.pos, .amp);
            },
            '*' => {
                if (self.match('*')) return tok(start, self.pos, .star_star);
                if (self.match('%')) {
                    if (self.match('=')) return tok(start, self.pos, .star_percent_eq);
                    return tok(start, self.pos, .star_percent);
                }
                if (self.match('|')) {
                    if (self.match('=')) return tok(start, self.pos, .star_pipe_eq);
                    return tok(start, self.pos, .star_pipe);
                }
                if (self.match('=')) return tok(start, self.pos, .star_eq);
                return tok(start, self.pos, .star);
            },
            '+' => {
                if (self.match('+')) return tok(start, self.pos, .plus_plus);
                if (self.match('%')) {
                    if (self.match('=')) return tok(start, self.pos, .plus_percent_eq);
                    return tok(start, self.pos, .plus_percent);
                }
                if (self.match('|')) {
                    if (self.match('=')) return tok(start, self.pos, .plus_pipe_eq);
                    return tok(start, self.pos, .plus_pipe);
                }
                if (self.match('=')) return tok(start, self.pos, .plus_eq);
                return tok(start, self.pos, .plus);
            },
            '-' => {
                if (self.match('>')) return tok(start, self.pos, .minus_gt);
                if (self.match('%')) {
                    if (self.match('=')) return tok(start, self.pos, .minus_percent_eq);
                    return tok(start, self.pos, .minus_percent);
                }
                if (self.match('|')) {
                    if (self.match('=')) return tok(start, self.pos, .minus_pipe_eq);
                    return tok(start, self.pos, .minus_pipe);
                }
                if (self.match('=')) return tok(start, self.pos, .minus_eq);
                return tok(start, self.pos, .minus);
            },
            '/' => {
                if (self.match('/')) {
                    if (self.match('!')) {
                        self.skipToEol();
                        return tok(start, self.pos, .container_doc_comment);
                    }
                    if (self.peek() == '/') {
                        self.pos += 1;
                        self.skipToEol();
                        return tok(start, self.pos, .doc_comment);
                    }
                    self.skipToEol();
                    return tok(start, self.pos, .line_comment);
                }
                if (self.match('=')) return tok(start, self.pos, .slash_eq);
                return tok(start, self.pos, .slash);
            },
            '<' => {
                if (self.match('<')) {
                    if (self.peek() == '|') {
                        self.pos += 1;
                        if (self.match('=')) return tok(start, self.pos, .lt_lt_pipe_eq);
                        return tok(start, self.pos, .lt_lt_pipe);
                    }
                    if (self.match('=')) return tok(start, self.pos, .lt_lt_eq);
                    return tok(start, self.pos, .lt_lt);
                }
                if (self.match('=')) return tok(start, self.pos, .lt_eq);
                return tok(start, self.pos, .lt);
            },
            '=' => {
                if (self.match('=')) return tok(start, self.pos, .eq_eq);
                if (self.match('>')) return tok(start, self.pos, .eq_gt);
                return tok(start, self.pos, .eq);
            },
            '>' => {
                if (self.match('>')) {
                    if (self.match('=')) return tok(start, self.pos, .gt_gt_eq);
                    return tok(start, self.pos, .gt_gt);
                }
                if (self.match('=')) return tok(start, self.pos, .gt_eq);
                return tok(start, self.pos, .gt);
            },
            '^' => {
                if (self.match('=')) return tok(start, self.pos, .caret_eq);
                return tok(start, self.pos, .caret);
            },
            '|' => {
                if (self.match('|')) return tok(start, self.pos, .pipe_pipe);
                if (self.match('=')) return tok(start, self.pos, .pipe_eq);
                return tok(start, self.pos, .pipe);
            },
            '.' => {
                if (self.match('.')) {
                    if (self.match('.')) return tok(start, self.pos, .dot_dot_dot);
                    return tok(start, self.pos, .dot_dot);
                }
                if (self.match('*')) return tok(start, self.pos, .dot_star);
                if (self.match('?')) return tok(start, self.pos, .dot_question);
                return tok(start, self.pos, .dot);
            },
            '"' => return self.lexString(start),
            '\'' => return self.lexChar(start),
            '0'...'9' => return self.lexNumber(start),
            else => {
                if (isIdentStart(c)) return self.lexIdent(start);
                return tok(start, self.pos, .invalid);
            },
        }
    }

    // ── internal helpers ──────────────────────────────────────────────────────

    fn advance(self: *Lexer) u8 {
        const c = self.source[self.pos];
        self.pos += 1;
        return c;
    }

    fn peek(self: *Lexer) ?u8 {
        if (self.pos >= self.source.len) return null;
        return self.source[self.pos];
    }

    fn match(self: *Lexer, expected: u8) bool {
        if (self.pos < self.source.len and self.source[self.pos] == expected) {
            self.pos += 1;
            return true;
        }
        return false;
    }

    fn skipWhitespace(self: *Lexer) void {
        while (self.pos < self.source.len) {
            switch (self.source[self.pos]) {
                ' ', '\t', '\r', '\n' => self.pos += 1,
                else => break,
            }
        }
    }

    fn skipToEol(self: *Lexer) void {
        while (self.pos < self.source.len and self.source[self.pos] != '\n')
            self.pos += 1;
    }

    fn lexIdent(self: *Lexer, start: u32) Token {
        while (self.peek()) |c| {
            if (isIdentCont(c)) self.pos += 1 else break;
        }
        const text = self.source[start..self.pos];
        const kind = keywords.get(text) orelse .ident;
        return tok(start, self.pos, kind);
    }

    fn lexNumber(self: *Lexer, start: u32) Token {
        var is_float = false;
        // prefix: 0x / 0o / 0b
        if (self.source[start] == '0' and self.pos < self.source.len) {
            switch (self.source[self.pos]) {
                'x', 'X' => {
                    self.pos += 1;
                    while (self.peek()) |c| {
                        if (std.ascii.isHex(c) or c == '_') self.pos += 1 else break;
                    }
                    return tok(start, self.pos, .int_lit);
                },
                'o', 'O' => {
                    self.pos += 1;
                    while (self.peek()) |c| {
                        if ((c >= '0' and c <= '7') or c == '_') self.pos += 1 else break;
                    }
                    return tok(start, self.pos, .int_lit);
                },
                'b', 'B' => {
                    self.pos += 1;
                    while (self.peek()) |c| {
                        if (c == '0' or c == '1' or c == '_') self.pos += 1 else break;
                    }
                    return tok(start, self.pos, .int_lit);
                },
                else => {},
            }
        }
        // decimal integer digits
        while (self.peek()) |c| {
            if (std.ascii.isDigit(c) or c == '_') self.pos += 1 else break;
        }
        // optional fractional part (avoid consuming ".." operator)
        if (self.pos + 1 < self.source.len and
            self.source[self.pos] == '.' and
            self.source[self.pos + 1] != '.')
        {
            is_float = true;
            self.pos += 1;
            while (self.peek()) |c| {
                if (std.ascii.isDigit(c) or c == '_') self.pos += 1 else break;
            }
        }
        // optional exponent
        if (self.peek()) |c| {
            if (c == 'e' or c == 'E') {
                is_float = true;
                self.pos += 1;
                if (self.peek()) |nc| {
                    if (nc == '+' or nc == '-') self.pos += 1;
                }
                while (self.peek()) |nc| {
                    if (std.ascii.isDigit(nc)) self.pos += 1 else break;
                }
            }
        }
        return tok(start, self.pos, if (is_float) .float_lit else .int_lit);
    }

    fn lexString(self: *Lexer, start: u32) Token {
        while (self.pos < self.source.len) {
            const c = self.advance();
            if (c == '\\') { if (self.pos < self.source.len) self.pos += 1; continue; }
            if (c == '"') break;
        }
        return tok(start, self.pos, .str_lit);
    }

    fn lexChar(self: *Lexer, start: u32) Token {
        while (self.pos < self.source.len) {
            const c = self.advance();
            if (c == '\\') { if (self.pos < self.source.len) self.pos += 1; continue; }
            if (c == '\'') break;
        }
        return tok(start, self.pos, .char_lit);
    }
};

fn tok(start: u32, end: u32, kind: TokenKind) Token {
    return .{ .kind = kind, .start = start, .end = end };
}

fn isIdentStart(c: u8) bool {
    return std.ascii.isAlphabetic(c) or c == '_';
}

fn isIdentCont(c: u8) bool {
    return std.ascii.isAlphanumeric(c) or c == '_';
}

// ── Public API ────────────────────────────────────────────────────────────────

/// Tokenize source into a caller-owned []Token. Free with allocator.free().
pub fn tokenize(allocator: std.mem.Allocator, source: []const u8) ![]Token {
    var list = std.array_list.Managed(Token).init(allocator);
    errdefer list.deinit();

    var lexer = Lexer.init(source);
    while (true) {
        const t = lexer.next();
        try list.append(t);
        if (t.kind == .eof) break;
    }
    return list.toOwnedSlice();
}

// ── Tests ─────────────────────────────────────────────────────────────────────

test "empty source yields eof" {
    const tokens = try tokenize(std.testing.allocator, "");
    defer std.testing.allocator.free(tokens);
    try std.testing.expectEqual(@as(usize, 1), tokens.len);
    try std.testing.expectEqual(TokenKind.eof, tokens[0].kind);
}

test "keywords" {
    const tokens = try tokenize(std.testing.allocator, "const var fn pub return");
    defer std.testing.allocator.free(tokens);
    try std.testing.expectEqual(TokenKind.kw_const, tokens[0].kind);
    try std.testing.expectEqual(TokenKind.kw_var, tokens[1].kind);
    try std.testing.expectEqual(TokenKind.kw_fn, tokens[2].kind);
    try std.testing.expectEqual(TokenKind.kw_pub, tokens[3].kind);
    try std.testing.expectEqual(TokenKind.kw_return, tokens[4].kind);
}

test "ident vs keyword" {
    const src = "foo const bar";
    const tokens = try tokenize(std.testing.allocator, src);
    defer std.testing.allocator.free(tokens);
    try std.testing.expectEqual(TokenKind.ident, tokens[0].kind);
    try std.testing.expectEqualStrings("foo", tokens[0].slice(src));
    try std.testing.expectEqual(TokenKind.kw_const, tokens[1].kind);
    try std.testing.expectEqual(TokenKind.ident, tokens[2].kind);
}

test "integer and float literals" {
    const tokens = try tokenize(std.testing.allocator, "42 0xff 3.14 1e10");
    defer std.testing.allocator.free(tokens);
    try std.testing.expectEqual(TokenKind.int_lit, tokens[0].kind);
    try std.testing.expectEqual(TokenKind.int_lit, tokens[1].kind);
    try std.testing.expectEqual(TokenKind.float_lit, tokens[2].kind);
    try std.testing.expectEqual(TokenKind.float_lit, tokens[3].kind);
}

test "operators" {
    const tokens = try tokenize(std.testing.allocator, "== != <= >= << >>");
    defer std.testing.allocator.free(tokens);
    try std.testing.expectEqual(TokenKind.eq_eq, tokens[0].kind);
    try std.testing.expectEqual(TokenKind.bang_eq, tokens[1].kind);
    try std.testing.expectEqual(TokenKind.lt_eq, tokens[2].kind);
    try std.testing.expectEqual(TokenKind.gt_eq, tokens[3].kind);
    try std.testing.expectEqual(TokenKind.lt_lt, tokens[4].kind);
    try std.testing.expectEqual(TokenKind.gt_gt, tokens[5].kind);
}

test "builtin and comments" {
    const src = "@import // line comment\n@as";
    const tokens = try tokenize(std.testing.allocator, src);
    defer std.testing.allocator.free(tokens);
    try std.testing.expectEqual(TokenKind.builtin, tokens[0].kind);
    try std.testing.expectEqualStrings("@import", tokens[0].slice(src));
    try std.testing.expectEqual(TokenKind.line_comment, tokens[1].kind);
    try std.testing.expectEqual(TokenKind.builtin, tokens[2].kind);
}
