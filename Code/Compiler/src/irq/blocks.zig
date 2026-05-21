const std = @import("std");
const tok = @import("../token.zig");
const kind_ranges = @import("kind_ranges.zig");

const Allocator = std.mem.Allocator;
const TK = tok.Kind;
const KIND_COUNT = kind_ranges.KIND_COUNT;
const KindBitSet = kind_ranges.KindBitSet;
const KindBitSetIterator = kind_ranges.KindBitSetIterator;
const KindRanges = kind_ranges.KindRanges;
const BlockBoundarySet = std.bit_set.DynamicBitSetUnmanaged;
const BlockBoundaryIterator = BlockBoundarySet.Iterator(.{});

pub const Blocks = struct {
    const Self = @This();
    pub const BlockRange = packed struct(u64) {
        start: u32,
        end: u32, // Exclusive.

        pub fn len(self: BlockRange) u32 {
            return self.end - self.start;
        }
    };

    activeBlockMap: KindBitSet = KindBitSet.initEmpty(),
    // Boundary bits are stored per kind and indexed relative to that kind's
    // reserved range. A set bit marks the last emitted node of that kind in a
    // parser block.
    boundaries: [KIND_COUNT]BlockBoundarySet = [_]BlockBoundarySet{.{}} ** KIND_COUNT,

    pub fn reserve(self: *Self, allocator: Allocator, kindRanges: *const KindRanges) !void {
        for (&self.boundaries, 0..) |*boundary, kindIndex| {
            try boundary.resize(allocator, kindRanges.reservedLen(kindIndex), false);
            boundary.unsetAll();
        }
        self.activeBlockMap = KindBitSet.initEmpty();
    }

    pub fn startBlock(self: *Self) void {
        self.activeBlockMap = KindBitSet.initEmpty();
    }

    pub fn endBlock(self: *Self, kindRanges: *const KindRanges) KindBitSet {
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
            const cursor = kindRanges.emittedCursor(kindIndex);
            const start = kindRanges.reservedStart(kindIndex);
            std.debug.assert(cursor > start);
            self.boundaries[kindIndex].set(cursor - start - 1);
        }
    }

    pub fn markActiveBlockKind(self: *Self, kind: TK) void {
        if (kind == TK.ir_block_map) return;
        self.activeBlockMap.set(@intFromEnum(kind));
    }

    pub fn deinit(self: *Self, allocator: Allocator) void {
        for (&self.boundaries) |*boundary| {
            if (boundary.capacity() != 0) {
                boundary.deinit(allocator);
            }
        }
    }

    pub fn Iterator(comptime Queue: type) type {
        return struct {
            const IterSelf = @This();
            // Iterator over blocks present in each kind.
            // advanceBlock is only called for present blocks.
            const PerKindBlockBoundaryCursor = struct {
                iter: ?BlockBoundaryIterator = null,
                currentStart: u32 = 0, // First absolute index in the current block.
                nextStart: u32 = 0, // First absolute index not yet claimed.

                // Advance to the next block with this kind's elements.
                // Only called when it's known the block contains this kind.
                fn advanceBlock(self: *PerKindBlockBoundaryCursor, boundary: *const BlockBoundarySet, reservedStart: u32) void {
                    if (self.iter == null) {
                        self.nextStart = reservedStart;
                    }

                    const relativeEnd = self.nextBlockBoundary(boundary) orelse unreachable;
                    const end = reservedStart + relativeEnd + 1;
                    std.debug.assert(end > self.nextStart);
                    self.currentStart = self.nextStart;
                    self.nextStart = end;
                }

                // Absolute range for this kind within the currently active block.
                // Which may not be the block that's active at a higher level
                fn currentRange(self: *const PerKindBlockBoundaryCursor) BlockRange {
                    std.debug.assert(self.nextStart > self.currentStart);
                    return .{
                        .start = self.currentStart,
                        .end = self.nextStart,
                    };
                }

                // Lazily creates and advances the kind-relative bitset iterator
                // so a cursor can be zero-initialized and reused by initIterator.
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
            // Dense local base index for each kind in the current block.
            blockLocalBases: [KIND_COUNT]u32 = [_]u32{0} ** KIND_COUNT,
            // Iterates over kinds in current block.
            nextKindIter: KindBitSetIterator = KindBitSet.initEmpty().iterator(.{}),

            pub fn initIterator(self: *IterSelf, queue: *const Queue) void {
                self.queue = queue;
                self.blockIndex = queue.kindRanges.reservedStart(@intFromEnum(TK.ir_block_map));
                self.blockKindMap = KindBitSet.initEmpty();
                self.kindBoundaryCursors = [_]PerKindBlockBoundaryCursor{.{}} ** KIND_COUNT;
                self.blockLocalBases = [_]u32{0} ** KIND_COUNT;
                self.nextKindIter = KindBitSet.initEmpty().iterator(.{});
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

                var nextLocalIndex: u32 = 0;
                var iter = self.blockKindMap.iterator(.{});
                while (iter.next()) |kindIndex| {
                    const reservedStart = self.queue.kindRanges.reservedStart(kindIndex);
                    self.kindBoundaryCursors[kindIndex].advanceBlock(&self.queue.blocks.boundaries[kindIndex], reservedStart);
                    self.blockLocalBases[kindIndex] = nextLocalIndex;
                    nextLocalIndex += self.kindBoundaryCursors[kindIndex].currentRange().len();
                }

                self.nextKindIter = self.blockKindMap.iterator(.{});
            }

            // Advance the cursor to the next kind this block contains.
            // Null when all kinds present in this block have been visited.
            pub fn nextKind(self: *IterSelf) ?TK {
                const kindIndex = self.nextKindIter.next() orelse return null;
                return @enumFromInt(kindIndex);
            }

            pub fn blockRange(self: *const IterSelf, kind: TK) BlockRange {
                const kindIndex = @intFromEnum(kind);
                std.debug.assert(self.blockKindMap.isSet(kindIndex));
                return self.kindBoundaryCursors[kindIndex].currentRange();
            }

            pub fn blockLen(self: *const IterSelf) u32 {
                var len: u32 = 0;
                var iter = self.blockKindMap.iterator(.{});
                while (iter.next()) |kindIndex| {
                    len += self.kindBoundaryCursors[kindIndex].currentRange().len();
                }
                return len;
            }

            // Dense index of an absolute IR element within the current block,
            // in the same order as nextKind ranges.
            pub fn getBlockLocalIndex(self: *const IterSelf, absoluteIndex: u32) ?u32 {
                std.debug.assert(absoluteIndex < self.queue.list.items.len);
                const kind = self.queue.indexToKind(absoluteIndex);
                const kindIndex = @intFromEnum(kind);
                if (!self.blockKindMap.isSet(kindIndex)) return null;

                const range = self.kindBoundaryCursors[kindIndex].currentRange();
                if (absoluteIndex < range.start or absoluteIndex >= range.end) return null;

                return self.blockLocalBases[kindIndex] + absoluteIndex - range.start;
            }
        };
    }
};
