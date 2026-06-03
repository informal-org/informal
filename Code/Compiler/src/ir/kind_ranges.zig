const tok = @import("../token.zig");
const std = @import("std");
const blocks = @import("blocks.zig");
const BitSet64 = @import("../bitset.zig").BitSet64;

const NUM_KINDS = 64;
const Kind = tok.Kind;

pub const KindRanges = struct {
    // An abstraction to maintain how many of each kind of element there are.
    // IR stores elements by kind.
    const Self = @This();

    // There's 3 bits of information packed into this.
    // During parsing, this stores the count of each token kind.
    // At initialization, it become the cumulative count - which is the "start" cursor. It moves with each insert.
    // After all elements are added, it points to the end of each range.
    // Only assertion is that IR conversion MUST insert the same exact count of elements that parser counted. Never more or less (i.e. if we do constant folding, add sentinels). Else the end boundaries will be off.
    kindRanges: [NUM_KINDS]u32 = [_]u32{0} ** NUM_KINDS,
    kindSnapshot: [NUM_KINDS]u32 = [_]u32{0} ** NUM_KINDS,

    pub fn incKind(self: *Self, kind: Kind) u32 {
        // Called by parser to increment counts
        // Called by IR conversion as a cursor for insertion.
        const kindId = @intFromEnum(kind);
        std.debug.assert(kindId < NUM_KINDS);
        const countCursor = self.kindRanges[kindId];
        self.kindRanges[kindId] = countCursor + 1;
        return countCursor;
    }

    pub fn lockRanges(self: *Self) u32 {
        // Turn kind counts -> kind starts by cumulative sum. Return total length.
        // Invariant: Must be called only once!
        var total = 0;
        for (self.kindRanges, 0..) |kindCount, i| {
            self.kindRanges[i] = total;
            total += kindCount;
        }
        return total;
    }

    pub fn snapshot(self: *Self) blocks.Block {
        // Take a snapshot of the kind-ranges after a block is complete
        // Indicating which kinds are present, and how many of each kind.
        const block = blocks.Block{ .kinds = BitSet64.initEmpty(), .counts = BitSet64.initEmpty() };

        for (0..NUM_KINDS) |index| {
            const numKindAdded = self.kindRanges[index] - self.kindSnapshot[index];
            if (numKindAdded != 0) {
                // Then this kind was added since last snapshot.
                block.kinds.set(index);
                // Set the next bit after N slots to indicate that many elements of this kind are present.
                const endIndex = block.counts.findLastSet() + numKindAdded;
                // Overall block sizes are capped, so this should never overflow.
                std.debug.assert(endIndex < blocks.MAX_BLOCK_LEN);
                block.counts.set(endIndex);

                // Snapshot for the next round.
                self.kindSnapshot[index] = self.kindRanges[index];
            }
        }
        return block;
    }
};
