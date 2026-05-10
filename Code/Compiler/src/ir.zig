// Intermediate representation
// We use a unique representation, with a bit of sea-of-nodes, bit of SSA, bit of continuation passing and more
// You'll notice that IR nodes don't have a "kind" at all.
// Instead, what we do is put all IR nodes of a certain kind in the same range.
// So if you need to iterate over all memory-stores, that's easy to do.
// And we save a byte from the IR nodes this way.
// And it's possible to just look at a value and tell what op it was from.
// Sorting each section also makes certain optimizations easier.

// TODO:
// 1. The IR should only contain non-constant ops. Anything operation where both sides are a constant should get folded during construction
// and replaced with the constant value, with maybe a graveyard symbol where it used to be to be cleaned up later on.
//
// 2. Each identifier needs a use-def chain. We do this by linking IR nodes together. The actual symbols are no longer relevant.
// Def: Value op index, tail ref - last reference so far. Initialized as itself.
// Ref: Referenced at index, Prev ref. First one points to the declaration.
//
// 3. All calls and jumps are modeled as message send/receive in the actor sense. It's similar to continuation passing style, or blocks with params.
// Send: Call Frame index, Prev send to this same destination.
// Receive: Tail send to this destination - initialized as itself. Continuation target - either the next "send" to call or a phi-node from the input frame.
// Receives don't explicit store their params, but each receive-index is 1:1 with a paramFrame index, so you can simply lookup by index.
//
// 4. Frames: Composed of
// Frame: Args index, arg count.
// Param: Equivalent of phi. Something with many variants.
// Arg tail, ref tail
// Arg: Instance of a param. Value, prev param arg.
//
// Convention - first arg is always the value. Second is linkage or secondary value.

const std = @import("std");
const q = @import("queue.zig");
const irq = @import("irq.zig");
const tok = @import("token.zig");
const Allocator = std.mem.Allocator;

const Token = tok.Token;
const TK = tok.Kind;
const Node = irq.Node;
const args = irq.args;

pub const TokenQueue = q.Queue(Token, tok.AUX_STREAM_END);
pub const IRQueue = irq.IRQueue(Node);
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

    pub fn calcKindCounts(kindCounts: [64]u32) [64]u32 {
        // Takes parser-maintained kind counts and returns IR kind counts.
        // In the future, this will need more logic when certain parser-tokens map to multiple IR nodes.
        // In that case, it'd need to look at the count of all nodes which can emit that IR node and sum those.
        var counts = kindCounts;
        counts[@intFromEnum(TK.ir_frame)] += 1; // At least one exit frame.
        counts[@intFromEnum(TK.ir_send)] += 1; // Send results to exit.
        return counts;
    }

    pub fn reserve(self: *Self, kindCounts: [64]u32) !void {
        try self.irQ.reserve(self.allocator, kindCounts, MAX_DEPTH);
    }

    pub fn lower(self: *Self) void {
        // Walk the parsed queue to lower to IR.
        // Two options: Reverse recursive which dispatches recursion for each arg to parse.
        // Or: explicit stack and forward walk.
        // Stack maintains each argument to be consumed.
        for (self.parsedQ.list.items, 0..) |token, index| {
            switch (token.kind) {
                TK.lit_number => {
                    // TODO: Larger 64 bit constants can be emitted directly in this space as well.
                    const constIndex = self.irQ.emitKind(token.kind, args(token.data.literal.value, 0));
                    self.irQ.pushArg(constIndex, index);
                },
                TK.op_add, TK.op_mul, TK.op_gt => {
                    const opNode = self.irQ.popBinary();
                    const opIndex = self.irQ.emitKind(token.kind, opNode);
                    self.irQ.pushArg(opIndex, index);
                },
                else => {},
            }
        }
    }
};
