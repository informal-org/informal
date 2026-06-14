const std = @import("std");

const blk = @import("../ir/blocks.zig");
const IRQueue = @import("../ir/irq.zig").IRQueue;
const DepMap = @import("../ir/depmap.zig").DepMap;
const Kind = @import("../token.zig").Kind;
const Token = @import("../token.zig").Token;
const KindRanges = @import("../ir/kind_ranges.zig").KindRanges;
const expect = std.testing.expect;
const allocator = std.testing.allocator;

test "Test depmap" {
    const IR_LEN = 3;
    var kindRanges = KindRanges{};
    _ = kindRanges.incKind(Kind.lit_number);
    _ = kindRanges.incKind(Kind.lit_number);
    _ = kindRanges.incKind(Kind.op_add);
    var irq = try IRQueue.init(allocator, &kindRanges, 64, IR_LEN);
    defer irq.deinit(allocator);
    irq.emitKind(Token.lex(Kind.lit_number, 42, 0));
    irq.emitKind(Token.lex(Kind.lit_number, 28, 1));
    irq.emitBinary(Token.lex(Kind.op_add, 0, 0));

    const NUM_BLOCKS = 1;
    var blocks = try blk.Blocks.init(allocator, NUM_BLOCKS);
    defer blocks.deinit(allocator);
    blocks.snapshotBlock(irq.kindCounts);

    var depmap = try DepMap.init(allocator, &irq);
    depmap.build(&blocks);
}
