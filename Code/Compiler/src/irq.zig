// IR queue — see Docs/Specs/ir.md for the full specification.
//
// IRQueue(t) is the backing store for IR nodes. Nodes are 64 bits and carry
// no kind tag — kind is recovered from the node's index via KindRanges
// (irq/kind_ranges.zig). Each kind owns a contiguous reserved range; emits
// land at the kind's next free slot inside its range, so writes are by
// absolute index rather than append. `reserve()` sizes the backing list once
// from parser-derived kind counts.
//
// A Node is a packed union of { raw: u64, args: { left: u32, right: u32 } }.
// Convention: args.left = primary value/index, args.right = linkage or
// secondary value. The same shape backs the value stack used during lowering
// (with args.right doubling as a sentinel / parser-index tag).
//
// Blocks (irq/blocks.zig) is a parallel side-table that records, per
// block, which kinds appear (KindBitSet) and where each kind's run ends
// in block-local coordinates (KindEndSet). startBlock / endBlock bracket
// each logical scope with an ir_enter / ir_exit pair (CPS-style block with
// params) and a BLOCK_SENTINEL_ARG marker on the value stack.

const std = @import("std");
const Allocator = std.mem.Allocator;
const tok = @import("token.zig");
const kind_ranges = @import("irq/kind_ranges.zig");
const blocks = @import("irq/blocks.zig");

const TK = tok.Kind;
const KIND_COUNT = kind_ranges.KIND_COUNT;
const KindRanges = kind_ranges.KindRanges;
const Blocks = blocks.Blocks;
// Sentinel pushed onto the value stack by startBlock; identifies the open
// frame so endBlock can distinguish "block produced a result" from "block was empty".
const BLOCK_SENTINEL_ARG = std.math.maxInt(u32);

// 64-bit IR node. No kind tag — kind is recovered from the node's index
// via KindRanges. The two views are interchangeable bitwise; pick the one
// matching the node's role (args for two-operand nodes, raw for 64-bit literals).
pub const Node = packed union {
    raw: u64,
    args: Args,

    pub const Args = packed struct(u64) {
        left: u32,
        right: u32,
    };
};

pub fn args(left: u32, right: u32) Node {
    return Node{ .args = .{ .left = left, .right = right } };
}

pub fn IRQueue(comptime t: type) type {
    return struct {
        const Self = @This();
        const ArrayList = std.array_list.Aligned(t, null);
        kindRanges: KindRanges = .{},
        list: ArrayList,
        stack: ArrayList,
        blocks: Blocks = .{},

        fn zeroValue() t {
            if (t == Node) return @as(t, Node{ .raw = std.mem.zeroes(u64) });
            return std.mem.zeroes(t);
        }

        pub fn init(allocator: Allocator) !Self {
            return Self{
                .list = try ArrayList.initCapacity(allocator, 0),
                .stack = try ArrayList.initCapacity(allocator, 0),
            };
        }

        // Single allocation path. Sizes the backing list to exactly hold the per-kind
        // reservations (filled with zero nodes so emits land at absolute indices),
        // and reserves the value stack and block table. Call once after init.
        pub fn reserve(self: *Self, allocator: Allocator, kindCounts: [KIND_COUNT]u32, maxDepth: usize) !void {
            // ir_enter / ir_exit reservations must match — every block has exactly one of each.
            const blockCount = kindCounts[@intFromEnum(TK.ir_enter)];
            std.debug.assert(blockCount == kindCounts[@intFromEnum(TK.ir_exit)]);
            var nodeKindCounts = kindCounts;
            // ir_block_map is reserved as a kind but not emitted today.
            nodeKindCounts[@intFromEnum(TK.ir_block_map)] = 0;

            const totalLen: usize = @intCast(self.kindRanges.reserve(nodeKindCounts));
            self.list.clearRetainingCapacity();
            self.stack.clearRetainingCapacity();
            try self.list.ensureTotalCapacity(allocator, totalLen);
            try self.stack.ensureTotalCapacity(allocator, maxDepth);
            try self.blocks.reserve(allocator, blockCount);
            self.list.appendNTimesAssumeCapacity(zeroValue(), totalLen); // TODO: Could I just use @memset here
        }

        pub fn indexToKind(self: *const Self, index: u32) TK {
            std.debug.assert(index < self.list.items.len);
            return self.kindRanges.indexToKind(index);
        }

        pub fn blockIterator(self: *const Self) Blocks.Iterator(Self) {
            var iter: Blocks.Iterator(Self) = undefined;
            iter.initIterator(self);
            return iter;
        }

        fn isBlockSentinel(node: Node) bool {
            return node.args.right == BLOCK_SENTINEL_ARG;
        }

        // Open a new logical block. Emits an ir_enter placeholder (left = right =
        // enterIdx) and pushes a stack sentinel that marks the open frame.
        pub fn startBlock(self: *Self) void {
            self.blocks.startBlock();
            const enterIdx = self.emitKind(TK.ir_enter, args(0, 0));
            self.set(enterIdx, args(enterIdx, enterIdx));
            self.pushArg(enterIdx, BLOCK_SENTINEL_ARG);
        }

        // Close the current block and emit ir_exit { enterIdx, resultIdx }. If the
        // top of stack is the block's own sentinel, the block produced no result;
        // otherwise the value below is the sentinel and the top is the result.
        pub fn endBlock(self: *Self) u32 {
            const result = self.stack.pop() orelse unreachable;
            const enter = if (isBlockSentinel(result)) result else enter: {
                const sentinel = self.stack.pop() orelse unreachable;
                std.debug.assert(isBlockSentinel(sentinel));
                break :enter sentinel;
            };
            const exitIdx = self.emitKind(TK.ir_exit, args(enter.args.left, result.args.left));
            self.blocks.endBlock(&self.kindRanges);
            return exitIdx;
        }

        // Reserve the next slot inside `kind`'s pre-allocated range, write `value`,
        // and record the emission in the active block's kinds bitset.
        pub fn emitKind(self: *Self, kind: TK, value: Node) u32 {
            const index = self.kindRanges.nextIndex(kind);
            self.set(index, value);
            self.blocks.markActiveBlockKind(kind, index);
            return index;
        }

        pub fn get(self: *const Self, index: u32) t {
            std.debug.assert(index < self.list.items.len);
            return self.list.items[index];
        }

        pub fn set(self: *Self, index: u32, value: t) void {
            std.debug.assert(index < self.list.items.len);
            self.list.items[index] = value;
        }

        // Push onto the lowering value stack. left is the just-emitted node index;
        // right doubles as a tag (parser index, or BLOCK_SENTINEL_ARG for sentinels).
        pub fn pushArg(self: *Self, left: u32, right: usize) void {
            std.debug.assert(self.stack.items.len < self.stack.capacity);
            self.stack.appendAssumeCapacity(args(left, @intCast(right)));
        }

        pub fn popUnary(self: *Self) Node {
            std.debug.assert(self.stack.items.len >= 1);
            return self.stack.pop() orelse unreachable;
        }

        // Pop two operand indices off the value stack and return them as a single
        // Node ready to be emitted as a binary op's args (left operand, right operand).
        pub fn popBinary(self: *Self) Node {
            std.debug.assert(self.stack.items.len >= 2);
            const right = self.stack.pop() orelse unreachable;
            const left = self.stack.pop() orelse unreachable;
            return args(left.args.left, right.args.left);
        }

        // Frame / Param / Arg: helpers for n-ary call lowering. Not yet called by
        // ir.lower; kept here to pin down the shape future call lowering will use.
        //
        // A frame implicitly owns the next argCount ir_arg slots starting at argIndex.
        pub fn createFrame(self: *Self, argCount: u32) u32 {
            const argIndex = self.kindRanges.cursor(TK.ir_arg);
            return self.emitKind(TK.ir_frame, args(argIndex, argCount));
        }

        // A param is our phi equivalent — one declaration site, many incoming
        // values. args.left doubles as the head of a singly-linked arg list
        // (the "arg tail", latest-first), initialized to point at itself.
        pub fn createParam(self: *Self) u32 {
            const paramIndex = self.kindRanges.cursor(TK.ir_param);
            // Arg tail, ref tail (TODO: Is ref tail useful?)
            self.emitKind(TK.ir_param, args(paramIndex, 0));
            return paramIndex;
        }

        // Append an incoming value to a param's arg list. The new arg's right
        // field points at the previous tail, and the param's left is updated to
        // the new arg — threading args latest-first.
        pub fn createFrameArg(self: *Self, paramIndex: u32, value: u32) u32 {
            var param = self.get(paramIndex);
            const argTail = param.args.left;
            const argIndex = self.emitKind(TK.ir_arg, args(value, argTail));
            param.args.left = argIndex;
            self.set(paramIndex, param);
            return argIndex;
        }

        // pub fn popArgs(self: *Self, count: usize) Node {
        //     std.debug.assert(count > 0);
        //     if (count == 1) {
        //         // Unary fn.
        //         return self.stack.pop() orelse zeroValue();
        //     } else if (count == 2) {
        //         // Pop and merge
        //         const right = self.stack.pop() orelse zeroValue();
        //         const left = self.stack.pop() orelse zeroValue();
        //         return args(left.args.left, right.args.left);
        //     } else {
        //         // N-ary function call. Need to construct a frame instead.
        //     }
        // }

        pub fn deinit(self: *Self, allocator: Allocator) void {
            self.blocks.deinit(allocator);
            self.list.deinit(allocator);
            self.stack.deinit(allocator);
        }
    };
}
