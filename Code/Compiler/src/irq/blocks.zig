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
