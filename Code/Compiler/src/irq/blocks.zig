const std = @import("std");
const tok = @import("../token.zig");
const bitset = @import("../bitset.zig");
const kind_ranges = @import("kind_ranges.zig");

const Allocator = std.mem.Allocator;
const TK = tok.Kind;
const KIND_COUNT = kind_ranges.KIND_COUNT;
const KindBitSet = kind_ranges.KindBitSet;
const KindBitSetIterator = kind_ranges.KindBitSetIterator;
const KindRanges = kind_ranges.KindRanges;
const KindEndSet = std.bit_set.IntegerBitSet(64);

pub const Blocks = struct {
    const Self = @This();
    pub const Block = struct {
        kinds: KindBitSet,
        ends: KindEndSet,
    };
    const BlockList = std.array_list.Aligned(Block, null);

    pub const BlockRange = packed struct(u96) {
        start: u32,
        end: u32, // Exclusive.
        localBase: u32,

        pub fn len(self: BlockRange) u32 {
            return self.end - self.start;
        }
    };
    const KindIterator = struct {
        iter: KindBitSetIterator,

        pub fn next(self: *KindIterator) ?TK {
            const kindIndex = self.iter.next() orelse return null;
            return @enumFromInt(kindIndex);
        }
    };

    activeKindStarts: [KIND_COUNT]u32 = [_]u32{0} ** KIND_COUNT,
    blocks: BlockList = .empty,

    pub fn reserve(self: *Self, allocator: Allocator, reservedBlockCount: u32) !void {
        const capacity: usize = @intCast(reservedBlockCount);
        self.blocks.clearRetainingCapacity();
        try self.blocks.ensureTotalCapacity(allocator, capacity);
        self.activeKindStarts = [_]u32{0} ** KIND_COUNT;
    }

    pub fn startBlock(self: *Self) void {
        std.debug.assert(self.blocks.items.len < self.blocks.capacity);
        self.blocks.appendAssumeCapacity(.{ .kinds = KindBitSet.initEmpty(), .ends = KindEndSet.initEmpty() });
    }

    pub fn endBlock(self: *Self, kindRanges: *const KindRanges) void {
        std.debug.assert(self.blocks.items.len > 0);
        const blockInfo = &self.blocks.items[self.blocks.items.len - 1];
        std.debug.assert(blockInfo.ends.mask == 0);
        var endMap = KindEndSet.initEmpty();
        var localEnd: u32 = 0;
        var iter = blockInfo.kinds.iterator(.{});
        while (iter.next()) |kindIndex| {
            const cursor = kindRanges.emittedCursor(kindIndex);
            const start = self.activeKindStarts[kindIndex];
            std.debug.assert(cursor > start);
            localEnd += cursor - start;
            std.debug.assert(localEnd <= 64);
            endMap.set(@intCast(localEnd - 1));
        }

        blockInfo.ends = endMap;
    }

    pub fn markActiveBlockKind(self: *Self, kind: TK, index: u32) void {
        if (self.blocks.items.len == 0) return;
        const blockInfo = &self.blocks.items[self.blocks.items.len - 1];
        if (blockInfo.ends.mask != 0) return;
        const kindIndex = @intFromEnum(kind);
        if (!blockInfo.kinds.isSet(kindIndex)) {
            self.activeKindStarts[kindIndex] = index;
            blockInfo.kinds.set(kindIndex);
        }
    }

    pub fn blockCount(self: *const Self) u32 {
        if (self.blocks.items.len == 0) return 0;
        const completeBlockCount = if (self.blocks.items[self.blocks.items.len - 1].ends.mask == 0)
            self.blocks.items.len - 1
        else
            self.blocks.items.len;
        return @intCast(completeBlockCount);
    }

    pub fn block(self: *const Self, blockIndex: u32) Block {
        std.debug.assert(blockIndex < self.blockCount());
        return self.blocks.items[@intCast(blockIndex)];
    }

    pub fn deinit(self: *Self, allocator: Allocator) void {
        self.blocks.deinit(allocator);
    }

    pub fn Iterator(comptime Queue: type) type {
        return struct {
            const IterSelf = @This();

            queue: *const Queue = undefined,
            blockIndex: u32 = 0,
            kindBlockRanges: [KIND_COUNT]BlockRange = [_]BlockRange{.{ .start = 0, .end = 0, .localBase = 0 }} ** KIND_COUNT,

            pub fn initIterator(self: *IterSelf, queue: *const Queue) void {
                self.queue = queue;
                self.blockIndex = 0;
                var kindIndex: usize = 0;
                while (kindIndex < KIND_COUNT) : (kindIndex += 1) {
                    const start = queue.kindRanges.reservedStart(kindIndex);
                    self.kindBlockRanges[kindIndex] = .{ .start = start, .end = start, .localBase = 0 };
                }
            }

            pub fn hasMoreBlocks(self: *const IterSelf) bool {
                return self.blockIndex < self.queue.blocks.blockCount();
            }

            pub fn nextBlock(self: *IterSelf) void {
                std.debug.assert(self.hasMoreBlocks());
                const currentBlockIndex = self.blockIndex;
                self.blockIndex += 1;

                const blockInfo = self.queue.blocks.block(currentBlockIndex);

                var localStart: u32 = 0;
                var kindIter = blockInfo.kinds.iterator(.{});
                var endIter = blockInfo.ends.iterator(.{});
                while (kindIter.next()) |kindIndex| {
                    const localEnd: u32 = @intCast((endIter.next() orelse unreachable) + 1);
                    std.debug.assert(localEnd > localStart);
                    const start = self.kindBlockRanges[kindIndex].end;
                    const end = start + localEnd - localStart;
                    self.kindBlockRanges[kindIndex] = .{ .start = start, .end = end, .localBase = localStart };
                    localStart = localEnd;
                }
                std.debug.assert(endIter.next() == null);
            }

            pub fn kindIterator(self: *const IterSelf) KindIterator {
                std.debug.assert(self.blockIndex > 0);
                return .{ .iter = self.queue.blocks.block(self.blockIndex - 1).kinds.iterator(.{}) };
            }

            pub fn blockRange(self: *const IterSelf, kind: TK) BlockRange {
                const kindIndex = @intFromEnum(kind);
                std.debug.assert(self.blockIndex > 0);
                std.debug.assert(self.queue.blocks.block(self.blockIndex - 1).kinds.isSet(kindIndex));
                return self.kindBlockRanges[kindIndex];
            }

            pub fn blockLen(self: *const IterSelf) u32 {
                std.debug.assert(self.blockIndex > 0);
                const ends = self.queue.blocks.block(self.blockIndex - 1).ends.mask;
                std.debug.assert(ends != 0);
                return 64 - @as(u32, @intCast(@clz(ends)));
            }

            pub fn toBlockRelativeIndex(self: *const IterSelf, absoluteIndex: u32) ?u32 {
                std.debug.assert(self.blockIndex > 0);
                std.debug.assert(absoluteIndex < self.queue.list.items.len);
                const blockInfo = self.queue.blocks.block(self.blockIndex - 1);
                const kind = self.queue.indexToKind(absoluteIndex);
                const kindIndex = @intFromEnum(kind);
                if (!blockInfo.kinds.isSet(kindIndex)) return null;

                const range = self.kindBlockRanges[kindIndex];
                if (absoluteIndex < range.start or absoluteIndex >= range.end) return null;

                return range.localBase + absoluteIndex - range.start;
            }

            pub fn toAbsoluteIndex(self: *const IterSelf, blockRelativeIndex: u32) u32 {
                std.debug.assert(self.blockIndex > 0);
                std.debug.assert(blockRelativeIndex < self.blockLen());
                const blockInfo = self.queue.blocks.block(self.blockIndex - 1);
                const endsBeforeIndex = blockInfo.ends.mask & bitset.lowBits(blockRelativeIndex).mask;
                const kindOrdinal: u32 = @intCast(@popCount(endsBeforeIndex));
                const kindIndex = kindIndexForOrdinal(blockInfo.kinds, kindOrdinal);
                const range = self.kindBlockRanges[kindIndex];
                return range.start + blockRelativeIndex - range.localBase;
            }
        };
    }
};

fn kindIndexForOrdinal(kinds: KindBitSet, ordinal: u32) usize {
    // A 50M-iteration standalone benchmark on 2026-05-24 measured the iterator-counter variant at 5.249 ns/op versus 8.847 ns/op for the branchy selectSetBit helper.
    var remaining = ordinal;
    var iter = kinds.iterator(.{});
    while (iter.next()) |kindIndex| {
        if (remaining == 0) return kindIndex;
        remaining -= 1;
    }
    unreachable;
}
