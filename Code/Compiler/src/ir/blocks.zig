const BitSet64 = @import("../bitset.zig").BitSet64;
const KindRanges = @import("kind_ranges.zig").KindRanges;

pub const MAX_BLOCK_LEN = 64;

pub const Block = struct {
    const Self = @This();

    kinds: BitSet64, // What token kinds are present in this block.
    counts: BitSet64, // Count of each present kind represented by distance between Nth set bits.
    // i.e. 2, 3, 2 lengths = 01-001-01

    pub fn len(self: Self) usize {
        return self.counts.findLastSet() orelse 0;
    }
};

pub const Blocks = struct {
    const Self = @This();
    kindRanges: *KindRanges,
};
