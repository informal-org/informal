// Parser. Based on the Double-E method by Erik Eidt
// https://erikeidt.github.io/The-Double-E-Method.html
const std = @import("std");
const tok = @import("token.zig");
const lex = @import("lexer.zig");
const bitset = @import("bitset.zig");

const Token = tok.Token;
const TK = tok.Kind;
const TokenQueue = lex.TokenQueue;
const Allocator = std.mem.Allocator;
const isKind = bitset.isKind;

pub const Parser = struct {
    const Self = @This();
    buffer: []const u8,
    syntaxQ: *TokenQueue,
    parsedQ: *ParsedQueue,

    // parsed: ParsedQueue
    fn init(buffer: []const u8, syntaxQ: *TokenQueue, parsedQ: *ParsedQueue) Self {
        return Self{ .buffer = buffer, .syntaxQ = syntaxQ, .parsedQ = parsedQ };
    }
    fn deinit(_: *Self) void {}

    fn parse(self: *Self) void {
        self.parsePrefix();
    }

    fn parsePrefix(self: *Self) void {
        // parsePrefix: We're looking for a unary operator or an operand.i
        // TODO: I do wonder if combining both parsers into a labeled switch would perform better.
        const token = self.syntaxQ.pop();
        std.debug.assert(token.kind < tok.AUX_KIND_START); // Give compiler some hints on bounds so it can optimize the switch better.

        switch (token.kind) {
            .aux_stream_end => return,
            .lit_string, .lit_bool, .lit_number, .lit_null => self.literal(token),
            .identifier, .const_identifier => self.identifier(token),
            .op_not, .op_unary_minus => self.unaryOp(token),
            .grp_open_paren, .grp_open_brace, .grp_open_bracket, .grp_indent => self.grouping(token),
            // TODO: prefix keywords like class, fn
        }
        // It's important that this remains tail recursive. No further actions should occur after the switch.
    }

    fn parseInfix(self: *Self) void {
        // Looking for a binary operator or the end of an expression.
        const token = self.syntaxQ.pop();
        std.debug.assert(token.kind < tok.AUX_KIND_START);

        switch (token.kind) {
            TK.op_gte, TK.op_dbl_eq, TK.op_lte, TK.op_not_eq, TK.op_choice, TK.op_pow, TK.op_gt, TK.op_lt, TK.op_div, TK.op_dot_member, TK.op_sub, TK.op_add, TK.op_mul, TK.op_mod, TK.op_and, TK.op_or, TK.op_in, TK.op_is, TK.op_as, TK.op_identifier => self.binaryOp(token),

            TK.op_assign_eq, TK.op_div_eq, TK.op_minus_eq, TK.op_plus_eq, TK.op_mul_eq => self.assign(token),
            TK.op_colon_assoc => self.associate(token),

            TK.sep_comma, TK.sep_newline => self.separator(token),

            TK.grp_close_paren, TK.grp_close_brace, TK.grp_close_bracket, TK.grp_dedent => self.endGroup(token),
        }
        // It's important that this function remains tail recursive. No further actions should happen after the switch.
    }

    fn literal(self: *Self, token: Token) void {
        self.emit(token);
        self.parseInfix(); // Expect operator or end of state.
    }

    fn identifier(self: *Self, token: Token) void {
        // TODO: resolution
        self.emit(token);
        self.parseInfix(); // Expect operator or end of state.
    }

    fn unaryOp(self: *Self, token: Token) void {
        self.pushOp(token);
        self.parsePrefix(); // Expect more unary ops or the left side op
    }

    fn binaryOp(self: *Self, token: Token) void {
        self.pushOp(token);
        self.parsePrefix();
    }

    fn grouping(self: *Self, token: Token) void {
        // We can quickly go from the open to the close by doing -1.
        self.pushOp(token);
        self.parsePrefix(); // Treat as if it's a beginning of a sub-expression.
    }

    fn endGroup(self: *Self, token: Token) void {
        // Grouping kinds are laid out in close, open pairs. From current close, +1 gives you the open kind.
        self.parsedQ.flushUntilKind(@enumFromInt(@intFromEnum(token.kind) + 1));
        self.parseInfix(); // Treat this whole node as being a left operator. Look for the infix operand next.
    }

    fn endParse(_: *Self) void {
        // Check the parser state and make sure we're in a good terminal state.
        // i.e. no left over state.

    }

    fn assign(self: *Self, token: Token) void {
        // TODO: Self resolution
        self.pushOp(token);
        self.parsePrefix();
    }

    fn associate(self: *Self, token: Token) void {
        self.pushOp(token);
        // This set can be reduced down to just fn / class.
        self.parsedQ.flushUntil(tok.KEYWORD_START);
        self.parsePrefix();
    }

    fn separator(self: *Self, token: Token) void {
        self.parsedQ.flush(token);
        self.parsePrefix();
    }

    fn pushOp(self: *Self, token: Token) void {
        self.parsedQ.pushOp(token, self.syntaxQ.head);
    }
};

// Abstracts away a Shunting-yard style stack for managing operator precedence. Manages all of the data-structure level operations without any grammar context.
pub const ParsedQueue = struct {
    const Self = @This();
    // TODO: We can know exactly what to size this from the lexer if we can maintain a counter.
    // We take advantage of the fact that none of the precedence sensitive operators are storing anything extra in their tokens.
    // So we use the spare-space within the token to store original indexes.
    opStack: std.array_list.AlignedManaged(Token, null),
    parsedQ: *TokenQueue,
    // We no longer maintain a separate offset queue.
    // New-lines give general location. Operands are always in order. And operators carry their index within them.

    pub fn init(allocator: Allocator, parsedQ: *TokenQueue) !Self {
        // TODO: Pre-allocate capacity?
        const opStack = std.ArrayList(Token).initCapacity(allocator, 32);
        return Self{ .opStack = opStack, .parsedQ = parsedQ };
    }

    pub fn deinit(self: *Self) void {
        self.opStack.deinit();
    }

    pub fn emit(self: *Self, token: Token) void {
        // TODO: We need to ensure parsed queue is sized appropriately upfront.
        self.parsedQ.appendAssumeCapacity(token);
    }

    pub fn flush(self: *Self, token: Token) void {
        // Flush all tokens with higher precedence / associativity.
        // Those operations must be emitted/done first before the current token.
        const tokValue = @intFromEnum(token.kind);
        std.debug.assert(tokValue < tok.TBL_PRECEDENCE_FLUSH.len);
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

    pub fn flushUntil(self: *Self, set: bitset.BitSet64) !void {
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

    fn flushUntilKind(self: *Self, kind: tok.Kind) !void {
        // You could write a specialized version of this without the bitset, but this is cleaner.
        try self.flushUntil(bitset.token_bitset(&[_]tok.Kind{kind}));
    }

    pub fn pushOp(self: *Self, token: Token, index: usize) !void {
        self.flush(token);
        token.data.raw = @truncate(index);
        self.opStack.append(token);
    }

    pub fn popOp(self: *Self) !void {
        emit(self.opStack.pop() orelse return);
    }
};
