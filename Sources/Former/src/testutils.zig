const tok = @import("token.zig");
const std = @import("std");
const q = @import("queue.zig");

const Token = tok.Token;
pub const TokenQueue = q.Queue(Token, tok.AUX_STREAM_END);
const print = std.debug.print;


const test_allocator = std.testing.allocator;
const arena_allocator = std.heap.ArenaAllocator;
const expect = std.testing.expect;
const expectEqual = std.testing.expectEqual;

pub fn testTokenEquals(lexed: Token, expected: Token) !void {
    const lexBits: u64 = @bitCast(lexed);
    const expectedBits: u64 = @bitCast(expected);
    try expectEqual(lexBits, expectedBits);
}

pub fn testQueueEquals(buffer: []const u8, resultQ: *TokenQueue, expected: []const Token) !void {
    if (resultQ.list.items.len != expected.len) {
        print("\nSyntax Queue - Length mismatch {d} vs {d}\n", .{ resultQ.list.items.len, expected.len });
        for (resultQ.list.items) |lexedToken| {
            tok.print_token(lexedToken, buffer);
            print("\n", .{});
        }
    }

    try expectEqual(resultQ.list.items.len, expected.len);

    for (resultQ.list.items, 0..) |lexedToken, i| {
        const lexBits: u64 = @bitCast(lexedToken);
        const expectedBits: u64 = @bitCast(expected[i]);
        if (lexBits != expectedBits) {
            print("\nLexed: ", .{});
            tok.print_token(lexedToken, buffer);
            print(".\nExpected: ", .{});
            tok.print_token(expected[i], buffer);
            print(".\n", .{});
            // print("\nLexerout ", .{});
        }
        // tok.print_token(lexedToken, buffer);
        try testTokenEquals(lexedToken, expected[i]);
    }
}

pub fn pushAll(queue: *TokenQueue, tokens: []const Token) !void {
    for (tokens) |token| {
        try queue.push(token);
    }
}