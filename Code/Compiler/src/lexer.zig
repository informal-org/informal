const std = @import("std");
const val = @import("value.zig");
const tok = @import("token.zig");
const q = @import("queue.zig");
const bitset = @import("bitset.zig");
const constants = @import("constants.zig");

const print = std.debug.print;
const StringArrayHashMap = std.array_hash_map.StringArrayHashMap;

const Token = tok.Token;
const TK = tok.Kind;
pub const TokenQueue = q.Queue(Token, tok.AUX_STREAM_END);

const SYNTAX_Q: u1 = 0;
const AUX_Q: u1 = 1;

const DELIMITERS = bitset.character_bitset("()[]{}\"'.,:; \t\n");
const MULTICHAR_SYMBOL_CHARS = "!*+-/<=>";
// Microoptimization - the multichar bitset can fit in u64 since all of these are < 64.
// Unclear if it's worth it without tests.
const MULTICHAR_BITSET = bitset.character_bitset(MULTICHAR_SYMBOL_CHARS); // All of these chars are < 64, so truncate. TODO: Verify shift.
const MULTICHAR_KEYWORD_COUNT = MULTICHAR_SYMBOL_CHARS.len; // 7
const SYMBOL_CHARS = "%*+,-./:<=>^|";
const SYMBOLS = bitset.character_bitset(SYMBOL_CHARS); // "%()*+,-./:;<=>?[]^{|}"
const SYMBOL_KEYWORD_COUNT = SYMBOL_CHARS.len; // 8
const GROUPING = bitset.character_bitset("()[]{}");
const IDENTIFIER_DELIIMITERS = bitset.character_bitset("()[]{}\"'.,:;\t\n%*+-/^<=>");
const IDENTIFIER_DELIIMITERS_WITH_SPACE = bitset.extend_bitset(IDENTIFIER_DELIIMITERS, " 0123456789");
const KEYWORD_DELIMITERS = bitset.extend_bitset(IDENTIFIER_DELIIMITERS, " "); // Don't add numbers here. Better to be stricter about space / symbol separated keywords.

const DEBUG = constants.DEBUG;

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
///
/// Future Optimizations:
/// Convert this to the direct-threaded tail-call style like the parser and specilize which branches you check based on what's expected.
/// Doesn't matter for jump-tables, but useful for if-else based dispatch.
/// We don't do any interning here to avoid allocations, but it may be worthwhile so the reader can
/// reuse the bytes immediately after the lexer is done with a chunk.
/// Depends on context - for IDEs and use-cases where we'll have the buffer in memory, this current approach is better.
pub const Lexer = struct {
    const Self = @This();
    buffer: []u8, // Slice/chunk of the source file.
    syntaxQ: *TokenQueue,
    auxQ: *TokenQueue,
    QIdx: [2]u32, // How many tokens we've emitted to each queue for cross-references.

    prevToken: Token,
    index: u32, // Char scan index into this chunk.
    lineQIndex: u32, // syntaxIndex of the previous newline. Newlines have an offset index to the previous.
    lineChStart: u32, // Character index where this line started. For ch offset calculations.
    lineNo: u16, // Line number within this chunk. Chunks are sized so this shouldn't overflow.

    // Interned constants.
    symbolTable: *std.StringHashMap(u64),
    // internedStrings: *std.StringHashMap(u64),
    internedStrings: *StringArrayHashMap(u64),
    internedNumbers: *std.AutoHashMap(u64, u64), // Key is the const. Val = the index.
    internedFloats: *std.AutoHashMap(f64, u64),

    indentStack: u64, // A tiny little stack to contain up to 21 levels of indentation. (3 bits per indent offset).
    depth: u16,
    // kind: TokenKind,
    // pub const TokenKind = enum { number, string, symbol, keyword, identifier, indent, dedent, newline, eof };

    pub fn init(
        //
        buffer: []u8,
        syntaxQ: *TokenQueue,
        auxQ: *TokenQueue,
        internedStrings: *StringArrayHashMap(u64),
        internedNumbers: *std.AutoHashMap(u64, u64),
        internedFloats: *std.AutoHashMap(f64, u64),
        symbolTable: *std.StringHashMap(u64),
    ) Self {
        const QIdx = [_]u32{ 0, 0 };
        // Initialize prev to stream start to avoid needing a null-check in every emit.
        // const initialPrev = @as(u64, @bitCast(tok.auxKindToken(tok.AuxKind.sep_stream_start, 0)));
        return Self{
            //
            .buffer = buffer,
            .index = 0,
            .QIdx = QIdx,
            .lineQIndex = 0,
            .lineChStart = 0,
            .lineNo = 0,
            .prevToken = tok.AUX_STREAM_START,
            .syntaxQ = syntaxQ,
            .auxQ = auxQ,
            .internedStrings = internedStrings,
            .internedNumbers = internedNumbers,
            .internedFloats = internedFloats,
            .symbolTable = symbolTable,
            .indentStack = 0,
            .depth = 0,
        };
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
            if (self.buffer[self.index] != ch) {
                break;
            }
        }
    }

    fn flushPrev(self: *Lexer, nextSyntax: bool) !void {
        if (@intFromEnum(self.prevToken.kind) < tok.AUX_KIND_START) {
            self.prevToken.aux.alt = !nextSyntax;
            try self.syntaxQ.push(self.prevToken);
        } else {
            self.prevToken.aux.alt = nextSyntax;
            try self.auxQ.push(self.prevToken);
        }
    }

    // Newlines and numbers have some special behavior.
    fn emitAux(self: *Lexer, v: Token) !void {
        // Emit the previous token and then queue up this one.
        try self.flushPrev(false);
        self.prevToken = v;
        self.QIdx[AUX_Q] += 1;
    }

    fn emitToken(self: *Lexer, v: Token) !void {
        try self.flushPrev(true);
        self.prevToken = v;
        self.QIdx[SYNTAX_Q] += 1;
    }

    // fn emitNumber(self: *Lexer, auxValue: Token) !void {
    //     print("Emit number: {d} {any}\n", .{value, auxValue});
    //     // Numeric tokens don't have any free bits for us to set the switch-bit.
    //     // Assume it always indicates a 1 to "switch" to aux.
    //     // try self.emitAux(auxValue); // The aux token can then indicate the switch-bit.
    //     try self.emitToken(auxValue);

    //     // Emit the number token, without queuing up the prevToken.
    //     // try self.Q[SYNTAX_Q].push(value);
    //     print("Syntax {any}\n", .{self.Q[SYNTAX_Q].list.items});
    //     print("Aux {any}\n", .{self.Q[AUX_Q].list.items});
    //     self.QIdx[SYNTAX_Q] += 1;
    // }

    fn emitNewLine(self: *Lexer) !void {
        // Newlines have significance for error-reporting and indentation.
        // We emit them to both queues.
        // NewLine in SyntaxQueue points to AuxQueue (32bit) and offset of previous line (16)
        // NewLine in AuxQueue stores char offset (32 bit) and absolute line number cache (16 bit)
        const prevOffset = self.QIdx[SYNTAX_Q] - self.lineQIndex; // Soft assumption - max 65k tokens per line.
        const auxIndex = self.QIdx[AUX_Q] + 1;

        const syntaxNewLine = Token.lex(tok.Kind.sep_newline, auxIndex, @truncate(prevOffset));
        try self.emitToken(syntaxNewLine);

        try self.emitAux(Token.lex(TK.aux_newline, self.index, self.lineNo));
        self.lineQIndex = self.QIdx[SYNTAX_Q];
        self.lineNo += 1;
        self.index += 1;
        // Points to the beginning of line rather than newline char. Stored to allow line-relative char calculations.
        self.lineChStart = self.index;
    }

    fn token_dot(self: *Lexer) !void {
        try switch (self.buffer[self.index]) {
            '0'...'9' => self.token_number(),
            else => {
                // Emit the dot symbol.
                try self.emitToken(tok.OP_DOT_MEMBER);
                self.index += 1;
            },
        };

        // Future: Handle .. / ...
    }

    fn token_number(self: *Lexer) !void {
        // MVL just needs int support for bootstrapping. Stage1+ should parse float.
        // const offset = self.index - self.lineChStart;
        const start = self.index;
        self.index += 1; // First char is already recognized as a digit or dot.
        self.gobble_digits();
        const len = self.index - start;
        const value: u64 = std.fmt.parseInt(u64, self.buffer[start..self.index], 10) catch 0;
        const MAX_LITERAL_NUMBER = std.math.pow(u64, 2, 16);
        // Predicate: Unary minus is handled separately. So value is always implicitly > 0.
        if (value > MAX_LITERAL_NUMBER) {
            if (DEBUG) {
                print("Add number to constant pool {d} {d}\n", .{ value, len });
            }
            // Add it to the numeric constant pool
            const constIdxEntry = self.internedNumbers.getOrPutValue(value, self.internedNumbers.count()) catch unreachable;
            const constIdx: u64 = constIdxEntry.value_ptr.*;
            try self.emitToken(Token.lex(TK.lit_number, @truncate(constIdx), 0));
        } else {
            if (DEBUG) {
                print("Emit literal number {d} {d}\n", .{ value, len });
            }
            // Emit it as an immediate value.
            try self.emitToken(Token.lex(TK.lit_number, @truncate(value), @truncate(len)));
        }
    }

    fn process_escape(ch: u8) u8 {
        return switch (ch) {
            'n' => '\n',
            't' => '\t',
            'r' => '\r',
            '\\' => '\\',
            '"' => '"',
            else => ch, // Invalid escape sequence - could add error handling here
        };
    }

    fn token_string(self: *Lexer) !void {
        self.index += 1; // Omit beginning quote
        const tokenStart = self.index;
        var escaped = false;
        var outIndex: usize = tokenStart;

        // Process string. Replaces escape sequences in-place in the input buffer to avoid extra allocations.
        // That operation is reversible if we need to unprocess it for error-reporting.
        while (self.index < self.buffer.len) {
            const ch = self.buffer[self.index];
            if (escaped) {
                // Replace escape sequence with actual character
                const processed = process_escape(ch);
                // Write back the processed character
                self.buffer[outIndex] = processed;
                outIndex += 1;
                escaped = false;
                self.index += 1;
                continue;
            }

            if (ch == '\\') {
                escaped = true;
                self.index += 1;
                continue;
            }

            if (ch == '"') {
                break;
            }

            // For non-escaped chars, only need to copy if we've processed escapes
            if (outIndex != self.index) {
                self.buffer[outIndex] = ch;
            }
            outIndex += 1;
            self.index += 1;
        }

        // Seek till the end-quote for cases when there was an escape sequence.
        if (self.index < self.buffer.len and self.buffer[self.index] == '"') {
            self.index += 1;
        } else {
            unreachable; // Error: Unterminated string
        }

        const tokenLen = outIndex - tokenStart;
        if (tokenLen > (2 << 16)) {
            unreachable; // Error: String too long
        }

        // Only slice the processed portion
        const strValue = self.buffer[tokenStart..outIndex];
        const constIdxEntry = self.internedStrings.getOrPutValue(strValue, self.internedStrings.count()) catch unreachable;
        const constIdx: u64 = constIdxEntry.value_ptr.*;
        try self.emitToken(Token.lex(TK.lit_string, @truncate(constIdx), @truncate(tokenLen)));
    }

    fn is_identifier_delimiter(ch: u8) bool {
        // No mathematical operators in MVL.
        return switch (ch) {
            '(', ')', '[', ']', '{', '}', '"', '\'', '.', ',', ':', ';', '\t', '\n' => true,
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

    fn push_identifier(self: *Lexer, start: u32) u64 {
        // Max identifier length.
        if (self.index - start > 255) {
            unreachable;
        }
        const name = self.buffer[start..self.index];
        if (DEBUG) {
            if (self.symbolTable.get(name)) |constIdx| {
                print("REF {s} => Symbol {d}\n", .{ name, constIdx });
            } else {
                print("DEF {s} => Symbol {d}\n", .{ name, self.symbolTable.count() });
            }
        }

        const constIdxEntry = self.symbolTable.getOrPutValue(name, self.symbolTable.count()) catch unreachable;
        const constIdx: u64 = constIdxEntry.value_ptr.*;
        return constIdx;
    }

    fn seek_till_identifier_delimiter(self: *Lexer) void {
        while (self.index < self.buffer.len) {
            const ch = self.buffer[self.index];
            if (IDENTIFIER_DELIIMITERS.isSet(ch)) {
                break;
            } else if (ch == ' ') {
                self.index += 1; // Single space is allowed as a separator in identifiers.
                const peekCh = self.peek_ch();
                // Check to prevent double-space in identifiers (not allowed)
                // Trailing spaces before other separators/end of buffer are disallowed as well.
                if (peekCh == 0 or IDENTIFIER_DELIIMITERS_WITH_SPACE.isSet(peekCh)) {
                    self.index -= 1; // Rewind and ignore this space.
                    break; // Break to main loop.
                }

                // Space followed by TWO or more uppercase characters is an operator.
                if (peekCh >= 'A' and peekCh <= 'Z') {
                    self.index += 1;
                    const peekCh2 = self.peek_ch();
                    // Multiple uppercase characters denote an operator.
                    if (peekCh2 >= 'A' and peekCh2 <= 'Z') {
                        // This is an operator. Rewind to before the space.
                        self.index -= 2;
                    }
                    break;
                }
            } else {
                self.index += 1;
            }
        }
    }

    fn token_identifier(self: *Lexer, start: u32) !void {
        // First char is known to not be a number.
        // Non digit or symbol start, so interpret as an identifier.
        // First part of the identifier may have been parsed when attempting to tokenize a keyword.
        _ = self.seek_till_identifier_delimiter();
        const len = self.index - start;
        const constIdx = self.push_identifier(start);
        if (self.index < self.buffer.len and self.buffer[self.index] == '(') {
            try self.emitToken(Token.lex(TK.call_identifier, @truncate(constIdx), @truncate(len)));
        } else {
            try self.emitToken(Token.lex(TK.identifier, @truncate(constIdx), @truncate(len)));
            try self.maybe_user_op_after_identifier();
        }
    }

    fn seek_till_keyword_delimiter(self: *Lexer) void {
        while (self.index < self.buffer.len) {
            const ch = self.buffer[self.index];
            if (KEYWORD_DELIMITERS.isSet(ch)) {
                break;
            }
            self.index += 1;
        }
    }
    fn token_keyword_or_identifier(self: *Lexer) !void {
        const start = self.index;
        _ = self.seek_till_keyword_delimiter();
        const len = self.index - start;
        if (len == 2) {
            const name = self.buffer[start..self.index];
            if (std.mem.eql(u8, name, "if")) {
                try self.emitToken(tok.KW_IF);
                return;
            }
        } else if (len == 4) {
            const name = self.buffer[start..self.index];
            if (std.mem.eql(u8, name, "else")) {
                try self.emitToken(tok.KW_ELSE);
                return;
            }
        }
        // Not a keyword - resume where we left off as if it's an identifier.
        try self.token_identifier(start);
    }

    fn seek_upperend(self: *Lexer) bool {
        var containsLowercase = false;
        while (self.index < self.buffer.len) {
            const ch = self.buffer[self.index];
            if (IDENTIFIER_DELIIMITERS.isSet(ch)) {
                break;
            }
            switch (ch) {
                ' ' => {
                    break;
                },
                'A'...'Z', '_' => {},
                else => {
                    containsLowercase = true;
                },
            }
            self.index += 1;
        }
        return containsLowercase;
    }

    // Tokens which may start with an uppercase letter.
    // CONSTANTS - Uppercase with no spaces.
    // Operators - like AND, OR, NOT, etc. No spaces. Must be a unary op or previous token is an identifier.
    // Types - like Int, Float, String, CamelCase etc. No spaces.
    fn token_upperstart(self: *Lexer, prevIdentifier: bool) !void {
        const start = self.index;

        // To distinguish the three cases.
        // If the entire token is uppercase AND the previous token is an identifier, it's an operator.
        // Emit special tokens for AND, OR, NOT by explicitly checking for those cases.
        // Else, all uppercase tokens are constants.
        // Tokens that start with an uppercase and have atleast one lowercase letter are types.
        // Treat single uppercase characters as constants. TBD...
        const containsLowercase = self.seek_upperend();
        const value = self.buffer[start..self.index];
        const len = self.index - start;
        if (containsLowercase) {
            // Types contain atleast one lowercase letter.
            const constIdx = self.push_identifier(start);
            try self.emitToken(Token.lex(TK.type_identifier, @truncate(constIdx), @truncate(len)));
        } else {
            // None of the built-in infix-operators contain lowercase letters.
            // StaticStringMap is another option for doing this if the number of keywords grows large.
            if (len == 2) {
                // Possibilities: AS, IN, IS, OR,
                switch (value[0]) {
                    'A' => {
                        if (value[1] == 'S') {
                            try self.emitToken(tok.OP_AS);
                            return;
                        }
                    },
                    'I' => {
                        if (value[1] == 'N') {
                            try self.emitToken(tok.OP_IN);
                            return;
                        }
                        if (value[1] == 'S') {
                            try self.emitToken(tok.OP_IS);
                            return;
                        }
                    },
                    'O' => {
                        if (value[1] == 'R') {
                            try self.emitToken(tok.OP_OR);
                            return;
                        }
                    },
                    else => {
                        // Not a built-in special case op. Handle below.
                    },
                }
            } else if (len == 3) {
                if (std.mem.eql(u8, value, "AND")) {
                    try self.emitToken(tok.OP_AND);
                    return;
                } else if (std.mem.eql(u8, value, "NOT")) {
                    try self.emitToken(tok.OP_NOT);
                    return;
                }
            }
            // Not a built-in operator.
            // Constant or operator, depending on previous token.
            if (prevIdentifier) {
                const constIdx = self.push_identifier(start);
                try self.emitToken(Token.lex(TK.op_identifier, @truncate(constIdx), @truncate(len)));
            } else {
                const constIdx = self.push_identifier(start);
                try self.emitToken(Token.lex(TK.const_identifier, @truncate(constIdx), @truncate(len)));
            }
        }
    }

    // Uppercase operators immediately after an identifier have special meaning as user-defined operators.
    // It is a contextual rule, but provides flexibility for user-defined operators.
    fn maybe_user_op_after_identifier(self: *Lexer) !void {
        if (self.index < self.buffer.len) {
            const ch = self.buffer[self.index];
            if (ch == ' ') {
                const start = self.index;
                self.gobble_ch(' ');
                const len = self.index - start;
                try self.emitAux(Token.lex(TK.aux_whitespace, start, @truncate(len)));
            }
        }
        if (self.index < self.buffer.len) {
            const ch = self.buffer[self.index];
            switch (ch) {
                'A'...'Z' => {
                    try self.token_upperstart(true);
                },
                else => {}, // Handle everything else in the main switch.
            }
        }
    }

    // fn deinit(self: *Lexer) void {
    //     // Free all allocated identifiers.
    // }

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
        return @truncate(indentLvl);
    }

    fn token_indentation(self: *Lexer) !Token {
        // TODO: This needs revision

        const indent: u16 = self.countIndentation();
        const ch = self.peek_ch();
        if (ch == '\n') {
            // Skip emitting anything when the entire line is empty.
            return tok.AUX_SKIP; // TODO: Return a special token to skip
        } else if (ch == '\t') {
            // Error on tabs - because it'll look like indentation visually, but don't have semantic meaning.
            // So either we have to raise an error error or accept tabs.
            print("Error: Mixed indentation. Use 4 spaces to align.", .{});
            // return tok.LEX_ERROR; // TODO
            return tok.AUX_SKIP;
        } else {
            if (DEBUG) {
                print("Indent: {d} Depth: {d}\n", .{ indent, self.depth });
            }
            // Count and determine if it's an indent or dedent.
            if (indent > self.depth) {
                const diff = indent - self.depth;
                if (diff > 8) {
                    // You can indent pretty far, but just can't do more than 8 spaces at a time.
                    print("Indentation level too deep. Use 4 spaces to align.", .{});
                    // return tok.LEX_ERROR;
                    return tok.AUX_SKIP;
                }
                self.tiny_stack_push(@truncate(diff));
                self.depth = indent;
                try self.emitToken(tok.GRP_INDENT);
                return tok.GRP_INDENT;
            } else if (indent < self.depth) {
                return self.token_dedent(indent);
            }
            // No special token if you're on the same indentation level.
        }

        return tok.AUX_SKIP;
    }

    fn token_dedent(self: *Lexer, indent: u16) !Token {
        var diff = self.depth - indent;
        var expectedDiff = self.tiny_stack_pop();
        if (expectedDiff == 0) {
            // If the tiny stack overflows, we'd get here.
            // FUTURE OPTIMIZATION IDEA: The tiny stack is sufficient for most normal cases.
            // As a fallback path, we can link up the indent/dedent tokens to the previous indentation
            // and track levels. You can then follow that in the slow-path after overflow to refill the tiny-stack
            // treating the stack as a cache and the linked list as the source of truth.
            print("Indentation level too deep.", .{});
            // return tok.LEX_ERROR;
            return tok.AUX_SKIP;
        }
        var dedentCount: u8 = 0;
        // Loop to pop multiple indentation levels.
        while (diff >= expectedDiff) {
            diff -= expectedDiff;
            dedentCount += 1;
            if (diff != 0) {
                expectedDiff = self.tiny_stack_pop();
            }
        }
        if (diff != 0) {
            print("Unaligned indentation. Use 4 spaces to align.", .{});
            // return tok.LEX_ERROR;
            return tok.AUX_SKIP;
        }

        self.depth = indent;
        while (dedentCount > 0) {
            try self.emitToken(tok.GRP_DEDENT);
            dedentCount -= 1;
        }
        return tok.GRP_DEDENT;
    }

    pub fn lex(self: *Lexer) !void {
        if (DEBUG) {
            print("\n------------- Lexer --------------- \n", .{});
        }
        // if (self.index >= self.buffer.len) {
        //     if (self.depth > 0) {
        //         // Flush any remaining open blocks.
        //         return self.token_dedent(0);
        //     }

        //     return tok.SYMBOL_STREAM_END;
        // }
        while (self.index < self.buffer.len) {
            const ch = self.buffer[self.index];
            // print("Char: {c} {d}\n", .{ch, self.index});
            // Ignore whitespace.
            switch (ch) {
                ' ' => {
                    if (self.lineChStart == self.index) {
                        // Indentation at the start of a line is significant.
                        _ = try self.token_indentation();
                        // self.index += 1; // TODO: Not implemented. Temporary skip.
                    } else {
                        const start = self.index;
                        self.gobble_ch(' ');
                        const len = self.index - start;
                        try self.emitAux(Token.lex(TK.aux_whitespace, start, @truncate(len)));
                    }
                },
                '\t' => {
                    // Tabs have no power here! We use spaces exclusively.
                    try self.emitAux(Token.lex(TK.aux_indentation, self.index, 1));
                    self.index += 1;
                },
                '\n' => {
                    try self.emitNewLine();
                    _ = try self.token_indentation();
                },
                '.' => {
                    try self.token_dot();
                },
                '0'...'9' => {
                    try self.token_number();
                },
                'A'...'Z' => {
                    try self.token_upperstart(false);
                },
                '"' => {
                    try self.token_string();
                },
                else => {
                    // const chByte: u7 = @truncate(@as(u8, ch));
                    // const one: u128 = 1;
                    // const chBit: u128 = one << chByte;
                    // Single-character symbols.
                    if (SYMBOLS.isSet(ch)) {
                        self.index += 1;

                        // All multichar symbol starts are a subset of the single-char symbol starts.
                        if (MULTICHAR_BITSET.isSet(ch)) {
                            const peekCh = self.peek_ch();
                            if (DEBUG) {
                                print("Multichar: {c} {c}\n", .{ ch, peekCh });
                            }
                            // All of the current multi-char symbols have = as the followup char.
                            // If that changes in the future, use a lookup string indexed by chBit popcnt index.
                            if (peekCh == '=') {
                                const tokenKind = bitset.chToKind(MULTICHAR_BITSET, ch, 0);
                                // Emit the multichar symbol.
                                self.index += 1;
                                try self.emitToken(tok.createToken(tokenKind));
                                continue;
                            }

                            // Comments
                            if (ch == '/' and peekCh == '/') {
                                self.index += 1;
                                self.seek_till("\n");
                                // self.emitAux()
                                // TODO: Emit comments.
                                continue;
                            }
                        }

                        // Single-character symbols.

                        // if (DEBUG) {
                        //     print("CH {d} index {d} enum val {d}\n", .{ ch, bitset.index128(SYMBOLS, ch), @intFromEnum(tok.TK.grp_close_brace) });
                        // }
                        const tokKind = bitset.chToKind(SYMBOLS, ch, MULTICHAR_KEYWORD_COUNT);
                        try self.emitToken(tok.createToken(tokKind));
                        // Index updated outside.
                        continue;
                    } else if (GROUPING.isSet(ch)) {
                        try self.emitToken(tok.createToken(bitset.chToKind(GROUPING, ch, tok.GROUPING_KIND_START)));
                        self.index += 1;
                        continue;
                    }

                    try self.token_keyword_or_identifier();
                },
            }
        }
        _ = try self.token_indentation();
        try self.emitAux(tok.AUX_STREAM_END);
        try self.flushPrev(false);

        if (DEBUG) {
            print("\n------------- Lexer End --------------- \n", .{});
            // Print the full interned symbol table
            print("\nInterned Symbol Table:\n", .{});
            var symbolIter = self.symbolTable.iterator();
            while (symbolIter.next()) |entry| {
                print("{d: <3} {s}\n", .{
                    entry.value_ptr.*,
                    entry.key_ptr.*,
                });
            }
        }
    }
};

const test_allocator = std.testing.allocator;
const arena_allocator = std.heap.ArenaAllocator;
const expect = std.testing.expect;
const expectEqual = std.testing.expectEqual;
const testutils = @import("testutils.zig");
const testTokenEquals = testutils.testTokenEquals;
const testQueueEquals = testutils.testQueueEquals;

// test {
//     if (constants.DISABLE_ZIG_LAZY) {
//         std.testing.refAllDecls(Lexer);
//     }
// }

pub fn testToken(buffer: []u8, expected: []const Token, aux: ?[]const Token) !void {
    // print("\nTest Lex Token: {s}\n", .{buffer});
    // defer print("\n--------------------------------------------------------------\n", .{});

    var syntaxQ = TokenQueue.init(test_allocator);
    var auxQ = TokenQueue.init(test_allocator);
    var internedStrings = StringArrayHashMap(u64).init(test_allocator);
    var internedNumbers = std.AutoHashMap(u64, u64).init(test_allocator);
    var internedFloats = std.AutoHashMap(f64, u64).init(test_allocator);
    var symbolTable = std.StringHashMap(u64).init(test_allocator);

    var lexer = Lexer.init(buffer, &syntaxQ, &auxQ, &internedStrings, &internedNumbers, &internedFloats, &symbolTable);

    // defer lexer.deinit();
    defer syntaxQ.deinit();
    defer auxQ.deinit();
    defer internedStrings.deinit();
    defer internedNumbers.deinit();
    defer internedFloats.deinit();
    defer symbolTable.deinit();
    try lexer.lex();

    try testQueueEquals(buffer, &syntaxQ, expected);
    if (aux) |auxExpected| {
        try testQueueEquals(buffer, &auxQ, auxExpected);
    }
}

test "Token equality" {
    const auxtok_bits: u64 = @bitCast(Token.lex(TK.aux_stream_end, 3, 5));
    const le_expected_bits: u64 = 0x000005_00000003_ff_00;
    try expect(auxtok_bits == le_expected_bits);

    const other_bits: u64 = @bitCast(Token.lex(TK.aux, 10, 20));
    try expect(other_bits != le_expected_bits);

    const numtok: u64 = @bitCast(Token.lex(TK.lit_number, 0, 1));
    const numother: u64 = @bitCast(Token.lex(TK.lit_number, 5, 10));
    try expect(numtok != numother);
}

test "Lex digits" {
    var buffer = "23 101 3".*;
    try testToken(&buffer, &[_]Token{
        Token.lex(TK.lit_number, 23, 2).nextAlt(),
        Token.lex(TK.lit_number, 101, 3).nextAlt(),
        Token.lex(TK.lit_number, 3, 1).nextAlt(),
    }, &[_]Token{ tok.AUX_STREAM_START.nextAlt(), Token.lex(TK.aux_whitespace, 2, 1).nextAlt(), Token.lex(TK.aux_whitespace, 6, 1).nextAlt(), tok.AUX_STREAM_END });
}

// test "Lex operator" {
//     try testToken("1+3", &[_]Token{ Token.lex(TK.lit_number, 1, 1), tok.OP_ADD, tok.nextAlt(Token.lex(TK.lit_number, 3, 1)) }, &[_]Token{ tok.nextAlt(tok.AUX_STREAM_START), tok.AUX_STREAM_END });
// }

fn testSymbol(buf: []const u8, kind: TK) !void {
    try testToken(@constCast(buf), &[_]Token{tok.createToken(kind).nextAlt()}, &[_]Token{ tok.AUX_STREAM_START.nextAlt(), tok.AUX_STREAM_END });
}

test "Lex symbols" {
    // These are mapped by ascii-order, so sensitive to adding new tokens in between.
    // If you add or remove a symbol, ensure the lexer.SYMBOLS constant is also updated
    // "%()*+,-./:<=>[]^{|}"
    // const TK = TK;

    try testSymbol("%", TK.op_mod);
    try testSymbol("(", TK.grp_open_paren);
    try testSymbol(")", TK.grp_close_paren);
    try testSymbol("*", TK.op_mul);
    try testSymbol("+", TK.op_add);
    try testSymbol(",", TK.sep_comma);
    try testSymbol("-", TK.op_sub);
    try testSymbol(".", TK.op_dot_member);
    try testSymbol("/", TK.op_div);
    try testSymbol(":", TK.op_colon_assoc);
    try testSymbol("<", TK.op_lt);
    try testSymbol("=", TK.op_assign_eq);
    try testSymbol(">", TK.op_gt);
    try testSymbol("[", TK.grp_open_bracket);
    try testSymbol("]", TK.grp_close_bracket);
    try testSymbol("^", TK.op_pow);
    try testSymbol("{", TK.grp_open_brace);
    try testSymbol("|", TK.op_choice);
    try testSymbol("}", TK.grp_close_brace);
}

// //     var lexer = Lexer.init("1 2 3", syntaxQ, auxQ);
// //     //try expect(lexer.lex() == 1);
// //     //  01234
// //     // try testToken("1 2 3", &[_]u64{ 1, 2, 3 });
// // }

test "Lex delimiters and identifiers" {
    // Delimiters , . = : and identifiers.
    // (a, bb):"
    // 01234567
    var buffer = "(a, bb):".*;
    try testToken(&buffer, &[_]Token{
        tok.createToken(TK.grp_open_paren),
        Token.lex(TK.identifier, 0, 1),
        tok.createToken(TK.sep_comma).nextAlt(),
        Token.lex(TK.identifier, 1, 2),
        tok.createToken(TK.grp_close_paren),
        tok.createToken(TK.op_colon_assoc).nextAlt(),
    }, null);
}

test "Lex assignment" {
    var buffer = "a = 1".*;
    try testToken(&buffer, &[_]Token{
        Token.lex(TK.identifier, 0, 1).nextAlt(),
        tok.createToken(TK.op_assign_eq).nextAlt(),
        Token.lex(TK.lit_number, 1, 1).nextAlt(),
    }, null);
}

test "Identifier with space" {
    // Should get lexed as a single token
    var buffer = "hello world".*;
    try testToken(&buffer, &[_]Token{
        Token.lex(TK.identifier, 0, 11).nextAlt(),
    }, null);
}

test "Identifier with trailing space" {
    // Should get lexed as a single token
    var buffer = "hello world ".*;
    try testToken(&buffer, &[_]Token{
        Token.lex(TK.identifier, 0, 11).nextAlt(),
    }, null);
}

test "Multiple multipart identifiers" {
    // Should get lexed as a single token
    // Should get parsed as identifier "a b c" + "+" + identifier "cd ef"
    var buffer = "a b c + cd efg".*;
    try testToken(&buffer, &[_]Token{
        Token.lex(TK.identifier, 0, 5).nextAlt(),
        tok.createToken(TK.op_add).nextAlt(),
        Token.lex(TK.identifier, 1, 6).nextAlt(),
    }, null);
}

// Another option is for us to just treat multiple spaces the same as a single space, but this is stricter.
test "Multiple consecutive spaces in identifier" {
    // Should treat multiple spaces as a delimiter
    var buffer = "hello  world".*;
    try testToken(&buffer, &[_]Token{
        Token.lex(TK.identifier, 0, 5).nextAlt(), // Should only capture "hello"
        Token.lex(TK.identifier, 1, 5).nextAlt(), // Should capture "world" separately
    }, null);
}

test "Keyword as identifier" {
    var buffer = "if x".*;
    try testToken(&buffer, &[_]Token{
        tok.KW_IF.nextAlt(),
        Token.lex(TK.identifier, 0, 1).nextAlt(),
    }, null);
}

test "Identifiers with operator separators" {
    var buffer = "aa OR bb".*;
    try testToken(&buffer, &[_]Token{
        Token.lex(TK.identifier, 0, 2).nextAlt(),
        tok.createToken(TK.op_or).nextAlt(),
        Token.lex(TK.identifier, 1, 2).nextAlt(),
    }, null);
}

test "Lex type" {
    var buffer = "HelloWorld".*;
    try testToken(&buffer, &[_]Token{
        Token.lex(TK.type_identifier, 0, 10).nextAlt(),
    }, null);
}

test "Lex constant" {
    var buffer = "HELLO_WORLD".*;
    try testToken(&buffer, &[_]Token{
        Token.lex(TK.const_identifier, 0, 11).nextAlt(),
    }, null);
}

test "Lex non-builtin operator" {
    var buffer = "aa SOME_OP bbb".*;
    try testToken(&buffer, &[_]Token{
        Token.lex(TK.identifier, 0, 2).nextAlt(),
        Token.lex(TK.op_identifier, 1, 7).nextAlt(),
        Token.lex(TK.identifier, 2, 3).nextAlt(),
    }, null);
}

// ================== end

// test "Lex string" {
//     // "Hello"
//     // 0123456
//     try testToken("\"Hello\"", &[_]u64{
//         val.createStringPtr(1, 5), // Doesn't include quotes.
//     });
// }

test "Test indentation" {
    // "Hello"
    // 0123456
    const source =
        \\a
        \\  b
        \\  b2
        \\     c
        \\       d
        \\  b3
    ;
    try testToken(@constCast(source), &[_]Token{
        Token.lex(TK.identifier, 0, 1), // a
        Token.lex(TK.sep_newline, 1, 1).nextAlt(),
        tok.GRP_INDENT,
        Token.lex(TK.identifier, 1, 1), // b
        Token.lex(TK.sep_newline, 2, 2).nextAlt(),
        Token.lex(TK.identifier, 2, 2), // b2
        Token.lex(TK.sep_newline, 3, 1).nextAlt(),
        tok.GRP_INDENT,
        Token.lex(TK.identifier, 3, 1), // c
        Token.lex(TK.sep_newline, 4, 2).nextAlt(),
        tok.GRP_INDENT,
        Token.lex(TK.identifier, 4, 1), // d
        Token.lex(TK.sep_newline, 5, 2).nextAlt(),
        tok.GRP_DEDENT,
        tok.GRP_DEDENT,
        Token.lex(TK.identifier, 5, 2), // b3
        tok.GRP_DEDENT.nextAlt(),
    }, null);
}
