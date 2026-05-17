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
const KindBitSetIterator = KindBitSet.Iterator(.{});
const BlockBoundarySet = std.bit_set.DynamicBitSetUnmanaged;
const BlockBoundaryIterator = BlockBoundarySet.Iterator(.{});

const Range = packed struct(u64) {
    cursor: u32, // Incremented on add
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

const KindRanges = struct {
    const Self = @This();

    // Reserved ranges keyed by kind. cursor is advanced by emitKind, while
    // end remains fixed.
    ranges: [KIND_COUNT]Range = std.mem.zeroes([KIND_COUNT]Range),
    // Inverted index from index bucket to kinds present within that bucket.
    // Each entry is a bitset of token kinds whose reserved ranges overlap
    // that bucket. indexToKind uses this to avoid scanning every kind.
    indexKindMap: [INDEX_KIND_MAP_BUCKET_COUNT]KindBitSet = [_]KindBitSet{KindBitSet.initEmpty()} ** INDEX_KIND_MAP_BUCKET_COUNT,
    // log2(bucket width). Computed once in reserve so hot lookups use a
    // shift instead of a division.
    indexKindMapWidthShift: u5 = 0,

    fn reserve(self: *Self, kindCounts: [KIND_COUNT]u32) u32 {
        var tail: u32 = 0;
        for (0..KIND_COUNT) |i| {
            self.ranges[i].cursor = tail;
            tail += kindCounts[i];
            self.ranges[i].end = tail;
        }
        self.buildIndexKindMap(tail);
        return tail;
    }

    fn cursor(self: *const Self, kind: TK) u32 {
        return self.ranges[@intFromEnum(kind)].cursor;
    }

    fn nextIndex(self: *Self, kind: TK) u32 {
        const kindIndex = @intFromEnum(kind);
        const index = self.ranges[kindIndex].cursor;
        std.debug.assert(index < self.ranges[kindIndex].end);
        self.ranges[kindIndex].cursor += 1;
        return index;
    }

    fn reservedStart(self: *const Self, kindIndex: usize) u32 {
        // ranges[kind].cursor is an emit cursor, so recover the stable
        // reserved start from the previous kind's end.
        return if (kindIndex == 0) 0 else self.ranges[kindIndex - 1].end;
    }

    fn reservedLen(self: *const Self, kindIndex: usize) u32 {
        return self.ranges[kindIndex].end - self.reservedStart(kindIndex);
    }

    fn relativeIndex(self: *const Self, kindIndex: usize, index: u32) u32 {
        const start = self.reservedStart(kindIndex);
        std.debug.assert(start <= index);
        std.debug.assert(index < self.ranges[kindIndex].end);
        return index - start;
    }

    fn indexKindMapIndex(self: *const Self, index: u32) usize {
        const mapIndex: usize = @intCast(index >> self.indexKindMapWidthShift);
        std.debug.assert(mapIndex < INDEX_KIND_MAP_BUCKET_COUNT);
        return mapIndex;
    }

    fn buildIndexKindMap(self: *Self, totalLen: u32) void {
        // Build the inverted index that'll help us map from an index to which kinds are present in that range.
        self.indexKindMap = [_]KindBitSet{KindBitSet.initEmpty()} ** INDEX_KIND_MAP_BUCKET_COUNT;
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
            const start = self.reservedStart(kindIndex);
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

    fn indexToKind(self: *const Self, index: u32) TK {
        const mapIndex = self.indexKindMapIndex(index);
        const indexKinds = self.indexKindMap[mapIndex];
        // Fast-path - just one kind set. Kind of redundant, but avoids the loop overhead.
        if (indexKinds.count() == 1) {
            const kindIndex = indexKinds.findFirstSet() orelse unreachable;
            return @enumFromInt(kindIndex);
        }
        var iter = indexKinds.iterator(.{});
        while (iter.next()) |kindIndex| {
            const start = self.reservedStart(kindIndex);
            const end = self.ranges[kindIndex].end;
            if (start <= index and index < end) return @enumFromInt(kindIndex);
        }

        unreachable;
    }
};

const Blocks = struct {
    const Self = @This();

    activeBlockMap: KindBitSet = KindBitSet.initEmpty(),
    // Boundary bits are stored per kind and indexed relative to that kind's
    // reserved range. A set bit marks the last emitted node of that kind in a
    // parser block.
    boundaries: [KIND_COUNT]BlockBoundarySet = [_]BlockBoundarySet{.{}} ** KIND_COUNT,

    fn reserve(self: *Self, allocator: Allocator, kindRanges: *const KindRanges) !void {
        for (&self.boundaries, 0..) |*boundary, kindIndex| {
            try boundary.resize(allocator, kindRanges.reservedLen(kindIndex), false);
            boundary.unsetAll();
        }
        self.activeBlockMap = KindBitSet.initEmpty();
    }

    fn startBlock(self: *Self) void {
        self.activeBlockMap = KindBitSet.initEmpty();
    }

    fn endBlock(self: *Self, kindRanges: *const KindRanges) KindBitSet {
        self.markActiveBlockBoundaries(kindRanges);
        const blockMap = self.activeBlockMap;
        self.activeBlockMap = KindBitSet.initEmpty();
        return blockMap;
    }

    fn markActiveBlockBoundaries(self: *Self, kindRanges: *const KindRanges) void {
        var iter = self.activeBlockMap.iterator(.{});
        while (iter.next()) |kindIndex| {
            // nextIndex advances the cursor after writing, so the block
            // boundary lives at cursor - 1: the last node emitted for
            // this kind in the block.
            const cursor = kindRanges.ranges[kindIndex].cursor;
            const start = kindRanges.reservedStart(kindIndex);
            std.debug.assert(cursor > start);
            self.boundaries[kindIndex].set(cursor - start - 1);
        }
    }

    fn markActiveBlockKind(self: *Self, kind: TK) void {
        if (kind == TK.ir_block_map) return;
        self.activeBlockMap.set(@intFromEnum(kind));
    }

    fn deinit(self: *Self, allocator: Allocator) void {
        for (&self.boundaries) |*boundary| {
            if (boundary.capacity() != 0) {
                boundary.deinit(allocator);
            }
        }
    }

    fn Iterator(comptime Queue: type) type {
        return struct {
            const IterSelf = @This();
            // Specifies the range of elements within a kind that a block occupies.
            const BlockRange = packed struct(u64) {
                start: u32,
                end: u32, // Inclusive. Where the boundary bit is set.
            };
            // Cursor through elements within current kind. Increment with nextElement till end (inclusive)
            const ElementCursor = packed struct(u64) {
                next: u32,
                end: u32,
            };
            // Iterator over blocks present in each kind.
            // advanceBlock is only called for present blocks.
            const PerKindBlockBoundaryCursor = struct {
                iter: ?BlockBoundaryIterator = null,
                currentStart: u32 = 0, // First relative index in the current block.
                nextStart: u32 = 0, // First relative index not yet claimed.

                // Advance to the next block with this kind's elements.
                // Only called when it's known the block contains this kind.
                fn advanceBlock(self: *PerKindBlockBoundaryCursor, boundary: *const BlockBoundarySet) void {
                    const end = self.nextBlockBoundary(boundary) orelse unreachable;
                    std.debug.assert(end >= self.nextStart);
                    self.currentStart = self.nextStart;
                    self.nextStart = end + 1;
                }

                // Currently active block for this kind's range.
                // Which may not be the block that's active at a higher level
                fn currentRange(self: *const PerKindBlockBoundaryCursor) BlockRange {
                    std.debug.assert(self.nextStart > 0);
                    return .{
                        .start = self.currentStart,
                        .end = self.nextStart - 1,
                    };
                }

                // Lazily creates and advances the bitset iterator so a
                // cursor can be zero-initialized and reused by initIterator.
                fn nextBlockBoundary(self: *PerKindBlockBoundaryCursor, boundary: *const BlockBoundarySet) ?u32 {
                    if (self.iter == null) {
                        self.iter = boundary.iterator(.{});
                    }
                    if (self.iter) |*iter| {
                        return @intCast(iter.next() orelse return null);
                    }
                    unreachable;
                }
            };

            queue: *const Queue = undefined,
            // Cursor over ir_block_map blocks.
            blockIndex: u32 = 0,
            // Kinds present in the current block.
            blockKindMap: KindBitSet = KindBitSet.initEmpty(),
            // Maintain block boundary state for each token kind.
            kindBoundaryCursors: [KIND_COUNT]PerKindBlockBoundaryCursor = undefined,
            // Iterates over kinds in current block.
            nextKindIter: KindBitSetIterator = KindBitSet.initEmpty().iterator(.{}),
            // Absolute element range for the kind most recently returned by nextKind
            currentElements: ?ElementCursor = null,

            pub fn initIterator(self: *IterSelf, queue: *const Queue) void {
                self.queue = queue;
                self.blockIndex = queue.kindRanges.reservedStart(@intFromEnum(TK.ir_block_map));
                self.blockKindMap = KindBitSet.initEmpty();
                self.kindBoundaryCursors = [_]PerKindBlockBoundaryCursor{.{}} ** KIND_COUNT;
                self.nextKindIter = KindBitSet.initEmpty().iterator(.{});
                self.currentElements = null;
            }

            pub fn hasMoreBlocks(self: *const IterSelf) bool {
                return self.blockIndex < self.queue.kindRanges.cursor(TK.ir_block_map);
            }

            // Advance to the next block.
            pub fn nextBlock(self: *IterSelf) void {
                std.debug.assert(self.hasMoreBlocks());
                const blockMapIndex = self.blockIndex;
                self.blockIndex += 1;
                self.blockKindMap = KindBitSet{ .mask = self.queue.get(blockMapIndex).raw };

                var iter = self.blockKindMap.iterator(.{});
                while (iter.next()) |kindIndex| {
                    self.kindBoundaryCursors[kindIndex].advanceBlock(&self.queue.blocks.boundaries[kindIndex]);
                }

                self.nextKindIter = self.blockKindMap.iterator(.{});
                self.currentElements = null;
            }

            // Advance the cursor to the next kind this block contains.
            // Null when all kinds present in this block have been visited.
            pub fn nextKind(self: *IterSelf) ?TK {
                const kindIndex = self.nextKindIter.next() orelse {
                    self.currentElements = null;
                    return null;
                };

                const range = self.kindBoundaryCursors[kindIndex].currentRange();
                const reservedStart = self.queue.kindRanges.reservedStart(kindIndex);
                self.currentElements = .{
                    .next = reservedStart + range.start,
                    .end = reservedStart + range.end,
                };
                return @enumFromInt(kindIndex);
            }

            // Return the next IR element index for current kind.
            // If null, advance to the next kind and call again.
            // If kind is null, this block is done.
            pub fn nextElement(self: *IterSelf) ?u32 {
                if (self.currentElements) |*elements| {
                    if (elements.next > elements.end) return null;

                    const index = elements.next;
                    elements.next += 1;
                    return index;
                }

                return null;
            }

            // Efficient test for whether an IR element belongs to the current block.
            pub fn inCurrentBlock(self: *const IterSelf, index: u32) bool {
                std.debug.assert(index < self.queue.list.items.len);
                const kind = self.queue.indexToKind(index);
                const kindIndex = @intFromEnum(kind);
                if (!self.blockKindMap.isSet(kindIndex)) return false;

                const relativeIndex = self.queue.kindRanges.relativeIndex(kindIndex, index);
                const range = self.kindBoundaryCursors[kindIndex].currentRange();
                return range.start <= relativeIndex and relativeIndex <= range.end;
            }
        };
    }
};

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
            const totalLen: usize = @intCast(self.kindRanges.reserve(kindCounts));
            self.list.clearRetainingCapacity();
            self.stack.clearRetainingCapacity();
            try self.list.ensureTotalCapacity(allocator, totalLen);
            try self.stack.ensureTotalCapacity(allocator, maxDepth);
            try self.blocks.reserve(allocator, &self.kindRanges);
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

        fn emitBlockMap(self: *Self, blockMap: KindBitSet) u32 {
            const index = self.kindRanges.nextIndex(TK.ir_block_map);
            self.set(index, Node{ .raw = blockMap.mask });
            return index;
        }

        pub fn startBlock(self: *Self) void {
            self.blocks.startBlock();
        }

        pub fn endBlock(self: *Self) void {
            _ = self.emitBlockMap(self.blocks.endBlock(&self.kindRanges));
        }

        pub fn emitKind(self: *Self, kind: TK, value: Node) u32 {
            const index = self.kindRanges.nextIndex(kind);
            self.set(index, value);
            self.blocks.markActiveBlockKind(kind);
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
