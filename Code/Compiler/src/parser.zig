// Parser. Based on the Double-E method by Erik Eidt
// https://erikeidt.github.io/The-Double-E-Method.html
const std = @import("std");
const tok = @import("token.zig");
const bitset = @import("bitset.zig");
const TokenQueue = @import("lexer.zig").TokenQueue;
const KindRanges = @import("ir/kind_ranges.zig").KindRanges;

const Token = tok.Token;
const Kind = tok.Kind;
const Allocator = std.mem.Allocator;
const isKind = bitset.isKind;

pub const Parser = struct {
    const Self = @This();
    buffer: []const u8,
    syntaxQ: *TokenQueue,
    parsedQ: *ParsedQueue,

    // parsed: ParsedQueue
    pub fn init(buffer: []const u8, syntaxQ: *TokenQueue, parsedQ: *ParsedQueue) Self {
        return Self{ .buffer = buffer, .syntaxQ = syntaxQ, .parsedQ = parsedQ };
    }
    fn deinit(_: *Self) void {}

    pub fn parse(self: *Self) void {
        self.parsePrefix();
    }

    fn parsePrefix(self: *Self) void {
        // parsePrefix: We're looking for a unary operator or an operand.i
        // TODO: I do wonder if combining both parsers into a labeled switch would perform better.
        const token = self.syntaxQ.pop();
        if (token.kind == .aux_stream_end) return;
        std.debug.assert(@intFromEnum(token.kind) < tok.AUX_KIND_START); // Give compiler some hints on bounds so it can optimize the switch better.

        switch (token.kind) {
            .lit_string, .lit_bool, .lit_number, .lit_null => self.literal(token),
            .identifier, .const_identifier => self.identifier(token),
            .op_not, .op_unary_minus => self.unaryOp(token),
            .grp_open_paren, .grp_open_brace, .grp_open_bracket, .grp_indent => self.grouping(token),
            else => return,
            // TODO: prefix keywords like class, fn
        }
        // It's important that this remains tail recursive. No further actions should occur after the switch.
    }

    fn parseInfix(self: *Self) void {
        // Looking for a binary operator or the end of an expression.
        const token = self.syntaxQ.pop();
        if (token.kind == .aux_stream_end) {
            self.parsedQ.flushAll();
            return;
        }
        std.debug.assert(@intFromEnum(token.kind) < tok.AUX_KIND_START);

        switch (token.kind) {
            .op_gte, .op_dbl_eq, .op_lte, .op_not_eq, .op_choice, .op_pow, .op_gt, .op_lt, .op_div, .op_dot_member, .op_sub, .op_add, .op_mul, .op_mod, .op_and, .op_or, .op_in, .op_is, .op_as, .op_identifier => self.binaryOp(token),

            .op_assign_eq, .op_div_eq, .op_minus_eq, .op_plus_eq, .op_mul_eq => self.assign(token),
            .op_colon_assoc => self.associate(token),

            .sep_comma, .sep_newline => self.separator(token),

            .grp_close_paren, .grp_close_brace, .grp_close_bracket, .grp_dedent => self.endGroup(token),
            else => return,
        }
        // It's important that this function remains tail recursive. No further actions should happen after the switch.
    }

    fn emit(self: *Self, token: Token) void {
        self.parsedQ.emit(token);
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
    opStack: std.array_list.Aligned(Token, null),
    kindCounts: *KindRanges,
    parsedQ: *TokenQueue,
    // We no longer maintain a separate offset queue.
    // New-lines give general location. Operands are always in order. And operators carry their index within them.

    pub fn init(allocator: Allocator, parsedQ: *TokenQueue, kindCounts: *KindRanges) !Self {
        const opStack = try std.array_list.Aligned(Token, null).initCapacity(allocator, 32);
        return Self{ .opStack = opStack, .parsedQ = parsedQ, .kindCounts = kindCounts };
    }

    pub fn deinit(self: *Self, allocator: Allocator) void {
        self.opStack.deinit(allocator);
    }

    pub fn reset(self: *Self) void {
        self.opStack.clearRetainingCapacity();
    }

    pub fn reserve(self: *Self, allocator: Allocator, maxOpStreak: usize) !void {
        std.log.info("Reserving opstack capacity for {d}", .{maxOpStreak});
        // We know the longest streak of operators after lexing (breaking on newlines).
        try self.opStack.ensureTotalCapacityPrecise(allocator, maxOpStreak);
    }

    pub fn emit(self: *Self, token: Token) void {
        // Reader ensures parsedQ is sized appropriately by lexed size.
        self.emitAs(token, token.kind);
    }

    pub fn emitAs(self: *Self, token: Token, kind: Kind) void {
        self.parsedQ.push(token);
        _ = self.kindCounts.incKind(kind);
    }

    pub fn flush(self: *Self, token: Token) void {
        // Flush all tokens with higher precedence / associativity.
        // Those operations must be emitted/done first before the current token.
        const tokValue = @intFromEnum(token.kind);
        std.debug.assert(tokValue < tok.TBL_PRECEDENCE_FLUSH.len);
        const flushBitset = tok.TBL_PRECEDENCE_FLUSH[tokValue];
        while (self.opStack.items.len > 0) {
            const top = self.opStack.items[self.opStack.items.len - 1];
            const topKind = top.kind;
            if (flushBitset.isSet(@intFromEnum(topKind))) {
                self.popOp();
            } else {
                break;
            }
        }
    }

    pub fn flushUntil(self: *Self, set: bitset.BitSet64) void {
        // Flush while will keep flushing as long as the bitset pattern is met.
        // Flush until will keep flushing until the bitset pattern is met. Then flush that and stop.
        while (self.opStack.items.len > 0) {
            const tokNode = self.opStack.items[self.opStack.items.len - 1];
            const tokKind = tokNode.kind;
            if (isKind(set, tokKind)) { // tok.KEYWORD_START
                self.popOp();
                // TODO: Multi-keyword?
                break;
            }
            if (isKind(tok.GROUP_START, tokKind)) {
                // Compilation error - print token
                tok.print_token("Compilation error - UNMATCHED GROUPING: {any}\n", tokNode, "");
                return;
                // return error.UnmatchedGrouping;
            }
            self.popOp();
        }
    }

    fn flushUntilKind(self: *Self, kind: tok.Kind) void {
        // You could write a specialized version of this without the bitset, but this is cleaner.
        self.flushUntil(bitset.token_bitset(&[_]tok.Kind{kind}));
    }

    pub fn flushAll(self: *Self) void {
        while (self.opStack.items.len > 0) {
            self.popOp();
        }
    }

    pub fn pushOp(self: *Self, token: Token, index: usize) void {
        self.flush(token);
        var opToken = token;
        opToken.data.raw = @truncate(index);
        self.opStack.appendAssumeCapacity(opToken);
    }

    pub fn popOp(self: *Self) void {
        self.emit(self.opStack.pop() orelse return);
    }
};
