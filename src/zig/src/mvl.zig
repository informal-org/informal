const std = @import("std");
const ArrayList = std.ArrayList;

const TokenKind = enum {
    number,
    symbol,     // Recognized tokens.
    string,     // A quoted string literal.
    identifier,
    boolean,
    comment
};

const Symbol = enum {
    none,
    comma,
    equals,
    colon,
    semi_colon,
    open_paren,
    close_paren,
    open_sqbr,
    close_sqbr,
    open_brace,
    close_brace
};

const Token = struct {
    kind: TokenKind,
    value: u64,
    start: u32        // Index into Lexer buffer. Length implicit from next token.
};


pub const Lexer = struct {
    const Self = @This();
    buffer: []const u8,
    index: u32,
    tokens: ArrayList(Token),

    pub fn init(buffer: []const u8, tokens: ArrayList(Token)) Self {
        return Self{
            .buffer = buffer,
            .index = 0,
            .tokens = tokens
        };
    }

    pub fn lex(self: *Lexer) void {
        _ = self;
    }
};


const test_allocator = std.testing.allocator;
const expect = std.testing.expect;
test "Lex identifiers" {
    // Identifiers
    var tokens = ArrayList(Token).init(test_allocator);
    defer tokens.deinit();
    var lexer = Lexer.init("3.1415", tokens);
    lexer.lex();
    // try expect()

    // Digits

    // , . = :

}

test "Lex grouping" {
    // ()
    // {}
    // []
    // " "
}

test "Lex comments" {

}

test "Lex blocks" {
    // Indentation aware block handling. 
}