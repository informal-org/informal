const std = @import("std");
const ArrayList = std.ArrayList;
const Allocator = std.mem.Allocator;


const TokenKind = enum {
    number,
    symbol,     // Recognized tokens.
    string,     // A quoted string literal.
    identifier,
    delimiter,
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
    allocator: Allocator,
    tokens: ArrayList(Token),

    pub fn init(buffer: []const u8, allocator: Allocator) Self {
        var tokens = ArrayList(Token).init(allocator);
        return Self {
            .buffer = buffer,
            .index = 0,
            .allocator = allocator,
            .tokens = tokens
        };
    }

    pub fn deinit(self: *Lexer) void {
        self.tokens.deinit();
        self.allocator.deinit();
    }

    fn gobble_digits(self: *Lexer) void {
        // Advance index until the first non-digit character.
        while (self.index < self.buffer.len) : (self.index += 1) {
            _ = switch (self.buffer[self.index]) {
                '0'...'9' => continue,
                else => break
            };
        }
    }

    fn token_number(self: *Lexer) Token {
        // MVL just needs int support for bootstrapping. Stage1+ should parse float.
        var start = self.index;
        self.index += 1;    // First char is already recognized as a digit.
        self.gobble_digits();
        var value: u64 = std.fmt.parseInt(u64, self.buffer[start..self.index], 10) catch 0;

        return Token {
            .kind = TokenKind.number,
            .start = start,
            .value = value
        };
    }

    fn token_string(self: *Lexer) Token {
        var start = self.index;
        self.index += 1;
        _ = self.seek_till("\"");
        // Use the value-field to explicitly store the end, or a ref to the 
        // string in some table. The string contains both quotes.
        return Token {
            .kind = TokenKind.string,
            .start = start,
            .value = self.index
        };
    }

    fn is_delimiter(ch: u8) bool {
        // No mathematical operators in MVL.
        return switch(ch) {
            '(', ')', '[', ']', '{', '}', '"', '\'',
            '.', ',', ':', ';', ' ', '\t', '\n' => true,
            else => false 
        };
    }

    fn peek_starts_with(self: *Lexer, matchStr: []const u8) bool {
        // Peek if the next tokens start with the given match string.
        for (matchStr) |character, matchIndex| {
            var bufferI = self.index + matchIndex;
            if ((bufferI >= self.buffer.len) or (self.buffer[bufferI] != character)) {
                return false;
            } 
        }
        return true;
    }

    fn seek_till(self: *Lexer, ch: []const u8) ?Token {
        while (self.index < self.buffer.len and self.buffer[self.index] != ch[0]) : (self.index += 1) {}
        return null;
    }

    fn seek_till_delimiter(self: *Lexer) ?Token {
        while (self.index < self.buffer.len and !is_delimiter(self.buffer[self.index])) : (self.index += 1) {}
        return null;
    }

    fn token_symbol(self: *Lexer) Token {
        // First char is known to not be a number.
        var start = self.index;
        var ch = self.buffer[self.index];
        // Capture single-character delimiters or symbols.
        if(Lexer.is_delimiter(ch)){
            self.index += 1;
            return Token {
                .kind = TokenKind.delimiter,
                .value = @as(u64, ch),
                .start = start
            };
        }

        // Non digit or symbol start, so interpret as an identifier.
        _ = self.seek_till_delimiter();
        self.index -= 1;    // Rewind, so the delimeter can be consumed next turn.
        return Token {
            .kind = TokenKind.identifier,
            .value = self.index,     // Store end idx, or a ref to symbol id in symbol table.
            .start = start
        };
    }

    fn skip(self: *Lexer) ?Token {
        self.index += 1;
        return null;
    }

    pub fn lex(self: *Lexer) !void {
        while (self.index < self.buffer.len) {
            var ch = self.buffer[self.index];
            var tok: ?Token = null;
            // Ignore whitespace.
            _ = switch(ch) {
                ' ', '\t' => {
                    // By skipping whitespace & comments, we can't rely on start of next tok as reliable
                    // "length" indexes. So instead store length explicitly for strings and identifiers.
                    _ = self.skip();
                },
                '0'...'9', '.' => {
                    tok = self.token_number();
                },
                '"' => {
                    tok = self.token_string();
                },
                else => {
                    // Capture comments.
                    if(self.peek_starts_with("//")) {
                        self.index += 2;    // Skip past '//'
                        _ = self.seek_till("\n");
                        // TODO: We still need a token for this, to know the end for prev token.
                    } else {
                        tok = self.token_symbol();
                    }
                }
            };

            if (tok) |t| {
                std.debug.print("Adding token is {any}\n", .{t});
                try self.tokens.append(t);
                std.debug.print("Adding succeeded. Len = \n", .{});
            }
        }
    }
};


const test_allocator = std.testing.allocator;
const arena_allocator = std.heap.ArenaAllocator;
const expect = std.testing.expect;

fn testTokenEquals(lexed: Token, expected: Token) !void {
    try expect(lexed.kind == expected.kind);
    try expect(lexed.start == expected.start);
    try expect(lexed.value == expected.value);
}

test "Lex identifiers" {
    // Identifiers
    // var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    // defer arena.deinit();
    // const allocator = arena.allocator();
    var lexer = Lexer.init("3", test_allocator);
    try lexer.lex();
    try testTokenEquals(lexer.tokens.items[0], Token {
        .start=0,
        .kind=TokenKind.number,
        .value=3,
    });

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