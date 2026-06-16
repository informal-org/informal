const std = @import("std");
const tok = @import("../token.zig");
const BitSet64 = @import("../bitset.zig").BitSet64;
const KindRanges = @import("kind_ranges.zig").KindRanges;
const Kind = tok.Kind;

pub const Direction = enum {
    // From bit_set.IteratorOptions.Direction
    forward,
    reverse,
};

pub const MAX_BLOCK_LEN = 64;
const Allocator = std.mem.Allocator;
const BlockList = std.array_list.Aligned(Block, null);

pub const Block = struct {
    const Self = @This();

    kinds: BitSet64, // What token kinds are present in this block.
    counts: BitSet64, // Count of each present kind represented by distance between Nth set bits.
    // i.e. 2, 3, 2 lengths = 01-001-01

    pub fn len(self: Self) usize {
        return self.counts.findLastSet() orelse 0;
    }

    pub fn kindIter(self: *Self) KindIterator {
        return .{ .iter = self.kinds.iterator(.{}) };
    }
};

pub const Blocks = struct {
    const Self = @This();
    // TODO: Maintaining both here kinda sucks. Is there a better way?
    kindBase: KindRanges,
    kindCursor: KindRanges,
    blocks: BlockList,

    pub fn init(allocator: Allocator, kindRanges: *KindRanges, length: u32) !Self {
        const blocks = try BlockList.initCapacity(allocator, length);
        var blockKindRanges = KindRanges{};
        var kindBases = KindRanges{};
        for (kindRanges.kindRanges, 0..) |range, i| {
            kindBases.kindRanges[i] = range;
            blockKindRanges.kindRanges[i] = range;
        }
        return Self{ .kindBase = kindBases, .kindCursor = blockKindRanges, .blocks = blocks };
    }

    pub fn deinit(self: *Self, allocator: Allocator) void {
        return self.blocks.deinit(allocator);
    }

    pub fn appendBlock(self: *Self, block: Block) void {
        self.blocks.appendAssumeCapacity(block);
    }

    pub fn snapshotBlock(self: *Self, kindCursor: *KindRanges) void {
        self.appendBlock(self.kindCursor.snapshot(kindCursor));
    }

    pub fn get(self: *Self, index: usize) Block {
        return self.blocks.items[index];
    }

    pub fn len(self: *Self) usize {
        return self.blocks.items.len;
    }
};

pub fn BlockIter(comptime direction: Direction) type {
    // _ = direction;

    return struct {
        const Self = @This();
        blocks: *Blocks,
        endRanges: KindRanges,

        kindIter: KindIterator,
        countIter: CountIterator,
        blockIndex: u32 = 0, // Actual block IDs start at 1. That's important for depmap block membership detection.

        pub fn init(blocks: *Blocks) Self {
            // Forward = empty kind ranges.
            // Reverse = TODO: Init kind ranges to a snapshot of the end state.
            const kindRanges = blocks.kindBase;
            return Self{ .blocks = blocks, .endRanges = kindRanges, .kindIter = KindIterator{ .iter = BitSet64.empty.iterator(.{}) }, .countIter = CountIterator{ .iter = BitSet64.empty.iterator(.{}), .prevCount = null } };
        }

        pub fn resetIter(self: *Self) void {
            const block = self.blocks.get(self.blockIndex - 1);
            self.kindIter = KindIterator{ .iter = block.kinds.iterator(.{}) };
            self.countIter = CountIterator{ .iter = block.counts.iterator(.{}), .prevCount = null };
        }

        pub fn nextBlock(self: *Self) ?Block {
            if (self.blockIndex < self.blocks.len()) {
                const block = self.blocks.get(self.blockIndex);
                self.endRanges.iter(block, direction);
                self.blockIndex += 1;
                self.resetIter();
                return block;
            }
            return null;
        }

        pub fn nextRange(self: *Self, kind: Kind) ?Range {
            const kindIndex = @intFromEnum(kind);
            const kindEnd = self.endRanges.kindRanges[kindIndex];
            if (self.countIter.next()) |kindCount| {
                return Range{ .current = kindEnd - @as(u32, kindCount), .end = kindEnd };
            }
            return null;
        }
    };
}

pub const KindIterator = struct {
    iter: BitSet64.Iterator(.{}),

    pub fn next(self: *KindIterator) ?Kind {
        const kindIndex = self.iter.next() orelse return null;
        return @enumFromInt(kindIndex);
    }
};

pub const CountIterator = struct {
    iter: BitSet64.Iterator(.{}),
    prevCount: ?u8 = null, // MUST be null initialized!

    pub fn next(self: *CountIterator) ?u8 {
        if (self.prevCount) |previous| {
            const count = self.iter.next() orelse return null;
            std.debug.assert(count < 255);
            const countu8: u8 = @truncate(count);
            const gap: u8 = countu8 - previous;
            self.prevCount = countu8;
            return gap;
        } else {
            // Set the initial bit. Zero init causes issues when first bit is set at 0.
            const count = self.iter.next() orelse return null;
            self.prevCount = @truncate(count);
            // 0th index set = count 1.
            // 1st index set = count 2. etc. for first count. From there it's the gaps.
            return @truncate(count + 1);
        }
    }
};

pub const Range = struct {
    current: u32 = 0,
    end: u32 = 0,

    pub fn next(self: *Range) ?u32 {
        if (self.current >= self.end) {
            return null;
        }
        const val = self.current;
        self.current += 1;
        return val;
    }
};
