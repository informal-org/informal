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
const irq = @import("irq.zig");
const tok = @import("token.zig");
const Allocator = std.mem.Allocator;

const Token = tok.Token;
const TK = tok.Kind;
const Node = irq.Node;

pub const DEFAULT_NODE = Node{ .left = 0, .right = 0 };
pub const TokenQueue = q.Queue(Token, tok.AUX_STREAM_END);
pub const IRQueue = q.Queue(Node, DEFAULT_NODE);
const MAX_DEPTH = 128; // Ideally computed from the parser so it's never reached here.

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
        // Takes token kind counts and returns IR kind counts.
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

    pub fn reserve(self: *Self, irKindCounts: [64]u32) !void {
        try self.irQ.reserve(irKindCounts, MAX_DEPTH);
    }

    pub fn lower(self: *Self) void {
        // Walk the parsed queue to lower to IR.
        // Two options: Reverse recursive which dispatches recursion for each arg to parse.
        // Or: explicit stack and forward walk.
        // Stack maintains each argument to be consumed.
        for (self.parsedQ.list.items, 0..) |token, index| {
            switch (token.kind) {
                TK.lit_number => {},
            }
        }
    }
};
