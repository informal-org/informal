const std = @import("std");
const tok = @import("../token.zig");
const BitSet64 = @import("../bitset.zig").BitSet64;
const KindCounts = @import("kind_ranges.zig").KindCounts;
const KindCursor = @import("kind_ranges.zig").KindCursor;
const Kind = tok.Kind;

// pub const Direction = enum {
//     // From bit_set.IteratorOptions.Direction
//     forward,
//     reverse,
// };

pub const MAX_BLOCK_LEN = 64;
const Allocator = std.mem.Allocator;
const BlockList = std.array_list.Aligned(Block, null);

pub const KindCount = struct { kind: Kind, count: u32 };

pub const Block = struct {
    const Self = @This();

    kinds: KindSet, // What token kinds are present in this block.
    counts: BitSet64, // Count of each present kind represented by distance between Nth set bits.
    // i.e. 2, 3, 2 lengths = 01-001-01

    pub fn initBetween(starts: KindCursor, ends: KindCursor) Self {
        // Takes the two cursor states and figures out how many of each kind of element there were. That represents the block compactly (without needing to store a whole array of indexes).
        var block = Self{ .kinds = KindSet{ .kinds = BitSet64.empty }, .counts = BitSet64.empty };
        var total: u32 = 0;
        for (starts.cursor, ends.cursor, 0..) |start, end, kindIndex| {
            const numKindAdded = end - start;
            // Check for presence of any ops/elements of this kind in current block.
            if (numKindAdded != 0) {
                block.kinds.kinds.set(kindIndex);
                total += numKindAdded;
                // Distance between bits indicates count of elements of this kind present.
                std.debug.assert(total <= MAX_BLOCK_LEN);
                block.counts.set(total - 1); // minus 1 so zeroth index doesn't go wasted.
            }
        }
        return block;
    }

    pub fn len(self: Self) usize {
        const lastCount = self.counts.findLastSet();
        if (lastCount) {
            return lastCount + 1;
        }
        return 0;
    }

    // pub fn kindIter(self: *Self) KindIterator {
    //     return .{ .iter = self.kinds.iterator(.{}) };
    // }

    pub const Iterator = struct {
        kinds: KindSet.Iterator,
        counts: BitSet64.Iterator(.{}),
        prevCountIndex: u32 = 0,

        // pub fn next(self: *CountIterator) ?u8 {
        //     if (self.prevCount) |previous| {
        //         const count = self.iter.next() orelse return null;
        //         std.debug.assert(count < 255);
        //         const countu8: u8 = @truncate(count);
        //         const gap: u8 = countu8 - previous;
        //         self.prevCount = countu8;
        //         return gap;
        //     } else {
        //         // Set the initial bit. Zero init causes issues when first bit is set at 0.
        //         const count = self.iter.next() orelse return null;
        //         self.prevCount = @truncate(count);
        //         // 0th index set = count 1.
        //         // 1st index set = count 2. etc. for first count. From there it's the gaps.
        //         return @truncate(count + 1);
        //     }
        // }
        //

        pub fn next(self: *Iterator) ?KindCount {
            const nextKind = self.kinds.next() orelse return null;
            const nextCountIndex: u32 = @intCast((self.counts.next() orelse unreachable) + 1);
            const count = nextCountIndex - self.prevCountIndex;
            self.prevCountIndex = nextCountIndex;
            // const nextCount = self.counts.next() orelse unreachable; // The two should be in lock-step, so if kinds isn't null, this one shouldn't ever be - else it's indicative of a bug elsewhere.
            return KindCount{ .kind = nextKind, .count = count };
        }
    };

    pub fn iterator(self: Self) Iterator {
        std.debug.assert(self.kinds.kinds.count() == self.counts.count());
        return .{ .kinds = self.kinds.iterator(), .counts = self.counts.iterator(.{}) };
    }
};

pub const Blocks = struct {
    const Self = @This();
    starts: KindCursor,

    blocks: BlockList,

    pub fn init(allocator: Allocator, kindCounts: KindCounts, length: u32) !Self {
        const blocks = try BlockList.initCapacity(allocator, length);
        return Self{ .starts = KindCursor.init(kindCounts), .blocks = blocks };
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

    pub const Iterator = struct {
        blocks: *Blocks,
        cursor: KindCursor,
        blockIndex: u32 = 0, // Actual block IDs start at 1. That's important for depmap block membership detection.

        pub fn init(blks: *Blocks) Iterator {
            return Iterator{ .blocks = blks, .cursor = blks.starts };
        }

        fn advance(self: *Iterator, block: Block) void {
            var iter = block.iterator();
            while (iter.next()) |e| {
                self.cursor.addKind(e.kind, e.count);
            }
        }

        pub fn nextBlock(self: *Iterator) ?Block {
            if (self.blockIndex < self.blocks.len()) {
                const block = self.blocks.get(self.blockIndex);
                self.advance(block);
                self.blockIndex += 1;
                return block;
            }
            return null;
        }
    };
};

// pub fn BlockIter() type {
//     return struct {
//         const Self = @This();
//         blocks: *Blocks,
//         cursor: KindCursor,
//
//         kindIter: KindIterator,
//         countIter: CountIterator,
//         blockIndex: u32 = 0, // Actual block IDs start at 1. That's important for depmap block membership detection.
//
//         pub fn init(blocks: *Blocks) Self {
//             // Forward = empty kind ranges.
//             // Reverse = TODO: Init kind ranges to a snapshot of the end state.
//             const kindRanges = blocks.kindCursor.counts.lockRanges();
//             return Self{ .blocks = blocks, .cursor = kindRanges, .kindIter = KindIterator{ .iter = BitSet64.empty.iterator(.{}) }, .countIter = CountIterator{ .iter = BitSet64.empty.iterator(.{}), .prevCount = null } };
//         }
//
//         pub fn resetIter(self: *Self) void {
//             const block = self.blocks.get(self.blockIndex - 1);
//             self.kindIter = KindIterator{ .iter = block.kinds.iterator(.{}) };
//             self.countIter = CountIterator{ .iter = block.counts.iterator(.{}), .prevCount = null };
//         }
//
//         pub fn nextBlock(self: *Self) ?Block {
//             if (self.blockIndex < self.blocks.len()) {
//                 const block = self.blocks.get(self.blockIndex);
//                 self.cursor.iter(block, direction);
//                 self.blockIndex += 1;
//                 self.resetIter();
//                 return block;
//             }
//             return null;
//         }
//
//         pub fn nextRange(self: *Self, kind: Kind) ?Range {
//             const kindIndex = @backingInt(kind);
//             const kindEnd = self.cursor.kindRanges[kindIndex];
//             if (self.countIter.next()) |kindCount| {
//                 return Range{ .current = kindEnd - @as(u32, kindCount), .end = kindEnd };
//             }
//             return null;
//         }
//     };
// }

pub const KindSet = struct {
    const Self = @This();
    kinds: BitSet64,

    pub const Iterator = struct {
        iter: BitSet64.Iterator(.{}),
        pub fn next(self: *Iterator) ?Kind {
            const kindIndex = self.iter.next() orelse return null;
            return @fromBackingInt(@intCast(kindIndex));
        }
    };

    pub fn iterator(self: Self) Iterator {
        return .{ .iter = self.kinds.iterator(.{}) };
    }
};

// pub const KindIterator = struct {
//     iter: BitSet64.Iterator(.{}),
//
//     pub fn next(self: *KindIterator) ?Kind {
//         const kindIndex = self.iter.next() orelse return null;
//         return @fromBackingInt(@intCast(kindIndex));
//     }
// };

// pub const CountIterator = struct {
//
// };

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
