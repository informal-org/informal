const std = @import("std");
const val = @import("value.zig");
const tok = @import("token.zig");
const q = @import("queue.zig");
const bitset = @import("bitset.zig");
const rs = @import("resolution.zig");
const constants = @import("constants.zig");

const log = std.log.scoped(.parser);
const print = std.debug.print;
// const Token = tok.Token;
const Token = tok.Token;
const TK = tok.Kind;
pub const TokenQueue = q.Queue(Token, tok.AUX_STREAM_END);
pub const OffsetQueue = q.Queue(u16, 0);
const Allocator = std.mem.Allocator;

const TokBitset = bitset.BitSet64;

const isKind = bitset.isKind;

/// The parser is solely responsible for recognizing structures and putting it in a useful form.
/// It should not concern itself with more semantic validity checks - that can come in a later stage.
/// Assumptions:
///   - Lexer combines multi-token keywords into a single token.
///   - Lexer normalizes unary minus into negative literals or a negatie multiplication. That removes a multi-role operator special-case.
/// The parser handles these semantic structures:
///   <Prefix> <Value> - Where value always denotes either a literal or an identifier.
///   <Value> <Infix> <Value>
///   <Type> (<Type>..) <Value>
///   <GroupStart> (<Value> <Separator>)+ | (<Value>) <GroupEnd> - i.e. Grouping tokens like (), {}, [], indent-dedent, etc.
///   <Keyword> (Header) ":" <Body> (<ContinuationKeyword>)
///      - The ordering in the token list should group the keywords such that startKeyword + 1 = continuationKeyword for all that have continuaton
///      - And we group those structures which have continuation separate from those without (allowing us to check what type it is just by index)
/// Some syntax notes:
/// We don't have the traditional "else if". That leads to an unbalanced visual structure.
/// Instead, we use switch/match style conditional blocks, which aligns the conditions and bodies more regularly.

// The parser takes a token stream from the lexer and converts it into a valid structure.
// It's only concerned with the grammatic structure of the code - not the meaning.
// It's a hybrid state-machine / recursive descent parser with state tables.
pub const Parser = struct {
    const Self = @This();
    buffer: []const u8,
    syntaxQ: *TokenQueue,
    auxQ: *TokenQueue,

    // The AST is stored is a postfix order - where all operands come before the operator.
    // This stack structure avoids the need for any explicit pointers for operators
    // and matches the dependency order we want to emit bytecode in and matches the order of evaluation.
    parsedQ: *TokenQueue,
    // For each token in the parsedQ, indicates where to find it in the syntaxQ.
    offsetQ: *OffsetQueue,

    // Benchmark: MultiArrayList vs ArrayList for this use-case.
    // Multi will be more compact without the padding, but we push/pop them in pairs anyway.
    opStack: std.array_list.AlignedManaged(ParseNode, null),

    resolution: *rs.Resolution,

    allocator: Allocator,
    index: u32,

    const ParseNode = struct {
        token: Token,
        index: usize,
    };

    pub fn init(buffer: []const u8, syntaxQ: *TokenQueue, auxQ: *TokenQueue, parsedQ: *TokenQueue, offsetQ: *OffsetQueue, allocator: Allocator, resolution: *rs.Resolution) Self {
        const opStack = std.array_list.AlignedManaged(ParseNode, null).init(allocator);
        return Self{ .buffer = buffer, .syntaxQ = syntaxQ, .auxQ = auxQ, .parsedQ = parsedQ, .offsetQ = offsetQ, .allocator = allocator, .index = 0, .opStack = opStack, .resolution = resolution };
    }

    pub fn deinit(self: *Self) void {
        self.opStack.deinit();
    }

    fn emitParsed(self: *Self, token: Token) !void {
        try self.parsedQ.push(token);
        try self.pushOffset(self.index);
    }

    fn pushOffset(self: *Self, index: usize) !void {
        // TODO: Bounds check
        try self.offsetQ.push(@truncate(self.offsetQ.list.items.len - index));
    }

    fn flushOpStack(self: *Self, token: Token) !void {
        // Indicates which tokens have higher-precedence and associativity.
        // Those operations must be emitted/done first before the current token.
        const tokValue = @intFromEnum(token.kind);
        if (tokValue < tok.TBL_PRECEDENCE_FLUSH.len) {
            const flushBitset = tok.TBL_PRECEDENCE_FLUSH[tokValue];
            while (self.opStack.items.len > 0) {
                const top = self.opStack.items[self.opStack.items.len - 1];
                const topKind = top.token.kind;
                if (flushBitset.isSet(@intFromEnum(topKind))) {
                    try self.popOp();
                } else {
                    break;
                }
            }
        }
    }

    fn flushUntil(self: *Self, set: bitset.BitSet64) !void {
        // Flush while will keep flushing as long as the bitset pattern is met.
        // Flush until will keep flushing until the bitset pattern is met. Then flush that and stop.
        while (self.opStack.items.len > 0) {
            const tokNode = self.opStack.items[self.opStack.items.len - 1];
            const tokKind = tokNode.token.kind;
            if (isKind(set, tokKind)) { // tok.KEYWORD_START
                try self.popOp();
                // TODO: Multi-keyword?
                break;
            }
            if (isKind(tok.GROUP_START, tokKind)) {
                // Compilation error - print token
                tok.print_token("Compilation error - UNMATCHED GROUPING: {any}\n", tokNode.token, self.buffer);
                return;
                // return error.UnmatchedGrouping;
            }
            try self.popOp();
        }
    }

    fn flushUntilToken(self: *Self, kind: tok.Kind) !void {
        log.debug("Flush until token: {any}\n", .{kind});
        // You could write a specialized version of this without the bitset, but this is cleaner.
        try self.flushUntil(bitset.token_bitset(&[_]tok.Kind{kind}));
    }

    fn pushOp(self: *Self, token: Token) !void {
        log.debug("    PUSH: {any}", .{token});
        try self.flushOpStack(token);
        try self.opStack.append(ParseNode{ .token = token, .index = self.index });
    }

    fn push(self: *Self, token: Token) !void {
        // Push without flushing
        log.debug("    PUSH: {any}\n", .{token});
        try self.opStack.append(ParseNode{ .token = token, .index = self.index });
    }

    fn popOp(self: *Self) !void {
        // TODO: We can do const-folding here by looking at the operands. If they're literals, emit the result instead of the op.
        const opNode = self.opStack.pop() orelse return;
        log.debug("    POP: {any}\n", .{opNode.token});
        try self.parsedQ.push(opNode.token);
        try self.pushOffset(opNode.index);
    }

    /////////////////////////////////////////////
    // Initial State
    // Null state at the beginning of the file;
    // Valid states:
    // Literals - Emit directly. Transition to expect_binary
    // Identifiers - Emit directly. Transition to expect after identifier.
    // ( - Push onto the stack. Transition to initial_state.
    // Unary operators.
    // // -- No longer relevant - Block keywords like def, if, etc. are valid. Switch to their custom handlers.
    // ------------------------------------------
    // Invalid states:
    // Binary operators - need an operand on the left.
    // { } - Empty scope is invalid?
    // Indent - Indentation at beginning of file is invalid.
    // Separators - , ; etch are invalid at the beginning.
    // -------------------------------------------
    fn initial_state(self: *Self) !void {
        const token = self.syntaxQ.pop();
        if (token.kind == tok.AUX_STREAM_END.kind) {
            return;
        }
        const kind = token.kind;
        if (isKind(tok.LITERALS, kind)) {
            log.debug("Initial state - Literal: {any}\n", .{token});
            try self.emitParsed(token);
            try self.expect_binary();
        } else if (isKind(tok.IDENTIFIER, kind)) {
            log.debug("Initial state - Identifier: {any}\n", .{token});
            const ident = self.resolution.resolve(@truncate(self.parsedQ.list.items.len), token);
            if (kind == TK.call_identifier) {
                // Next token is known to be an open-paren. But put it after the identifier, so it's kinda in a lispy form. (foo ...)
                const next = self.syntaxQ.pop();
                std.debug.assert(next.kind == TK.grp_open_paren);
                try self.pushOp(next);
                try self.pushOp(token);
                // TODO: Is initial state right here? Or do we want to allow indentations?
                try self.initial_state();
            } else {
                try self.emitParsed(ident);
                try self.expect_binary();
            }
        } else if (isKind(tok.PAREN_START, kind)) {
            tok.print_token("Initial state - Paren Start: {any}\n", token, self.buffer);
        } else if (isKind(tok.UNARY_OPS, kind)) {
            tok.print_token("Initial state - UNARY Op: {any}\n", token, self.buffer);
        } else if (kind == TK.sep_newline) {
            tok.print_token("Initial state - Skipping Newline: {any}\n", token, self.buffer);
            try self.initial_state();
        } else if (kind == TK.grp_indent) {
            tok.print_token("Initial state - Indent: {any}\n", token, self.buffer);
            const scopeId = self.resolution.scopeId;
            const startIdx = self.parsedQ.list.items.len;
            try self.emitParsed(tok.Token.lex(TK.grp_indent, 0, scopeId)); // We emit the indentation start right away to denote blocks.
            // TODO: Pass in the correct scope type.
            try self.resolution.startScope(rs.Scope{ .start = @truncate(startIdx), .scopeType = .block }); // TODO: Scope type
            // try self.pushOp(token);
            // We actually push the `dedent` token onto the stack instead, since that's the marker we want at the end.
            try self.pushOp(Token.lex(TK.grp_dedent, @truncate(startIdx), scopeId));
            try self.initial_state();
        } else if (kind == TK.grp_dedent) {
            tok.print_token("Initial state - Dedent: {any}\n", token, self.buffer);
            try self.flushUntilToken(TK.grp_dedent);
            try self.resolution.endScope(@truncate(self.parsedQ.list.items.len));
            try self.initial_state();
        } else {
            tok.print_token("Initial state - Invalid token: {any}\n", token, self.buffer);
        }

        // switch (token.kind) {
        //     LITERALS => {}, // self.expect_binary(token),
        //     IDENTIFIER => {}, // self.expect_after_identifier(token),
        //     PAREN_START => {}, // self.group_start(token),
        //     KEYWORD_START => {}, // self.keyword(token),
        //     _ => {} // self.expect_error(token),
        // }
    }

    /////////////////////////////////////////////
    // Expect Binary Literal Operations
    // We've seen an operand on the left. Now expecting a binary operation.
    // Valid states:
    // Binary operators:
    //     Precedence flush: Lookup current operator for a bitmask of what to flush - encodes precedence and associtivity.
    //     Check any non-matches if they're error-cases in another bitset.
    //     Push the operand onto the stack - indicate that it's a binary op (to differentiate unary vs binary -)
    //     Transition to expect_unary.
    // Separators - 1, 2
    // Invalid States:
    // Literals / Identifiers - Need a binary operator. 1 1 is invalid.
    // Unary operators. ex. True not.
    // Grouping operators. ex. 1 (...
    /////////////////////////////////////////////
    // Zig can't infer the error set due to circular refs. Propagate errors from push/pop.
    fn expect_binary(self: *Self) (std.mem.Allocator.Error)!void { // (err || error)
        const token = self.syntaxQ.pop();
        if (token.kind == tok.AUX_STREAM_END.kind) {
            // Stream end is fine. Expression is complete without continuation.
            // 1 + 1 _
            return;
        }
        // 1 __
        // "hello " ___

        const kind = token.kind;
        if (isKind(tok.SEPARATORS, kind)) {
            tok.print_token("Separators: {any}\n", token, self.buffer);
            try self.flushOpStack(token);
            // Flush any operators.
            try self.initial_state();
        } else if (isKind(tok.BINARY_OPS, kind)) {
            log.debug("Expect binary - Binary op: {any}\n", .{token});

            if (kind == TK.op_assign_eq) {
                // Assume - the token to the left was the identifier.
                // When we add destructuring in the future, this will need to change.
                // TODO: This is fairly brittle since the previous val may not be an identifier or it might be a more complex definition.
                const ident = self.resolution.declare(@truncate(self.parsedQ.list.items.len - 1), self.parsedQ.list.getLast());
                self.parsedQ.list.items[self.parsedQ.list.items.len - 1] = ident;

                try self.pushOp(token);
                try self.expect_unary();
            } else if (kind == TK.op_colon_assoc) {
                // Pop whatever keyword was on the stack.
                try self.pushOp(token);
                try self.flushUntil(tok.KEYWORD_START); // TODO: What does this become now?
                try self.initial_state();
            } else {
                try self.pushOp(token);
                try self.expect_unary();
            }
        } else if (isKind(tok.GROUP_START, kind)) {
            tok.print_token("Expect binary - Group start: {any}\n", token, self.buffer);
            if (kind == TK.grp_indent) {
                tok.print_token("Expect binary - UNEXPECTED INDENT TOKEN!: {any}\n", token, self.buffer);
            } else {
                try self.pushOp(token);
                try self.initial_state();
            }
        } else if (isKind(tok.GROUP_END, kind)) {
            tok.print_token("Expect binary - Group end: {any}\n", token, self.buffer);
            try self.flushUntil(tok.GROUP_START);
            // TODO: Should this contain indent as well?
            const expectedStart = switch (kind) {
                TK.grp_close_brace => TK.grp_open_brace,
                TK.grp_close_paren => TK.grp_open_paren,
                TK.grp_close_bracket => TK.grp_open_bracket,
                else => unreachable,
            };

            // Pop off the grouping tokens from the parsedQ - we don't need them anymore.
            // Make sure the token at the end matches.
            const top = self.parsedQ.popLast();
            _ = self.offsetQ.popLast();
            // TODO: Long-term, we'll want some kind of error-recovery here to keep parsing.
            if (top.kind != expectedStart) {
                tok.print_token("Compilation error - UNMATCHED GROUPING: {any}\n", token, self.buffer);
                return;
                // return error.UnmatchedGrouping;
            }

            try self.initial_state();
        } else {
            tok.print_token("Invalid token: {any}\n", token, self.buffer);
        }
    }

    /////////////////////////////////////////////
    // Expect Identifier Operations
    // We've seen an identifier to the left. You can do an operation on it.
    // Or it might be a function call foo()
    // Or an index access. foo[0]
    // Or a declaration like class foo {} (TODO: Needs more thought...)
    // Separators - a, b = 1, 2
    // Invalid states:
    // Other identifiers or literals.
    // Unary operators.
    fn expect_unary(self: *Self) !void {
        const token = self.syntaxQ.pop();
        if (token.kind == tok.AUX_STREAM_END.kind) {
            return;
        }
        const kind = token.kind;

        // Pretty similar to the initial state.
        if (isKind(tok.LITERALS, kind)) {
            log.debug("Expect unary - Literal: {any}\n", .{token});
            try self.emitParsed(token);
            try self.expect_binary();
        } else if (isKind(tok.IDENTIFIER, kind)) {
            log.debug("Expect unary - Identifier: {any}\n", .{token});

            const ident = self.resolution.resolve(@truncate(self.parsedQ.list.items.len), token);
            try self.emitParsed(ident);
            try self.expect_binary();
        } else if (isKind(tok.PAREN_START, kind)) {
            tok.print_token("Parser - unhandled unary - Paren Start: {any}\n", token, self.buffer);
        } else if (isKind(tok.KEYWORD_START, kind)) {
            tok.print_token("Parser - unhandled unary - Keyword Start: {any}\n", token, self.buffer);
        } else if (isKind(tok.UNARY_OPS, kind)) {
            tok.print_token("Parser - unhandled unary - UNARY Op: {any}\n", token, self.buffer);
        } else {
            print("Parser - unhandled unary at {d} - Invalid token: {any}\n", .{ self.index, token });
        }
    }

    /////////////////////////////////////////////
    // Expect Binary String Operations
    // We've seen a string literal. You can index it, or call string functions on it.
    // Allow [] and . operations and other binary functions like +, and, etc.
    /////////////////////////////////////////////

    /////////////////////////////////////////////
    // Expect Right Unary Operations. a op ___
    // We're in the middle of an expression. There may be an operator to the left.
    // Valid states:
    // Unary operators:
    //     Precedence flush.
    // Literals:
    //     Numeric -> Expect binary literal operations.
    //     String -> Expect binary string operations.
    // Keyword starts - sub-expressions which will give a value. x + if y then z else w
    // Identifiers: -> Expect identifier operations
    // Grouping is valid. i.e. 1 * (2 + 3)
    // Invalid states:
    // Binary operators.
    // Indentation, separators, {}, [].
    // Keyword continuations - i.e. a + else

    /////////////////////////////////////////////
    // Expect assignment right. a = ___
    // We're at an assignment operator.
    // Mark the currently open line or group as containing an assignment.
    // This allows the symbol-resolution to recognize declaration vs reference without lookahead.
    // That'll also support de-structuring like [a, b, c] = ...
    /////////////////////////////////////////////

    // Initialize the parser state.
    // Note: All sub-parse functions MUST be tail-recursive, in a direct-threaded style.
    // Each state function should process a token at a time, with no lookahead or backtracking.
    pub fn parse(self: *Self) !void {
        log.debug("\n------------- Parser --------------- \n", .{});
        try self.parsedQ.push(tok.AUX_STREAM_START); // Hack - to make sure zero index is always occupied.
        try self.initial_state();
        log.debug("-- End flush --\n", .{});

        // At the end - flush the operator stack.
        // TODO: Validate that it contains no brackets (indicates open without close), etc.
        while (self.opStack.items.len > 0) {
            try self.popOp();
        }
    }
};

const test_allocator = std.testing.allocator;
const expect = std.testing.expect;
const expectEqual = std.testing.expectEqual;
const testutils = @import("testutils.zig");

pub const std_options = .{
    .log_level = .debug,
};

fn enableDebugLog() void {
    std.testing.log_level = .debug;
}

// pub fn testParseExpression(buffer: []const u8, expected: []const Token) !void {
//     print("\nTest Parse: {s}\n", .{buffer});
// }

pub fn testParse(buffer: []const u8, tokens: []const Token, aux: []const Token, expected: []const Token) !void {
    enableDebugLog();
    var syntaxQ = TokenQueue.init(test_allocator);
    try testutils.pushAll(&syntaxQ, tokens);

    var auxQ = TokenQueue.init(test_allocator);
    var parsedQ = TokenQueue.init(test_allocator);
    var offsetQ = OffsetQueue.init(test_allocator);
    var resolution = try rs.Resolution.init(test_allocator, 0, &parsedQ);
    defer syntaxQ.deinit();
    defer auxQ.deinit();
    defer parsedQ.deinit();
    defer offsetQ.deinit();
    defer resolution.deinit();
    var parser = Parser.init(buffer, &syntaxQ, &auxQ, &parsedQ, &offsetQ, test_allocator, &resolution);
    defer parser.deinit();

    try parser.parse();

    print("\nTest Parse: {s}\n", .{buffer});
    tok.print_token_queue(parsedQ.list.items, buffer);

    try testutils.testQueueEquals(buffer, &parsedQ, expected);

    // Ignore aux. Fail when we start using it in tests.
    try expect(aux.len == 0);
}

test {
    if (constants.DISABLE_ZIG_LAZY) {
        std.testing.refAllDecls(Parser);
    }
}

test "Parse basic add" {
    const buffer = "1+3";
    const tokens = &[_]Token{ Token.lex(TK.lit_number, 0, 1), tok.createToken(TK.op_add), Token.lex(TK.lit_number, 2, 1).nextAlt() };

    const aux = &[_]Token{};

    const expected = &[_]Token{
        tok.AUX_STREAM_START,
        Token.lex(TK.lit_number, 0, 1),
        // next-alt bit doesn't have much meaning in the parsed expr...
        Token.lex(TK.lit_number, 2, 1).nextAlt(),
        tok.createToken(TK.op_add),
    };

    try testParse(buffer, tokens, aux, expected);
}

test "Parse math op precedence" {
    const buffer = "1+2*3";
    const tokens = &[_]Token{
        Token.lex(TK.lit_number, 0, 1),
        tok.createToken(TK.op_add),
        Token.lex(TK.lit_number, 2, 1),
        tok.createToken(TK.op_mul),
        Token.lex(TK.lit_number, 4, 1),
    };

    const aux = &[_]Token{};
    // Ensure multiply before add.
    const expected = &[_]Token{ tok.AUX_STREAM_START, Token.lex(TK.lit_number, 0, 1), Token.lex(TK.lit_number, 2, 1), Token.lex(TK.lit_number, 4, 1), tok.createToken(TK.op_mul), tok.createToken(TK.op_add) };

    try testParse(buffer, tokens, aux, expected);
}
