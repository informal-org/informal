const std = @import("std");
const ArrayList = std.ArrayList;

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
    tokens: ArrayList(Token),

    pub fn init(buffer: []const u8, tokens: ArrayList(Token)) Self {
        return Self {
            .buffer = buffer,
            .index = 0,
            .tokens = tokens
        };
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
        return Token {
            .kind = TokenKind.string,
            .start = start,
            .value = 0
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
        return Token {
            .kind = TokenKind.identifier,
            .value = 0,
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
                    // TODO: By skipping these, end offsets may be missing.
                    // It'd gulp up extra whitespace.
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
                try self.tokens.append(t);
            }
        }
    }
};


// const test_allocator = std.testing.allocator;
const arena_allocator = std.heap.ArenaAllocator;
const expect = std.testing.expect;
test "Lex identifiers" {
    // Identifiers
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    var tokens = ArrayList(Token).init(allocator);    // test_allocator

    var lexer = Lexer.init("3.1415", tokens);
    try lexer.lex();
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