// Intermediate representation
// We use a unique representation, with a bit of sea-of-nodes, bit of SSA, bit of continuation passing and more
// You'll notice that IR nodes don't have a "kind" at all.
// Instead, what we do is put all IR nodes of a certain kind in the same range.
// So if you need to iterate over all memory-stores, that's easy to do.
// And we save a byte from the IR nodes this way.
// And it's possible to just look at a value and tell what op it was from.
// Sorting each section also makes certain optimizations easier.

const std = @import("std");
const q = @import("queue.zig");
const tok = @import("token.zig");
const Allocator = std.mem.Allocator;

const Token = tok.Token;
const TK = tok.Kind;

pub const Node = packed struct(u64) {
    left: u32,
    right: u32,
};

pub const DEFAULT_NODE = Node{ .left = 0, .right = 0 };
pub const TokenQueue = q.Queue(Token, tok.AUX_STREAM_END);
pub const IRQueue = q.Queue(Node, DEFAULT_NODE);

// pub const IRKind = enum(u8) {
//     //
//     op_gte,
//     op_dbl_eq,
//     op_lte,
//     op_div_eq,
// };

pub const IR = struct {
    const Self = @This();
    allocator: Allocator,
    parsedQ: *TokenQueue,
    irQ: *IRQueue,

    pub fn init(allocator: Allocator, parsedQ: *TokenQueue, irQ: *IRQueue) Self {
        return Self{
            .allocator = allocator,
            .parsedQ = parsedQ,
            .irQ = irQ,
        };
    }

    pub fn initRanges(kindCounts: [64]u32) [64]u32 {
        // In the future, this will need more logic when certain parser-tokens map to multiple IR nodes.
        // In that case, it'd need to look at the count of all nodes which can emit that IR node and sum those.
        var ranges: [64]u32 = [0]**64;
        var tail: u32 = 0;
        for (kindCounts, 0..) |count, i| {
            ranges[i] = tail;
            tail += count;
        }

        return ranges;
    }

    pub fn pushKind(self: *Self, kind: TK) void {
        // Future; We'll need separate kinds at the IR level.
        const index = self.ranges[@intFromEnum(kind)].end;
        self.ranges[@intFromEnum(kind)].end += 1;
    }

    pub fn lower(self: *Self) void {
        // Lower the parsed tokens into IR representation
        for (self.parsedQ.list.items, 0..) |token, index| {
            switch (token.kind) {
                TK.lit_number => {},
            }
        }
    }
};
