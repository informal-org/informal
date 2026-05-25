const std = @import("std");
const tok = @import("../token.zig");
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

    pub const BlockRange = packed struct(u64) {
        start: u32,
        end: u32, // Exclusive.

        pub fn len(self: BlockRange) u32 {
            return self.end - self.start;
        }
    };

    activeKindStarts: [KIND_COUNT]u32 = [_]u32{0} ** KIND_COUNT,
    blocks: BlockList = .empty,
    cursor: u32 = 0,

    pub fn reserve(self: *Self, allocator: Allocator, reservedBlockCount: u32) !void {
        const capacity: usize = @intCast(reservedBlockCount);
        self.blocks.clearRetainingCapacity();
        try self.blocks.ensureTotalCapacity(allocator, capacity);
        self.blocks.appendNTimesAssumeCapacity(.{ .kinds = KindBitSet.initEmpty(), .ends = KindEndSet.initEmpty() }, capacity);
        self.activeKindStarts = [_]u32{0} ** KIND_COUNT;
        self.cursor = 0;
    }

    pub fn startBlock(self: *Self) void {
        std.debug.assert(self.cursor < self.blocks.items.len);
        self.blocks.items[@intCast(self.cursor)] = .{ .kinds = KindBitSet.initEmpty(), .ends = KindEndSet.initEmpty() };
    }

    pub fn endBlock(self: *Self, kindRanges: *const KindRanges) void {
        std.debug.assert(self.cursor < self.blocks.items.len);
        const blockIndex: usize = @intCast(self.cursor);
        const blockInfo = &self.blocks.items[blockIndex];
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
        self.cursor += 1;
    }

    pub fn markActiveBlockKind(self: *Self, kind: TK, index: u32) void {
        if (kind == TK.ir_block_map) return;
        if (self.cursor >= self.blocks.items.len) return;
        const blockInfo = &self.blocks.items[@intCast(self.cursor)];
        const kindIndex = @intFromEnum(kind);
        if (!blockInfo.kinds.isSet(kindIndex)) {
            self.activeKindStarts[kindIndex] = index;
            blockInfo.kinds.set(kindIndex);
        }
    }

    pub fn blockCount(self: *const Self) u32 {
        return self.cursor;
    }

    pub fn block(self: *const Self, blockIndex: u32) Block {
        std.debug.assert(blockIndex < self.cursor);
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
            blockKindMap: KindBitSet = KindBitSet.initEmpty(),
            kindNextStarts: [KIND_COUNT]u32 = [_]u32{0} ** KIND_COUNT,
            kindBlockRanges: [KIND_COUNT]BlockRange = [_]BlockRange{.{ .start = 0, .end = 0 }} ** KIND_COUNT,
            blockLocalBases: [KIND_COUNT]u32 = [_]u32{0} ** KIND_COUNT,
            len: u32 = 0,
            nextKindIter: KindBitSetIterator = KindBitSet.initEmpty().iterator(.{}),

            pub fn initIterator(self: *IterSelf, queue: *const Queue) void {
                self.queue = queue;
                self.blockIndex = 0;
                self.blockKindMap = KindBitSet.initEmpty();
                for (&self.kindNextStarts, 0..) |*start, kindIndex| {
                    start.* = queue.kindRanges.reservedStart(kindIndex);
                }
                self.kindBlockRanges = [_]BlockRange{.{ .start = 0, .end = 0 }} ** KIND_COUNT;
                self.blockLocalBases = [_]u32{0} ** KIND_COUNT;
                self.len = 0;
                self.nextKindIter = KindBitSet.initEmpty().iterator(.{});
            }

            pub fn hasMoreBlocks(self: *const IterSelf) bool {
                return self.blockIndex < self.queue.blocks.blockCount();
            }

            pub fn nextBlock(self: *IterSelf) void {
                std.debug.assert(self.hasMoreBlocks());
                const currentBlockIndex = self.blockIndex;
                self.blockIndex += 1;

                const blockInfo = self.queue.blocks.block(currentBlockIndex);
                self.blockKindMap = blockInfo.kinds;

                var localStart: u32 = 0;
                var kindIter = self.blockKindMap.iterator(.{});
                var endIter = blockInfo.ends.iterator(.{});
                while (kindIter.next()) |kindIndex| {
                    const localEnd: u32 = @intCast((endIter.next() orelse unreachable) + 1);
                    std.debug.assert(localEnd > localStart);
                    const start = self.kindNextStarts[kindIndex];
                    const end = start + localEnd - localStart;
                    self.kindBlockRanges[kindIndex] = .{ .start = start, .end = end };
                    self.kindNextStarts[kindIndex] = end;
                    self.blockLocalBases[kindIndex] = localStart;
                    localStart = localEnd;
                }
                std.debug.assert(endIter.next() == null);

                self.len = localStart;
                self.nextKindIter = self.blockKindMap.iterator(.{});
            }

            pub fn nextKind(self: *IterSelf) ?TK {
                const kindIndex = self.nextKindIter.next() orelse return null;
                return @enumFromInt(kindIndex);
            }

            pub fn blockRange(self: *const IterSelf, kind: TK) BlockRange {
                const kindIndex = @intFromEnum(kind);
                std.debug.assert(self.blockKindMap.isSet(kindIndex));
                return self.kindBlockRanges[kindIndex];
            }

            pub fn blockLen(self: *const IterSelf) u32 {
                return self.len;
            }

            pub fn blockIdToLocalId(self: *const IterSelf, absoluteIndex: u32) ?u32 {
                std.debug.assert(absoluteIndex < self.queue.list.items.len);
                const kind = self.queue.indexToKind(absoluteIndex);
                const kindIndex = @intFromEnum(kind);
                if (!self.blockKindMap.isSet(kindIndex)) return null;

                const range = self.kindBlockRanges[kindIndex];
                if (absoluteIndex < range.start or absoluteIndex >= range.end) return null;

                return self.blockLocalBases[kindIndex] + absoluteIndex - range.start;
            }
        };
    }
};
