const std = @import("std");
const val = @import("value.zig");
const tok = @import("token.zig");
const constants = @import("constants.zig");
// const ArrayList = std.ArrayList;
// const Allocator = std.mem.Allocator;
const print = std.debug.print;

pub const Span = struct {
    start: u32,
    end: u32,
};

pub const Location = struct {
    index: u32,
    line_start: u32,
};

pub const Lexer = struct {
    const Self = @This();
    buffer: []const u8,
    index: u32, // Scan index.
    lineStart: u32, // Beginning of this line
    tokenStart: u32,
    tokenEnd: u32,
    indentStack: u64, // A tiny little stack to contain up to 21 levels of indentation.
    depth: u16, // Indentation level
    kind: TokenKind,
    // allocator: Allocator,
    // tokens: ArrayList(u64),

    pub const TokenKind = enum { number, string, symbol, keyword, identifier, indent, dedent, newline, eof };

    pub fn init(buffer: []const u8) Self {
        return Self{ .buffer = buffer, .index = 0, .ctxLineStart = 0, .ctxDepth = 0, .indentStack = 0 };
    }

    fn gobble_digits(self: *Lexer) void {
        // Advance index until the first non-digit character.
        while (self.index < self.buffer.len) : (self.index += 1) {
            _ = switch (self.buffer[self.index]) {
                '0'...'9' => continue,
                else => break,
            };
        }
    }

    fn token_number(self: *Lexer) void {
        // MVL just needs int support for bootstrapping. Stage1+ should parse float.
        self.tokenStart = self.index;
        self.index += 1; // First char is already recognized as a digit.
        self.gobble_digits();
        self.tokenEnd = self.index;
        self.tokenKind = TokenKind.TNumber;
        // const value: u64 = std.fmt.parseInt(u32, self.buffer[self.ctxTokenStart..self.ctxTokenEnd], 10) catch 0;
        // return value;
    }

    fn token_string(self: *Lexer) void {
        self.index += 1; // Omit beginning quote.
        self.tokenStart = self.index;
        _ = self.seek_till("\"");
        self.tokenEnd = self.index - 1;
        // Expect but omit end quote.
        if (self.index < self.buffer.len and self.buffer[self.index] == '"') {
            self.index += 1;
        } else {
            // Raise error. Unterminated string. Skip for MVL.
            unreachable;
        }
        // Use the value-field to explicitly store the end, or a ref to the
        // string in some table. The string contains both quotes.
        // return val.createStringPtr(start, end);
    }

    fn is_delimiter(ch: u8) bool {
        // No mathematical operators in MVL.
        return switch (ch) {
            '(', ')', '[', ']', '{', '}', '"', '\'', '.', ',', ':', ';', ' ', '\t', '\n' => true,
            else => false,
        };
    }

    fn peek_starts_with(self: *Lexer, matchStr: []const u8) bool {
        // Peek if the next tokens start with the given match string.
        for (matchStr, 0..) |character, matchIndex| {
            const bufferI = self.index + matchIndex;
            if ((bufferI >= self.buffer.len) or (self.buffer[bufferI] != character)) {
                return false;
            }
        }
        return true;
    }

    fn peek_ch(self: *Lexer) u8 {
        if (self.index < self.buffer.len) {
            return self.buffer[self.index];
        }
        return 0;
    }

    fn seek_till(self: *Lexer, ch: []const u8) ?u64 {
        while (self.index < self.buffer.len and self.buffer[self.index] != ch[0]) : (self.index += 1) {}
        return null;
    }

    fn seek_till_delimiter(self: *Lexer) ?u64 {
        while (self.index < self.buffer.len and !is_delimiter(self.buffer[self.index])) : (self.index += 1) {}
        return null;
    }

    fn token_symbol(self: *Lexer) u64 {
        // First char is known to not be a number.
        const start = self.index;
        const ch = self.buffer[self.index];
        _ = ch;
        // // Capture single-character delimiters or symbols.
        // if (Lexer.is_delimiter(ch)) {
        //     self.index += 1;
        //     return val.createSymbol(ch);
        // }

        // Non digit or symbol start, so interpret as an identifier.
        _ = self.seek_till_delimiter();
        if (self.index - start > 255) {
            unreachable;
        }

        return tok.createIdentifier(@truncate(start), @truncate(self.index - start));
    }

    fn skip(self: *Lexer) ?u64 {
        self.index += 1;
        return null;
    }

    fn countIndentation(self: *Lexer) u16 {
        // Only indent with spaces. Mixed indentation is not allowed. Furthermore,
        var indent: u16 = 0;
        while (self.index < self.buffer.len and self.buffer[self.index] == ' ') : (self.index += 1) {
            // It's an indentation char. Check if it matches.
            indent += 1;
        }
        return indent;
    }

    fn tiny_stack_push(self: *Lexer, indentLvl: u3) void {
        self.indentStack = (self.indentStack << 3) | indentLvl;
    }

    fn tiny_stack_pop(self: *Lexer) u3 {
        const indentLvl = self.indentStack & 0b111;
        self.indentStack >>= 3;
        return indentLvl;
    }

    fn token_indentation(self: *Lexer) u64 {
        const indent: u16 = self.countIndentation();
        const ch = self.peek_ch();
        if (ch == '\n') {
            // Skip emitting anything when the entire line is empty.
            return tok.SKIP_TOKEN; // TODO: Return a special token to skip
        } else if (ch == '\t') {
            // Error on tabs - because it'll look like indentation visually, but don't have semantic meaning.
            // So either we have to raise an error error or accept tabs.
            print("Error: Mixed indentation. Use 4 spaces to align.", .{});
            return tok.LEX_ERROR; // TODO
        } else {
            // Count and determine if it's an indent or dedent.
            if (indent > self.depth) {
                const diff = indent - self.depth;
                if (diff > 8) {
                    // You can indent pretty far, but just can't do more than 8 spaces at a time.
                    print("Indentation level too deep. Use 4 spaces to align.", .{});
                    return tok.LEX_ERROR;
                }
                self.tiny_stack_push(@truncate(diff));
                self.depth = indent;
                return tok.SYMBOL_INDENT;
            } else if (indent < self.depth) {
                return self.token_dedent(indent);
            }
            // No special token if you're on the same indentation level.
        }

        return tok.SKIP_TOKEN;
    }

    fn token_dedent(self: *Lexer, indent: u16) u64 {
        var diff = self.depth - indent;
        var expectedDiff = self.tiny_stack_pop();
        if (expectedDiff == 0) {
            // If the tiny stack overflows, we'd get here.
            print("Indentation level too deep.", .{});
            return tok.LEX_ERROR;
        }
        var dedentCount: u8 = 0;
        // Loop to pop multiple indentation levels.
        while (diff > expectedDiff) {
            diff -= expectedDiff;
            dedentCount += 1;
            if (diff != 0) {
                expectedDiff = self.tiny_stack_pop();
            }
        }
        if (diff != 0) {
            print("Unaligned indentation. Use 4 spaces to align.", .{});
            return tok.LEX_ERROR;
        }

        self.depth = indent;
        // TODO: Return dedent count in the token context somehow since we can't emit multiple tokens at once.
        return tok.SYMBOL_DEDENT;
    }

    pub fn lex(self: *Lexer) u64 {
        if (self.index >= self.buffer.len) {
            if (self.depth > 0) {
                // Flush any remaining open blocks.
                return self.token_dedent(0);
            }

            return tok.SYMBOL_STREAM_END;
        }

        while (self.index < self.buffer.len) {
            const ch = self.buffer[self.index];
            // Ignore whitespace.
            switch (ch) {
                ' ' => {
                    if (self.lineStart == self.index) {
                        // Indentation at the start of a line is significant.
                        const indent = self.token_indentation();
                        if (indent != tok.SKIP_TOKEN) {
                            return indent;
                        }
                    } else {
                        // By skipping whitespace & comments, we can't rely on start of next tok as reliable
                        // "length" indexes. So instead store length explicitly for strings and identifiers.
                        self.skip();
                    }
                },
                '\t' => {
                    // Tabs have no power here! We use spaces exclusively.
                    self.skip();
                },
                '\n' => {
                    // New-lines are significant.
                    self.index += 1;
                    // Points to the beginning of line rather than newline char.
                    self.lineStart = self.index;
                    return tok.SYMBOL_NEWLINE;
                },
                '0'...'9', '.' => {
                    return self.token_number();
                },
                '"' => {
                    return self.token_string();
                },
                else => {
                    // Capture comments.
                    if (self.peek_starts_with("//")) {
                        self.index += 2; // Skip past '//'
                        self.seek_till("\n");
                    } else if (Lexer.is_delimiter(ch)) {
                        self.index += 1;
                        return val.createSymbol(ch);
                    } else {
                        return self.token_symbol();
                    }
                },
            }
        }
    }
};

const test_allocator = std.testing.allocator;
const arena_allocator = std.heap.ArenaAllocator;
const expect = std.testing.expect;

fn testTokenEquals(lexed: u64, expected: u64) !void {
    try expect(lexed == expected);
}

pub fn testLexToken(buffer: []const u8, expected: []const u64) !void {
    print("\nTest Lex Token: {s}\n", .{buffer});
    defer print("\n--------------------------------------------------------------\n", .{});
    var lexer = Lexer.init(buffer);
    defer lexer.deinit();
    lexer.lex();
    if (lexer.tokens.items.len != expected.len) {
        print("\nLength mismatch {d} vs {d}", .{ lexer.tokens.items.len, expected.len });

        for (lexer.tokens.items) |lexedToken| {
            tok.print_token(lexedToken, buffer);
        }
    }

    try expect(lexer.tokens.items.len == expected.len);

    for (lexer.tokens.items, 0..) |lexedToken, i| {
        if (lexedToken != expected[i]) {
            print(".\nExpected ", .{});
            tok.print_token(expected[i], buffer);
            print("\nLexerout ", .{});
        }
        tok.print_token(lexedToken, buffer);
        print("\n", .{});

        try testTokenEquals(lexedToken, expected[i]);
    }
}

test "Lex digits" {

    // "1 2 3"
    var lexer = Lexer.init("1 2 3");
    try expect(lexer.lex() == 1);
    //  01234
    // try testLexToken("1 2 3", &[_]u64{ 1, 2, 3 });
}

// test "Lex delimiters and identifiers" {
//     // Delimiters , . = : and identifiers.
//     // (a, bb):"
//     // 01234567
//     try testLexToken("(a, bb):", &[_]u64{
//         tok.SYMBOL_OPEN_PAREN,
//         val.createObject(tok.T_IDENTIFIER, 1, 1),
//         tok.SYMBOL_COMMA,
//         val.createObject(tok.T_IDENTIFIER, 4, 2),
//         tok.SYMBOL_CLOSE_PAREN,
//         tok.SYMBOL_COLON,
//     });
// }

// test "Lex string" {
//     // "Hello"
//     // 0123456
//     try testLexToken("\"Hello\"", &[_]u64{
//         val.createStringPtr(1, 5), // Doesn't include quotes.
//     });
// }

// test "Test indentation" {
//     // "Hello"
//     // 0123456
//     var source =
//         \\a
//         \\  b
//         \\  b2
//         \\     c
//         \\       d
//         \\  b3
//     ;
//     try testLexToken(source, &[_]u64{
//         val.createObject(tok.T_IDENTIFIER, 0, 1), // a
//         tok.SYMBOL_NEWLINE,
//         tok.SYMBOL_INDENT,
//         val.createObject(tok.T_IDENTIFIER, 4, 1), // b
//         tok.SYMBOL_NEWLINE,
//         val.createObject(tok.T_IDENTIFIER, 8, 2), // b2
//         tok.SYMBOL_NEWLINE,
//         tok.SYMBOL_INDENT,
//         val.createObject(tok.T_IDENTIFIER, 16, 1), // c
//         tok.SYMBOL_NEWLINE,
//         tok.SYMBOL_INDENT,
//         val.createObject(tok.T_IDENTIFIER, 25, 1), // d
//         tok.SYMBOL_NEWLINE,
//         tok.SYMBOL_DEDENT,
//         tok.SYMBOL_DEDENT,
//         val.createObject(tok.T_IDENTIFIER, 29, 2), // b3
//         tok.SYMBOL_DEDENT,
//     });
// }
