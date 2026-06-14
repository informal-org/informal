const std = @import("std");
const tok = @import("../token.zig");
const KindRanges = @import("kind_ranges.zig").KindRanges;
const TokenQueue = @import("../lexer.zig").TokenQueue;

const Allocator = std.mem.Allocator;
const Token = tok.Token;
const TokenList = std.array_list.Aligned(Token, null);
const IRIndexStack = std.array_list.Aligned(u24, null);

pub const IRQueue = struct {
    const Self = @This();
    kindCounts: *KindRanges,
    kindCursor: KindRanges,
    opStack: IRIndexStack,
    tokensByKind: TokenList,

    pub fn init(allocator: Allocator, kindCounts: *KindRanges, maxOpStreak: usize, length: usize) !Self {
        const kindCursor = kindCounts.lockRanges();
        // TODO: We can probably just eliminate length param.
        std.debug.assert(kindCursor.kindRanges[63] == length);
        const opStack = try IRIndexStack.initCapacity(allocator, maxOpStreak);
        var irq = try TokenList.initCapacity(allocator, length);
        const EMPTY_TOKEN = Token.lex(tok.Kind.aux_skip, 0, 0);
        irq.appendNTimesAssumeCapacity(EMPTY_TOKEN, length);
        return Self{ .kindCounts = kindCounts, .kindCursor = kindCursor, .opStack = opStack, .tokensByKind = irq };
    }

    pub fn deinit(self: *Self, allocator: Allocator) void {
        self.opStack.deinit(allocator);
        self.tokensByKind.deinit(allocator);
    }

    pub fn emitKind(self: *Self, token: Token) void {
        // Literals and identifiers are emitted directly.
        const index = self.kindCursor.incKind(token.kind);
        // std.debug.assert(index < self.tokensByKind.items.len);
        self.tokensByKind.items[index] = token;
        self.opStack.appendAssumeCapacity(@truncate(index));
    }

    pub fn emitBinary(self: *Self, token: Token) void {
        // Consume two things from the stack and add refs to it in the token. Then push this onto the stack.
        // TODO: Error handling
        const right = self.opStack.pop() orelse unreachable;
        const left = self.opStack.pop() orelse unreachable;
        const binOp = token.ir(left, right);
        self.emitKind(binOp);
    }

    pub fn emitUnary(self: *Self, token: Token) void {
        // TODO: Error handling
        const left = self.opStack.pop() orelse unreachable;
        self.emitKind(token.ir(token, left, 0));
    }
};
