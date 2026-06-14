const std = @import("std");

const blk = @import("../ir/blocks.zig");
const IRQueue = @import("../ir/irq.zig").IRQueue;
const DepMap = @import("../ir/depmap.zig").DepMap;
const Kind = @import("../token.zig").Kind;
const Token = @import("../token.zig").Token;
const KindRanges = @import("../ir/kind_ranges.zig").KindRanges;
const expectEqual = std.testing.expectEqual;
const allocator = std.testing.allocator;

test "Test depmap" {
    const IR_LEN = 3;
    var kindRanges = KindRanges{};
    _ = kindRanges.incKind(Kind.lit_number);
    _ = kindRanges.incKind(Kind.lit_number);
    _ = kindRanges.incKind(Kind.op_add);
    var irq = try IRQueue.init(allocator, &kindRanges, 64, IR_LEN);
    defer irq.deinit(allocator);

    const NUM_BLOCKS = 1;
    // Note that kind ranges is locked at this point after irq init.
    var blocks = try blk.Blocks.init(allocator, &irq.kindCursor, NUM_BLOCKS);
    defer blocks.deinit(allocator);

    irq.emitKind(Token.lex(Kind.lit_number, 42, 0));
    irq.emitKind(Token.lex(Kind.lit_number, 28, 1));
    irq.emitBinary(Token.lex(Kind.op_add, 0, 0));

    blocks.snapshotBlock(&irq.kindCursor);

    var depmap = try DepMap.init(allocator, &irq);
    defer depmap.deinit(allocator);
    depmap.build(&blocks);

    // 0 = add, 1, 2 = lit numbers

    try expectEqual(Kind.lit_number, irq.tokensByKind.items[1].kind);
    try expectEqual(0, depmap.deps.items(.deps)[1].count());
    try expectEqual(1, depmap.deps.items(.refs)[1].count());
    try expectEqual(true, depmap.deps.items(.refs)[1].isSet(0));

    // TODO: We're not testing any input-cases yet.
}
