const std = @import("std");
const tok = @import("token.zig");
const BitSet128 = @import("../bitset.zig").BitSet128;
const Token = tok.Token;
const Allocator = std.mem.Allocator;
pub const MemError = std.mem.Allocator.Error;

// Abstracts away a Shunting-yard style stack for managing operator precedence. Manages all of the data-structure level operations without any grammar context.
pub const ParsedQueue = struct {
    const Self = @This();
    allocator: Allocator,
    precedenceStack: std.array_list.Aligned(Token, null),
    parsedQ: std.array_list.Aligned(Token, null),

    pub fn init(allocator: Allocator) !Self {
        const precedenceStack = try std.array_list.Aligned(Token, null).initCapacity(allocator, 32);
        const parsedQ = try std.array_list.Aligned(Token, null).initCapacity(allocator, 64);
        return Self{ .allocator = allocator, .precedenceStack = precedenceStack, .parsedQ = parsedQ };
    }

    pub fn deinit(self: *Self) void {
        self.precedenceStack.deinit(self.allocator);
        self.parsedQ.deinit(self.allocator);
    }

    pub fn emit(self: *Self, token: Token) MemError!void {
        try self.parsedQ.append(self.allocator, token);
    }

    pub fn top(self: *Self) u7 {
        return @truncate(self.precedenceStack.items[self.precedenceStack.items.len - 1].kind);
    }

    pub fn flush(self: *Self, popset: BitSet128) MemError!void {
        while (self.precedenceStack.items.len > 0 and popset.isSet(self.top())) {
            try self.popOp();
        }
    }

    pub fn pushOp(self: *Self, token: Token, index: usize) MemError!void {
        var opToken: Token = token;
        opToken.data.raw = @truncate(index);
        // self.precedenceStack.appendAssumeCapacity(opToken);
        try self.precedenceStack.append(self.allocator, opToken);
    }

    pub fn popOp(self: *Self) MemError!void {
        try self.emit(self.precedenceStack.pop() orelse return);
    }
};
