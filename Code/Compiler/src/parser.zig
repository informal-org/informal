const std = @import("std");
const val = @import("value.zig");
const tok = @import("token.zig");
const q = @import("queue.zig");
const bitset = @import("bitset.zig");
const ns = @import("namespace.zig");

const print = std.debug.print;
// const Token = tok.Token;
const Token = tok.Token;
const TK = tok.Kind;
pub const TokenQueue = q.Queue(Token, tok.AUX_STREAM_END);
pub const OffsetQueue = q.Queue(u16, 0);
const Allocator = std.mem.Allocator;

const TokBitset = bitset.BitSet64;

const isKind = bitset.isKind;

const DEBUG = false;
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
    opStack: std.ArrayList(ParseNode),

    namespace: *ns.Namespace,

    allocator: Allocator,
    index: u32,

    const ParseNode = struct {
        token: Token,
        index: usize,
    };

    pub fn init(buffer: []const u8, syntaxQ: *TokenQueue, auxQ: *TokenQueue, parsedQ: *TokenQueue, offsetQ: *OffsetQueue, allocator: Allocator, namespace: *ns.Namespace) Self {
        const opStack = std.ArrayList(ParseNode).init(allocator);
        return Self{ .buffer = buffer, .syntaxQ = syntaxQ, .auxQ = auxQ, .parsedQ = parsedQ, .offsetQ = offsetQ, .allocator = allocator, .index = 0, .opStack = opStack, .namespace = namespace };
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
        const flushBitset = tok.TBL_PRECEDENCE_FLUSH[@intFromEnum(token.kind)];
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

    fn pushOp(self: *Self, token: Token) !void {
        try self.flushOpStack(token);
        try self.opStack.append(ParseNode{ .token = token, .index = self.index });
    }

    fn popOp(self: *Self) !void {
        // TODO: We can do const-folding here by looking at the operands. If they're literals, emit the result instead of the op.
        const opNode = self.opStack.pop();
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
    // Block keywords like def, if, etc. are valid. Switch to their custom handlers.
    // ------------------------------------------
    // Invalid states:
    // Binary operators - need an operand on the left.
    // { } - Empty scope is invalid?
    // Indent - Indentation at beginning of file is invalid.
    // Separators - , ; etch are invalid at the beginning.
    /////////////////////////////////////////////
    fn initial_state(self: *Self) !void {
        const token = self.syntaxQ.pop();
        if (token.kind == tok.AUX_STREAM_END.kind) {
            return;
        }
        const kind = token.kind;
        if (isKind(tok.LITERALS, kind)) {
            if (DEBUG) {
                print("Initial state Literal: {any}\n", .{token});
            }
            try self.emitParsed(token);
            try self.expect_binary();
        } else if (isKind(tok.IDENTIFIER, kind)) {
            if (DEBUG) {
                print("Initial state - Identifier: {any}\n", .{token});
            }
            const ident = self.namespace.resolve(@truncate(self.parsedQ.list.items.len), token);
            try self.emitParsed(ident);
            try self.expect_binary();
        } else if (isKind(tok.PAREN_START, kind)) {
            print("Paren Start: {any}\n", .{token});
        } else if (isKind(tok.KEYWORD_START, kind)) {
            print("Keyword Start: {any}\n", .{token});
        } else if (isKind(tok.UNARY_OPS, kind)) {
            print("UNARY Op: {any}\n", .{token});
        } else {
            print("Invalid token: {any}\n", .{token});
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
            print("Separators: {any}\n", .{token});
            try self.flushOpStack(token);
            // Flush any operators.
            try self.initial_state();
        } else if (isKind(tok.BINARY_OPS, kind)) {
            if (DEBUG) {
                print("Expect binary - Binary op: {any}\n", .{token});
            }

            if (kind == TK.op_assign_eq) {
                // Assume - the token to the left was the identifier.
                // When we add destructuring in the future, this will need to change.
                const ident = self.namespace.declare(@truncate(self.parsedQ.list.items.len - 1), self.parsedQ.list.getLast());
                self.parsedQ.list.items[self.parsedQ.list.items.len - 1] = ident;

                try self.pushOp(token);
                try self.expect_unary();
            } else {
                try self.pushOp(token);
                try self.expect_unary();
            }
        } else {
            print("Invalid token: {any}\n", .{token});
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
            if (DEBUG) {
                print("Expect unary - Literal: {any}\n", .{token});
            }
            try self.emitParsed(token);
            try self.expect_binary();
        } else if (isKind(tok.IDENTIFIER, kind)) {
            if (DEBUG) {
                print("Expect unary - Identifier: {any}\n", .{token});
            }

            const ident = self.namespace.resolve(@truncate(self.parsedQ.list.items.len), token);
            try self.emitParsed(ident);
            try self.expect_binary();
        } else if (isKind(tok.PAREN_START, kind)) {
            print("Parser - unhandled unary - Paren Start: {any}\n", .{token});
        } else if (isKind(tok.KEYWORD_START, kind)) {
            print("Parser - unhandled unary - Keyword Start: {any}\n", .{token});
        } else if (isKind(tok.UNARY_OPS, kind)) {
            print("Parser - unhandled unary - UNARY Op: {any}\n", .{token});
        } else {
            print("Parser - unhandled unary - Invalid token: {any}\n", .{token});
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
        if (DEBUG) {
            print("\n------------- Parser --------------- \n", .{});
        }
        try self.parsedQ.push(tok.AUX_STREAM_START); // Hack - to make sure zero index is always occupied.
        try self.initial_state();

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

// pub fn testParseExpression(buffer: []const u8, expected: []const Token) !void {
//     print("\nTest Parse: {s}\n", .{buffer});
// }

pub fn testParse(buffer: []const u8, tokens: []const Token, aux: []const Token, expected: []const Token) !void {
    var syntaxQ = TokenQueue.init(test_allocator);
    try testutils.pushAll(&syntaxQ, tokens);

    var auxQ = TokenQueue.init(test_allocator);
    var parsedQ = TokenQueue.init(test_allocator);
    var offsetQ = OffsetQueue.init(test_allocator);
    var namespace = try ns.Namespace.init(test_allocator, 0, &parsedQ);
    defer syntaxQ.deinit();
    defer auxQ.deinit();
    defer parsedQ.deinit();
    defer offsetQ.deinit();
    defer namespace.deinit();
    var parser = Parser.init(buffer, &syntaxQ, &auxQ, &parsedQ, &offsetQ, test_allocator, &namespace);
    defer parser.deinit();

    try parser.parse();

    print("\nTest Parse: {s}\n", .{buffer});
    tok.print_token_queue(parsedQ.list.items, buffer);

    try testutils.testQueueEquals(buffer, &parsedQ, expected);

    // Ignore aux. Fail when we start using it in tests.
    try expect(aux.len == 0);
}

test {
    std.testing.refAllDecls(Parser);
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
