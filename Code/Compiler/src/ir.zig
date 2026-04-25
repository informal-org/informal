const std = @import("std");
const q = @import("queue.zig");
const tok = @import("token.zig");
const Allocator = std.mem.Allocator;

const Token = tok.Token;

pub const Node = packed struct(u64) {
    left: u32,
    right: u32,
};

pub const DEFAULT_NODE = Node{ .left = 0, .right = 0 };

pub const Range = packed struct(u64) {
    start: u32, // Precomputed from the results of Parser's kind count
    end: u32, // Incremented as elements are added.
};

pub const TokenQueue = q.Queue(Token, tok.AUX_STREAM_END);
pub const IRQueue = q.Queue(Node, DEFAULT_NODE);

pub const IR = struct {
    const Self = @This();
    allocator: Allocator,
    parsedQ: *TokenQueue,
    irQ: *IRQueue,
    ranges: [64]Range = [_]Range{Range{ .start = 0, .end = 0 }} ** 64,

    pub fn init(allocator: Allocator, parsedQ: *TokenQueue, irQ: *IRQueue) Self {
        return Self{
            .allocator = allocator,
            .parsedQ = parsedQ,
            .irQ = irQ,
        };
    }

    pub fn initRanges(self: *Self, kindCounts: [64]u32) void {
        // In the future, this will need more logic when certain parser-tokens map to multiple IR nodes.
        // In that case, it'd need to look at the count of all nodes which can emit that IR node and sum those.
        var tail: u32 = 0;
        for (kindCounts, 0..) |count, i| {
            self.ranges[i] = Range{ .start = tail, .end = tail };
            tail += count;
        }
    }
};
