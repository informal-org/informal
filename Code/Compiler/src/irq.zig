const std = @import("std");
const Allocator = std.mem.Allocator;
const tok = @import("token.zig");
const TK = tok.Kind;

const KIND_COUNT = 64; // IR queues track the first 64 token kinds.
// Power of two sized buckets to slice the entire range into an inverted index
// of range-bucket -> kinds present within that range.
const INDEX_KIND_MAP_BUCKET_COUNT_SHIFT = 5;
const INDEX_KIND_MAP_BUCKET_COUNT = 1 << INDEX_KIND_MAP_BUCKET_COUNT_SHIFT;
const KindBitSet = std.bit_set.IntegerBitSet(KIND_COUNT);

pub const Range = packed struct(u64) {
    start: u32, // Incremented on add
    end: u32, // Precomputed from the results of Parser's kind count
};

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
        // Reserved ranges keyed by kind. start is later advanced by emitKind,
        // while end remains fixed.
        ranges: [KIND_COUNT]Range = std.mem.zeroes([KIND_COUNT]Range),
        // Inverted index from index bucket to kinds present within that bucket.
        // Each entry is a bitset of token kinds whose reserved ranges overlap
        // that bucket. indexToKind uses this to avoid scanning every kind.
        indexKindMap: [INDEX_KIND_MAP_BUCKET_COUNT]KindBitSet = [_]KindBitSet{KindBitSet.initEmpty()} ** INDEX_KIND_MAP_BUCKET_COUNT,
        // log2(bucket width). Computed once in reserve so hot lookups use a
        // shift instead of a division.
        indexKindMapWidthShift: u5 = 0,
        list: ArrayList,
        stack: ArrayList,

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
            var tail: u32 = 0;
            for (0..KIND_COUNT) |i| {
                self.ranges[i].start = tail;
                tail += kindCounts[i];
                self.ranges[i].end = tail;
            }
            self.buildIndexKindMap(tail);

            const totalLen: usize = @intCast(tail);
            self.list.clearRetainingCapacity();
            self.stack.clearRetainingCapacity();
            try self.list.ensureTotalCapacity(allocator, totalLen);
            try self.stack.ensureTotalCapacity(allocator, maxDepth);
            self.list.appendNTimesAssumeCapacity(zeroValue(), totalLen); // TODO: Could I just use @memset here
        }

        fn kindStart(self: *Self, kind: TK) u32 {
            return self.ranges[@intFromEnum(kind)].start;
        }

        fn reservedKindStart(self: *const Self, kindIndex: usize) u32 {
            // ranges[kind].start is an emit cursor, so recover the stable
            // reserved start from the previous kind's end.
            return if (kindIndex == 0) 0 else self.ranges[kindIndex - 1].end;
        }

        fn indexKindMapIndex(self: *const Self, index: u32) usize {
            const mapIndex: usize = @intCast(index >> self.indexKindMapWidthShift);
            std.debug.assert(mapIndex < INDEX_KIND_MAP_BUCKET_COUNT);
            return mapIndex;
        }

        fn buildIndexKindMap(self: *Self, totalLen: u32) void {
            // Build the inverted index that'll help us map from an index to which kinds are present in that range.
            self.indexKindMapWidthShift = 0;
            if (totalLen > 1) {
                // Round the ideal 1/32 slice width up to a power of two. This can
                // leave high buckets unused, but guarantees index >> shift is in
                // bounds for every valid queue index.
                const bucketLen = std.math.divCeil(u32, totalLen, INDEX_KIND_MAP_BUCKET_COUNT) catch unreachable;
                self.indexKindMapWidthShift = @intCast(std.math.log2_int_ceil(u32, bucketLen));
            }
            if (totalLen == 0) return;

            for (0..KIND_COUNT) |kindIndex| {
                const start = self.reservedKindStart(kindIndex);
                const end = self.ranges[kindIndex].end;
                // Skip setting the bits for empty-ranges.
                if (start == end) continue;

                const firstMapIndex = self.indexKindMapIndex(start);
                const lastMapIndex = self.indexKindMapIndex(end - 1);
                for (firstMapIndex..lastMapIndex + 1) |mapIndex| {
                    self.indexKindMap[mapIndex].set(kindIndex);
                }
            }
        }

        pub fn indexToKind(self: *const Self, index: u32) TK {
            std.debug.assert(index < self.list.items.len);

            const mapIndex = self.indexKindMapIndex(index);
            const indexKinds = self.indexKindMap[mapIndex];
            // Fast-path - just one kind set. Kind of redundant, but avoids the loop overhead.
            if (indexKinds.count() == 1) {
                const kindIndex = indexKinds.findFirstSet() orelse unreachable;
                return @enumFromInt(kindIndex);
            }
            var iter = indexKinds.iterator(.{});
            while (iter.next()) |kindIndex| {
                const start = self.reservedKindStart(kindIndex);
                const end = self.ranges[kindIndex].end;
                if (start <= index and index < end) return @enumFromInt(kindIndex);
            }

            unreachable;
        }

        pub fn emitKind(self: *Self, kind: TK, value: Node) u32 {
            const kindIndex = @intFromEnum(kind);
            const index = self.kindStart(kind);
            std.debug.assert(index < self.ranges[kindIndex].end);
            self.set(index, value);
            self.ranges[kindIndex].start += 1;
            return index;
        }

        pub fn get(self: *Self, index: u32) t {
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
            return self.stack.pop() orelse zeroValue();
        }

        pub fn popBinary(self: *Self) Node {
            const right = self.stack.pop() orelse zeroValue();
            const left = self.stack.pop() orelse zeroValue();
            return args(left.args.left, right.args.left);
        }

        pub fn createFrame(self: *Self, argCount: u32) u32 {
            const argIndex = self.kindStart(TK.ir_arg);
            return self.emitKind(TK.ir_frame, args(argIndex, argCount));
        }

        pub fn createParam(self: *Self) u32 {
            const paramIndex = self.kindStart(TK.ir_param);
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
            self.list.deinit(allocator);
            self.stack.deinit(allocator);
        }
    };
}
