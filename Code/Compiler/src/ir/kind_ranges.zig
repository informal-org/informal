const tok = @import("../token.zig");
const std = @import("std");
const blocks = @import("blocks.zig");
const BitSet64 = @import("../bitset.zig").BitSet64;

const NUM_KINDS = 64;
const Kind = tok.Kind;

fn incKindHelper(kindCursors: *[NUM_KINDS]u32, kind: Kind, amt: u32) u32 {
    const kindId = @backingInt(kind);
    std.debug.assert(kindId < NUM_KINDS);
    const count = kindCursors[kindId];
    kindCursors[kindId] = count + amt;
    return count;
}

pub const KindCounts = struct {
    // Counter for how many of each kind of tokens are seen in a step.
    // Useful for pre-allocating in later steps. i.e. count during parse, pre-allocate IR nodes.
    const Self = @This();
    counts: [NUM_KINDS]u32 = @splat(0),

    pub fn incKind(self: *Self, kind: Kind) void {
        _ = incKindHelper(&self.counts, kind, 1);
    }
};

pub const KindCursor = struct {
    const Self = @This();
    // Absolute index position for a kind.
    cursor: [NUM_KINDS]u32 = @splat(0),

    pub fn init(kindCounts: KindCounts) Self {
        var starts = Self{};
        var total: u32 = 0;
        for (kindCounts.counts, 0..) |count, i| {
            starts.cursor[i] = total;
            total += count;
        }
        return starts;
    }

    pub fn incKind(self: *Self, kind: Kind) u32 {
        return incKindHelper(&self.cursor, kind, 1);
    }

    pub fn addKind(self: *Self, kind: Kind, count: u32) void {
        _ = incKindHelper(&self.cursor, kind, count);
    }
};
