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
    kindRanges: *KindRanges,
    blocks: BlockList,

    pub fn init(allocator: Allocator, kindRanges: *KindRanges, length: u32) !Self {
        const blocks = try BlockList.initCapacity(allocator, length);
        return Self{ .kindRanges = kindRanges, .blocks = blocks };
    }

    pub fn deinit(self: *Self, allocator: Allocator) void {
        return self.blocks.deinit(allocator);
    }

    pub fn appendBlock(self: *Self, block: Block) void {
        self.blocks.appendAssumeCapacity(block);
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
        kindRanges: KindRanges,
        kindIter: KindIterator,
        countIter: CountIterator,
        blockIndex: usize = 0,

        pub fn init(blocks: *Blocks) Self {
            // Forward = empty kind ranges.
            // Reverse = Init kind ranges to a snapshot of the end state.
            return Self{ .blocks = blocks, .kindRanges = KindRanges{}, .kindIter = KindIterator{ .iter = BitSet64.empty.iterator(.{}) }, .countIter = CountIterator{ .iter = BitSet64.empty.iterator(.{}), .prevCount = 0 } };
        }

        pub fn nextBlock(self: *Self) ?Block {
            if (self.blockIndex < self.blocks.len()) {
                const block = self.blocks.get(self.blockIndex);
                self.kindRanges.iter(block, direction);
                self.kindIter = KindIterator{ .iter = block.kinds.iterator(.{}) };
                self.countIter = CountIterator{ .iter = block.counts.iterator(.{}), .prevCount = 0 };
                self.blockIndex += 1;
                return block;
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
    prevCount: u8 = 0,

    pub fn next(self: *CountIterator) ?u8 {
        const count = self.iter.next() orelse return null;
        std.debug.assert(count < 255);
        const countu8: u8 = @truncate(count);
        const gap: u8 = countu8 - self.prevCount;
        self.prevCount = countu8;
        return gap;
    }
};
