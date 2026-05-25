// IR lowering — see Docs/Specs/ir.md for the full specification.
//
// Walks the parser's postfix `parsedQ` and emits into `irQ` (see irq.zig).
// The IR is a sea-of-nodes / SSA / continuation-passing hybrid where nodes
// carry no kind tag — every kind owns a contiguous reserved range in the
// queue, and kind is recovered from an index via an inverted-index lookup.
//
// Lowering is a single forward pass with an explicit value stack:
//   - lit_number  -> emit literal, push result index
//   - op_add/mul  -> popBinary (two operand indices), emit op, push result
//   - grp_indent / grp_dedent -> endBlock + startBlock (parser scope boundary)
//   - aux_stream_start -> skip
//   - anything else -> error.UnsupportedIRKind (not yet wired)
//
// Each block is bracketed by ir_enter / ir_exit, modeling calls/jumps in
// the actor / CPS sense (blocks-with-params). A BLOCK_SENTINEL_ARG on the
// value stack marks the open frame so endBlock can tell empty-vs-with-result.
//
// TODO:
// 1. Constant folding during construction — if both sides of an op are
//    constants, fold to the value and leave a graveyard symbol for later
//    cleanup. The IR should hold only non-constant ops.
// 2. Use-def chains via linked IR nodes (symbols become irrelevant past lowering).
//    Def: { value op index, tail ref } initialized to itself.
//    Ref: { referenced index, prev ref } — first ref points at the declaration.
// 3. Calls and jumps as block enter/exit with continuation linkage.
//    Exit: { call frame index, prev exit to this destination }.
//    Enter: { tail exit, continuation target } — either the next exit or a phi
//    from the input frame. Enters don't store params explicitly; enter index
//    is 1:1 with the param frame so params are recovered by index.
// 4. Frames for n-ary calls — see createFrame / createParam / createFrameArg
//    helpers in irq.zig.

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
const MAX_DEPTH = 128; // Value-stack depth ceiling. Ideally computed from the parser so it's never reached here.

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
        // Translate parser-side kind counts into IR-side reservations.
        // - grp_indent / grp_dedent are consumed as block delimiters, not emitted as IR nodes.
        // - Every parser scope boundary (plus the root) needs one ir_enter / ir_exit pair.
        // Future: when a parser kind expands into multiple IR kinds, sum the contributing sources here.
        var counts = kindCounts;
        const blockCount = 1 + counts[@intFromEnum(TK.grp_indent)] + counts[@intFromEnum(TK.grp_dedent)];
        counts[@intFromEnum(TK.grp_indent)] = 0;
        counts[@intFromEnum(TK.grp_dedent)] = 0;
        counts[@intFromEnum(TK.ir_enter)] += blockCount;
        counts[@intFromEnum(TK.ir_exit)] += blockCount;
        return counts;
    }

    pub fn reserve(self: *Self, kindCounts: [64]u32) !void {
        try self.irQ.reserve(self.allocator, kindCounts, MAX_DEPTH);
    }

    pub fn lower(self: *Self) !u32 {
        // Forward postfix walk with an explicit value stack. The stack carries the
        // index of each emitted IR node (and a block sentinel from startBlock); each
        // operator pops its operand indices and pushes its own result index.
        self.irQ.startBlock();
        for (self.parsedQ.list.items, 0..) |token, index| {
            switch (token.kind) {
                TK.aux_stream_start => {},
                TK.grp_indent, TK.grp_dedent => {
                    _ = self.irQ.endBlock();
                    self.irQ.startBlock();
                },
                TK.lit_number => {
                    // TODO: Larger 64 bit constants can be emitted directly in this space as well.
                    const constIndex = self.irQ.emitKind(token.kind, args(token.data.literal.value, 0));
                    self.irQ.pushArg(constIndex, index);
                },
                TK.op_add, TK.op_mul => {
                    const opNode = self.irQ.popBinary();
                    const opIndex = self.irQ.emitKind(token.kind, opNode);
                    self.irQ.pushArg(opIndex, index);
                },
                else => return error.UnsupportedIRKind,
            }
        }

        return self.irQ.endBlock();
    }

    // Exit = output.
    // Collect all transitive dependencies of output.
    // -> We actually don't need to look at the output node at all.
    // Just any two 'identifiers' which are referencing that IR node.
    // Look at each identifier definition index. What that op depends on is added to the working set.
};
