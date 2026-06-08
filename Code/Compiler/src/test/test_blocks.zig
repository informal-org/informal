const std = @import("std");

const blk = @import("../ir/blocks.zig");
const KindRanges = @import("../ir/kind_ranges.zig").KindRanges;
const expect = std.testing.expect;
const expectEqual = std.testing.expectEqual;
const Kind = @import("../token.zig").Kind;
const Block = blk.Block;
const Blocks = blk.Blocks;
const Direction = blk.Direction;
const BlockIter = blk.BlockIter(Direction.forward);
const allocator = std.testing.allocator;

pub fn addKindNTimes(kinds: *KindRanges, kind: Kind, n: usize) void {
    for (0..n) |_| {
        _ = kinds.incKind(kind);
    }
}

pub fn kindCount(kinds: *KindRanges, kind: Kind) usize {
    return kinds.kindRanges[@intFromEnum(kind)];
}

test "Test kind counts" {
    var blockSnapshots = KindRanges{};
    var kindRanges = KindRanges{};
    try expect(kindRanges.incKind(Kind.identifier) == 0);
    try expect(kindRanges.incKind(Kind.identifier) == 1);
    addKindNTimes(&kindRanges, Kind.identifier, 3);
    addKindNTimes(&kindRanges, Kind.lit_number, 7);
    std.debug.assert(kindCount(&kindRanges, Kind.identifier) == 5);
    std.debug.assert(kindCount(&kindRanges, Kind.lit_number) == 7);
    var blocks = try Blocks.init(allocator, &kindRanges, 2);
    defer blocks.deinit(allocator);

    // Convert kind counts into blocks.
    const block0 = blockSnapshots.snapshot(kindRanges);
    try expect(block0.kinds.count() == 2);
    try expect(block0.counts.count() == 2);
    blocks.appendBlock(block0);

    // Test with some new kinds and some existing kind.
    addKindNTimes(&kindRanges, Kind.lit_string, 2);
    addKindNTimes(&kindRanges, Kind.identifier, 4);
    addKindNTimes(&kindRanges, Kind.op_add, 1);
    const block1 = blockSnapshots.snapshot(kindRanges);
    try expect(block1.kinds.count() == 3);
    try expect(block1.counts.count() == 3);

    var blockIter = BlockIter.init(&blocks);
    while (blockIter.nextBlock()) |block| {
        std.debug.print("got block .{}\n", .{block});
        while (blockIter.kindIter.next()) |kind| {
            std.debug.print("Got kind .{}\n", .{kind});
            const count = blockIter.countIter.next() orelse unreachable;
            std.debug.print("Got count .{}\n", .{count});
        }
    }
}
