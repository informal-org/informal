const std = @import("std");
const val = @import("value.zig");
const tok = @import("token.zig");
const constants = @import("constants.zig");
const q = @import("queue.zig");

const print = std.debug.print;
const TokenQueue = q.Queue(tok.Token);
const AuxQueue = q.Queue(tok.Aux);

const SYNTAX_Q: u1 = 0;
const AUX_Q: u1 = 1;

// Compile time constant function which takes a string of valid delimiter characters and returns a bitset.
// The bitset is used to quickly check if a character is a delimiter.
pub fn make_character_bitset(pattern: []const u8) u128 {
    // assert - is-ascii. Just used internally with fixed compile-time patterns.
    var bitset: u128 = 0;
    for (pattern) |ch| {
        bitset |= 1 << ch;
    }
    return bitset;
}

const DELIMITERS = make_character_bitset("()[]{}\"'.,:; \t\n");
const MULTICHAR_SYMBOLS = "!*+-/<=>";
// Microoptimization - the multichar bitset can fit in u64 since all of these are < 64.
// Unclear if it's worth it without tests.
const MULTICHAR_BITSET = make_character_bitset(MULTICHAR_SYMBOLS); // All of these chars are < 64, so truncate. TODO: Verify shift.
const MULTILINE_KEYWORD_COUNT = MULTICHAR_SYMBOLS.len; // 8
const SYMBOLS = make_character_bitset("%()*+,-./:;<=>?[]^{|}");

/// The lexer splits up an input buffer into tokens.
/// The input buffer are smaller chunks of a source file.
/// Lines are never split across chunks. The lexer yields after each line.
/// The higher level controller chooses when to split chunks or continue, passing in the appropriate context.
/// In general, we split by line-level when running in language server mode and by file when running in batch mode.
/// All output is chunk-relative - if it specifies a line number, it's line number within this chunk.
/// The lexer outputs to two queues:
/// The syntax queue, containing semantically meaningful tokens.
/// The aux queue, with tokens for comments, whitespace, etc. (used for formatting, error offsets, etc.)
/// A bit per token indicates whether the next token appears in the other queue (one token lookahead buffer).
pub const Lexer = struct {
    const Self = @This();
    buffer: []const u8, // Slice/chunk of the source file.
    syntaxQ: TokenQueue,
    auxQ: AuxQueue,
    QIdx: [2]u32, // How many tokens we've emitted to each queue for cross-references.

    prevToken: tok.AuxOrToken,
    index: u32, // Char scan index into this chunk.
    lineQIndex: u32, // syntaxIndex of the previous newline. Newlines have an offset index to the previous.
    lineChStart: u32, // Character index where this line started. For ch offset calculations.
    lineNo: u16, // Line number within this chunk. Chunks are sized so this shouldn't overflow.

    // indentStack: u64, // A tiny little stack to contain up to 21 levels of indentation. (3 bits per indent offset).
    // kind: TokenKind,
    // pub const TokenKind = enum { number, string, symbol, keyword, identifier, indent, dedent, newline, eof };

    pub fn init(buffer: []const u8, syntaxQ: TokenQueue, auxQ: AuxQueue) Self {
        const QIdx = [_]u32{ 0, 0 };
        // Initialize prev to stream start to avoid needing a null-check in every emit.
        const initialPrev = @as(u64, @bitCast(tok.auxKindToken(tok.AuxKind.sep_stream_start, 0)));
        return Self{ .buffer = buffer, .index = 0, .QIdx = QIdx, .lineQIndex = 0, .lineChStart = 0, .lineNo=0, .prevToken = initialPrev, .syntaxQ=syntaxQ, .auxQ=auxQ };
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

    fn gobble_ch(self: *Lexer, ch: u8) void {
        while (self.index < self.buffer.len) : (self.index += 1) {
            if(self.buffer[self.index] != ch) {
                break;
            }
        }
    }

    fn flushPrev(self: *Lexer, nextSyntax: bool) !void {
        print("Prev is syntax: {any} {any}\n", .{self.prevToken});
        switch (self.prevToken) {
            tok.AuxOrToken.token => |token| {
                print("Pushing to syntax queue: {d}\n", .{token});
                token.alternate = if (nextSyntax) 0 else 1;
                try self.syntaxQ.push(token);       // token vs self.prevToken
            },
            tok.AuxOrToken.aux => |aux| {
                print("Pushing to aux queue: {d}\n", .{aux});
                aux.alternate = if (nextSyntax) 1 else 0;
                try self.auxQ.push(aux);
            }
        }
    }

    // Newlines and numbers have some special behavior.
    fn emitAux(self: *Lexer, v: tok.AuxToken) !void {
        // Emit the previous token and then queue up this one.
        try self.flushPrev(false);
        self.prevToken = AuxOrToken{.aux: v};
        self.QIdx[AUX_Q] += 1;
    }
    fn emitToken(self: *Lexer, v: tok.Token) !void {
        try self.flushPrev(true);
        self.prevToken = AuxOrToken{.token: v};
        self.QIdx[SYNTAX_Q] += 1;
    }

    fn emitNumber(self: *Lexer, value: u64, auxValue: tok.AuxToken) !void {
        print("Emit number: {d} {any}\n", .{value, auxValue});
        // Numeric tokens don't have any free bits for us to set the switch-bit.
        // Assume it always indicates a 1 to "switch" to aux.
        try self.emitAux(auxValue); // The aux token can then indicate the switch-bit.

        // Emit the number token, without queuing up the prevToken.
        try self.Q[SYNTAX_Q].push(value);
        print("Syntax {any}\n", .{self.Q[SYNTAX_Q].list.items});
        print("Aux {any}\n", .{self.Q[AUX_Q].list.items});
        self.QIdx[SYNTAX_Q] += 1;
    }

    fn emitNewLine(self: *Lexer) !void {
        // Newlines have significance for error-reporting and indentation.
        // We emit them to both queues.
        // NewLine in SyntaxQueue points to AuxQueue (32bit) and offset of previous line (16)
        // NewLine in AuxQueue stores char offset (32 bit) and absolute line number cache (16 bit)
        const prevOffset = self.QIdx[SYNTAX_Q] - self.lineQIndex; // Soft assumption - max 65k tokens per line.
        const auxIndex = self.QIdx[AUX_Q] + 1;

        const syntaxNewLine = tok.createNewLine(auxIndex, @truncate(prevOffset));
        try self.emitToken(syntaxNewLine);

        try self.emitAux(tok.auxToken(tok.AuxTag.newline, self.index, self.lineNo));
        self.lineQIndex = self.QIdx[SYNTAX_Q];
        self.lineNo += 1;
        self.index += 1;
        // Points to the beginning of line rather than newline char. Stored to allow line-relative char calculations.
        self.lineChStart = self.index;
    }

    fn token_number(self: *Lexer) !void {
        // MVL just needs int support for bootstrapping. Stage1+ should parse float.
        // const offset = self.index - self.lineChStart;
        const start = self.index;
        self.index += 1; // First char is already recognized as a digit.
        self.gobble_digits();
        const len = self.index - start;

        const value: u64 = std.fmt.parseInt(u32, self.buffer[start..self.index], 10) catch 0;

        const auxTok = tok.auxKindToken(tok.AuxKind.number, @truncate(len));
        try self.emitNumber(value, auxTok);
    }

    fn token_string(self: *Lexer) !void {
        self.index += 1; // Omit beginning quote.
        const tokenStart = self.index;
        _ = self.seek_till("\"");
        const tokenLen = self.index - 1 - tokenStart;
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
        if (tokenLen > 2 ^ 16) {
            // Error: String too long.
            unreachable;
        }

        try self.emitToken(tok.stringLiteral(tokenStart, @truncate(tokenLen)));
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

    fn seek_till(self: *Lexer, ch: []const u8) void {
        while (self.index < self.buffer.len and self.buffer[self.index] != ch[0]) : (self.index += 1) {}
    }

    fn seek_till_delimiter(self: *Lexer) void {
        while (self.index < self.buffer.len and !is_delimiter(self.buffer[self.index])) : (self.index += 1) {}
    }

    fn token_identifier(self: *Lexer) !u64 {
        // TODO: Validate characters.
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

        // Max identifier length.
        if (self.index - start > 255) {
            unreachable;
        }

        try self.emitToken(tok.identifier(start, @truncate(self.index - start)));
    }

    // fn skip(self: *Lexer) void {
    //     self.index += 1;
    // }

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
        // TODO: This needs revision

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

    pub fn lex(self: *Lexer) !void {
        // if (self.index >= self.buffer.len) {
        //     if (self.depth > 0) {
        //         // Flush any remaining open blocks.
        //         return self.token_dedent(0);
        //     }

        //     return tok.SYMBOL_STREAM_END;
        // }

        while (self.index < self.buffer.len) {
            const ch = self.buffer[self.index];
            // Ignore whitespace.
            switch (ch) {
                ' ' => {
                    if (self.lineChStart == self.index) {
                        // Indentation at the start of a line is significant.
                        // const indent = self.token_indentation();
                        // if (indent != tok.SKIP_TOKEN) {
                        //     return indent;
                        // }
                    } else {
                        const start = self.index;
                        self.gobble_ch(' ');
                        const len = self.index - start;
                        try self.emitAux(tok.auxToken(tok.AuxTag.whitespace, start, @truncate(len)));
                    }
                },
                '\t' => {
                    // Tabs have no power here! We use spaces exclusively.
                    try self.emitAux(tok.auxToken(tok.AuxTag.whitespace, self.index, 1));
                    self.index += 1;
                },
                '\n' => {
                    try self.emitNewLine();
                },
                '0'...'9', '.' => {
                    try self.token_number();
                },
                '"' => {
                    try self.token_string();
                },
                else => {
                    const chByte: u7 = @truncate(@as(u8, ch));
                    const one: u128 = 1;
                    const chBit: u128 = one << chByte;
                    if (chBit | MULTICHAR_BITSET != 0) {
                        const peekCh = self.peek_ch();
                        // All of the current multi-char symbols have = as the followup char.
                        // If that changes in the future, use a lookup string indexed by chBit popcnt index.
                        if (peekCh == '=') {
                            const multiChKindVal: u8 = @truncate(@popCount(MULTICHAR_BITSET >> chByte)); // assert < MULTILINE_KEYWORD_COUNT
                            const tokenKind: tok.TokenKind = @enumFromInt(multiChKindVal);
                            // Emit the multichar symbol.
                            self.index += 2;
                            try self.emitToken(tok.createToken(tokenKind));
                            continue;
                        }

                        // Comments
                        if (ch == '/' and peekCh == '/') {
                            self.index += 2;
                            self.seek_till("\n");
                            // self.emitAux()
                        }
                    }

                    // Single-character symbols.
                    if (chBit | SYMBOLS != 0) {
                        const tokKind: u8 = @truncate(@popCount(SYMBOLS >> chByte));
                        try self.emitToken(tok.createToken(@enumFromInt(tokKind + MULTILINE_KEYWORD_COUNT)));
                        self.index += 1;
                        continue;
                    }

                    // TODO: Parse alphabetic keywords like if, for.
                    // self.token_symbol();
                    // handle cases where it's not a valid identifier and none of the recognized tokens.
                },
            }
        }


        try self.flushPrev(self.prevToken);
    }
};

// pub fn init_lexer()

const test_allocator = std.testing.allocator;
const arena_allocator = std.heap.ArenaAllocator;
const expect = std.testing.expect;

fn testTokenEquals(lexed: u64, expected: u64) !void {
    try expect(lexed == expected);
}

pub fn testLexToken(buffer: []const u8, expected: []const u64, aux: []const u64) !void {
    print("\nTest Lex Token: {s}\n", .{buffer});
    defer print("\n--------------------------------------------------------------\n", .{});

    var syntaxQ = Queue.init(test_allocator);
    var auxQ = Queue.init(test_allocator);
    var lexer = Lexer.init(buffer, &syntaxQ, &auxQ);
    // defer lexer.deinit();
    defer syntaxQ.deinit();
    defer auxQ.deinit();
    try lexer.lex();
    if (syntaxQ.list.items.len != expected.len) {
        print("\nLength mismatch {d} vs {d}", .{ syntaxQ.list.items.len, expected.len });
        for (syntaxQ.list.items) |lexedToken| {
            tok.print_token(lexedToken);
        }
    }

    print("\nSyntaxQ: {any}\n", .{syntaxQ.list.items});
    print("\nAuxQ: {any}\n", .{auxQ.list.items});

    try expect(syntaxQ.list.items.len == expected.len);
    try expect(auxQ.list.items.len == aux.len);

    for (syntaxQ.list.items, 0..) |lexedToken, i| {
        if (lexedToken != expected[i]) {
            print(".\nExpected ", .{});
            // tok.print_token(expected[i], buffer);
            print("\nLexerout ", .{});
        }
        // tok.print_token(lexedToken, buffer);
        print("\n", .{});

        try testTokenEquals(lexedToken, expected[i]);
    }
}

test "Lex digits" {

//     // "1 2 3"
    const auxNum = tok.valFromAux(tok.auxKindToken(tok.AuxKind.number, 1));

    try testLexToken("1 2 3", &[_]u64{
        1,
        2,
        3,
    }, &[_]u64{
        auxNum,
        auxNum,
        auxNum
    });

}

//     var lexer = Lexer.init("1 2 3", syntaxQ, auxQ);
//     //try expect(lexer.lex() == 1);
//     //  01234
//     // try testLexToken("1 2 3", &[_]u64{ 1, 2, 3 });
// }

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
