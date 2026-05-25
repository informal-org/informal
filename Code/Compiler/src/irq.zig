const std = @import("std");
const Allocator = std.mem.Allocator;
const tok = @import("token.zig");
const kind_ranges = @import("irq/kind_ranges.zig");
const blocks = @import("irq/blocks.zig");

const TK = tok.Kind;
const KIND_COUNT = kind_ranges.KIND_COUNT;
const KindRanges = kind_ranges.KindRanges;
const Blocks = blocks.Blocks;
const BLOCK_SENTINEL_ARG = std.math.maxInt(u32);

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

        // reserve is the queue's allocation path and is meant to be called once after init.
        pub fn reserve(self: *Self, allocator: Allocator, kindCounts: [KIND_COUNT]u32, maxDepth: usize) !void {
            const blockCount = kindCounts[@intFromEnum(TK.ir_enter)];
            std.debug.assert(blockCount == kindCounts[@intFromEnum(TK.ir_exit)]);
            var nodeKindCounts = kindCounts;
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

        pub fn startBlock(self: *Self) void {
            self.blocks.startBlock();
            const enterIdx = self.emitKind(TK.ir_enter, args(0, 0));
            self.set(enterIdx, args(enterIdx, enterIdx));
            self.pushArg(enterIdx, BLOCK_SENTINEL_ARG);
        }

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

        pub fn pushArg(self: *Self, left: u32, right: usize) void {
            std.debug.assert(self.stack.items.len < self.stack.capacity);
            self.stack.appendAssumeCapacity(args(left, @intCast(right)));
        }

        pub fn popUnary(self: *Self) Node {
            std.debug.assert(self.stack.items.len >= 1);
            return self.stack.pop() orelse unreachable;
        }

        pub fn popBinary(self: *Self) Node {
            std.debug.assert(self.stack.items.len >= 2);
            const right = self.stack.pop() orelse unreachable;
            const left = self.stack.pop() orelse unreachable;
            return args(left.args.left, right.args.left);
        }

        pub fn createFrame(self: *Self, argCount: u32) u32 {
            const argIndex = self.kindRanges.cursor(TK.ir_arg);
            return self.emitKind(TK.ir_frame, args(argIndex, argCount));
        }

        pub fn createParam(self: *Self) u32 {
            const paramIndex = self.kindRanges.cursor(TK.ir_param);
            // Arg tail, ref tail (TODO: Is ref tail useful?)
            self.emitKind(TK.ir_param, args(paramIndex, 0));
            return paramIndex;
        }

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
