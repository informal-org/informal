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

    pub fn kinds(self: *Self) KindIterator {

    }
};

pub const Blocks = struct {
    const Self = @This();
    kindRanges: *KindRanges,
    blocks: BlockList,
};

pub fn BlockIter(comptime direction: Direction) type {

    return struct {
        const Self = @This();
        blocks: *Blocks,
        kindRanges: *KindRanges,
        kindIter: BitSet64.Iterator(.{}),

        pub fn init(self: Self, blocks: *Blocks) Self {
            // Forward = empty kind ranges.
            // Reverse = Init kind ranges to a snapshot of the end state.
            return Self {
                .blocks = blocks,
            };
        }
    };
};

const KindIterator = struct {
    iter: BitSet64.Iterator(.{}),

    pub fn next(self: *KindIterator) Kind {
        const kindIndex = self.kindIter.next() orelse return null;
        return @enumFromInt(kindIndex);
    }
};

const CountIterator = struct {
    iter: BitSet64.Iterator(.{}),
    prevCount: u8 = 0,

    pub fn next(self: *CountIterator) u8? {
        const count = self.iter.next() orelse return null;
        const gap = count - prevCount;
        prevCount = count;
        return gap;
    }
};
