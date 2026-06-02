const std = @import("std");
const tok = @import("../token.zig");
const KindRanges = @import("ir/kind_ranges.zig").KindRanges;
const TokenQueue = @import("lexer.zig").TokenQueue;

const Allocator = std.mem.Allocator;
const Token = tok.Token;
const TokenList = std.array_list.Aligned(Token, null);
const IRIndexStack = std.array_list.Aligned(u24, null);

pub const IRQueue = struct {
    const Self = @This();
    kindCounts: *KindRanges,
    opStack: IRIndexStack,
    tokensByKind: TokenList,

    pub fn init(allocator: Allocator, kindCounts: *KindRanges, maxOpStreak: usize, length: usize) !Self {
        kindCounts.lockRanges();
        const opStack = try IRIndexStack.initCapacity(allocator, maxOpStreak);
        const irq = try TokenList.initCapacity(allocator, length);
        return Self{ .kindCounts = kindCounts, .opStack = opStack, .tokensByKind = irq };
    }

    pub fn deinit(self: *Self, allocator: Allocator) !void {
        self.opStack.deinit(allocator);
        self.tokensByKind.deinit(allocator);
    }

    pub fn emitKind(self: *Self, token: Token) void {
        // Literals and identifiers are emitted directly.
        const index = self.kindCounts.incKind(token.kind);
        std.debug.assert(index < self.tokensByKind.items.len);
        self.tokensByKind.items[index] = token;
        self.opStack.appendAssumeCapacity(@truncate(index));
    }

    pub fn emitBinary(self: *Self, token: Token) void {
        // Consume two things from the stack and add refs to it in the token. Then push this onto the stack.
        // TODO: Error handling
        const right = self.opStack.pop() orelse unreachable;
        const left = self.opStack.pop() orelse unreachable;
        const binOp = token.ir(token, left, right);
        self.emitKind(binOp);
    }

    pub fn emitUnary(self: *Self, token: Token) void {
        // TODO: Error handling
        const left = self.opStack.pop() orelse unreachable;
        self.emitKind(token.ir(token, left, 0));
    }
};
