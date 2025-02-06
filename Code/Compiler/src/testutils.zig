const tok = @import("token.zig");
const std = @import("std");
const q = @import("queue.zig");

// const Token = tok.Token;
const LexToken = tok.Token;
const TokenWriter = tok.TokenWriter;
pub const TokenQueue = q.Queue(LexToken, tok.AUX_STREAM_END);
const print = std.debug.print;

const test_allocator = std.testing.allocator;
const arena_allocator = std.heap.ArenaAllocator;
const expect = std.testing.expect;
const expectEqual = std.testing.expectEqual;

pub fn testTokenEquals(lexed: LexToken, expected: LexToken) !void {
    const lexBits: u64 = @bitCast(lexed);
    const expectedBits: u64 = @bitCast(expected);
    try expectEqual(expectedBits, lexBits);
}

pub fn testQueueEquals(buffer: []const u8, resultQ: *TokenQueue, expected: []const LexToken) !void {
    if (resultQ.list.items.len != expected.len) {
        print("\nSyntax Queue - Length mismatch {d} vs {d}\n", .{ resultQ.list.items.len, expected.len });
        for (resultQ.list.items) |lexedToken| {
            print("\n {any}", .{TokenWriter{ .token = lexedToken, .buffer = buffer }});
        }
    }

    try expectEqual(expected.len, resultQ.list.items.len);

    for (resultQ.list.items, 0..) |lexedToken, i| {
        const lexBits: u64 = @bitCast(lexedToken);
        const expectedBits: u64 = @bitCast(expected[i]);
        if (lexBits != expectedBits) {
            print("\nMismatch at index {d}", .{i});
            print("\n    Lexed: {any}", .{TokenWriter{ .token = lexedToken, .buffer = buffer }});
            print("\n    Expected: {any}\n", .{TokenWriter{ .token = expected[i], .buffer = buffer }});
        }
        // tok.print_token(lexedToken, buffer);
        try testTokenEquals(lexedToken, expected[i]);
    }
}

pub fn pushAll(queue: *TokenQueue, tokens: []const LexToken) !void {
    for (tokens) |token| {
        try queue.push(token);
    }
}
