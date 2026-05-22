const std = @import("std");
const ir = @import("../ir.zig");
const irq = @import("../irq.zig");
const tok = @import("../token.zig");

const TK = tok.Kind;
const expect = std.testing.expect;
const expectEqual = std.testing.expectEqual;
const KindBitSet = std.bit_set.IntegerBitSet(64);

fn expectedBlockMap(kinds: []const TK) u64 {
    var set = KindBitSet.initEmpty();
    for (kinds) |kind| {
        set.set(@intFromEnum(kind));
    }
    return set.mask;
}

fn expectInCurrentBlock(blockIter: anytype, index: u32) !void {
    try expect(blockIter.getBlockLocalIndex(index) != null);
}

fn expectNotInCurrentBlock(blockIter: anytype, index: u32) !void {
    try expect(blockIter.getBlockLocalIndex(index) == null);
}

fn expectBlockRange(blockIter: anytype, kind: TK, start: u32, end: u32) !void {
    const range = blockIter.blockRange(kind);
    try expectEqual(start, range.start);
    try expectEqual(end, range.end);
}

fn collectBlockMaps(queue: *ir.IRQueue, out: []u32) usize {
    var count: usize = 0;
    for (queue.list.items, 0..) |_, index| {
        const irIndex: u32 = @intCast(index);
        if (queue.indexToKind(irIndex) == TK.ir_block_map) {
            std.debug.assert(count < out.len);
            out[count] = irIndex;
            count += 1;
        }
    }
    return count;
}

test "IR counts include parser counts and block enter exit plumbing" {
    var counts: [64]u32 = [_]u32{0} ** 64;
    counts[@intFromEnum(TK.lit_number)] = 3;
    counts[@intFromEnum(TK.ir_use)] = 2;
    counts[@intFromEnum(TK.ir_def)] = 1;

    const kindCounts = ir.IR.calcKindCounts(counts);

    try expectEqual(3, kindCounts[@intFromEnum(TK.lit_number)]);
    try expectEqual(2, kindCounts[@intFromEnum(TK.ir_use)]);
    try expectEqual(1, kindCounts[@intFromEnum(TK.ir_def)]);
    try expectEqual(0, kindCounts[@intFromEnum(TK.ir_frame)]);
    try expectEqual(1, kindCounts[@intFromEnum(TK.ir_enter)]);
    try expectEqual(1, kindCounts[@intFromEnum(TK.ir_exit)]);
    try expectEqual(1, kindCounts[@intFromEnum(TK.ir_block_map)]);
}

test "IR counts include root scope blocks and continuations" {
    var counts: [64]u32 = [_]u32{0} ** 64;
    counts[@intFromEnum(TK.grp_indent)] = 2;
    counts[@intFromEnum(TK.grp_dedent)] = 2;

    const kindCounts = ir.IR.calcKindCounts(counts);

    try expectEqual(0, kindCounts[@intFromEnum(TK.grp_indent)]);
    try expectEqual(0, kindCounts[@intFromEnum(TK.grp_dedent)]);
    try expectEqual(5, kindCounts[@intFromEnum(TK.ir_enter)]);
    try expectEqual(5, kindCounts[@intFromEnum(TK.ir_exit)]);
    try expectEqual(5, kindCounts[@intFromEnum(TK.ir_block_map)]);
}

test "IR queue writes by reserved index without shifting nodes" {
    var counts: [64]u32 = [_]u32{0} ** 64;
    counts[@intFromEnum(TK.op_add)] = 1;
    counts[@intFromEnum(TK.lit_number)] = 2;
    const kindCounts = ir.IR.calcKindCounts(counts);

    var queue = try ir.IRQueue.init(std.testing.allocator);
    defer queue.deinit(std.testing.allocator);
    try queue.reserve(std.testing.allocator, kindCounts, 4);

    const firstLit = queue.emitKind(TK.lit_number, irq.args(11, 0));
    const add = queue.emitKind(TK.op_add, irq.args(99, 0));
    const secondLit = queue.emitKind(TK.lit_number, irq.args(12, 0));

    try expectEqual(@as(u32, 0), add);
    try expectEqual(@as(u32, 1), firstLit);
    try expectEqual(@as(u32, 2), secondLit);
    try expectEqual(@as(u32, 99), queue.get(add).args.left);
    try expectEqual(@as(u32, 11), queue.get(firstLit).args.left);
    try expectEqual(@as(u32, 12), queue.get(secondLit).args.left);
}

test "IR queue maps reserved indexes back to kinds" {
    var kindCounts: [64]u32 = [_]u32{0} ** 64;
    kindCounts[@intFromEnum(TK.op_add)] = 3;
    kindCounts[@intFromEnum(TK.lit_number)] = 70;
    kindCounts[@intFromEnum(TK.ir_use)] = 2;

    var queue = try ir.IRQueue.init(std.testing.allocator);
    defer queue.deinit(std.testing.allocator);
    try queue.reserve(std.testing.allocator, kindCounts, 4);

    const firstAdd = queue.emitKind(TK.op_add, irq.args(1, 0));
    _ = queue.emitKind(TK.op_add, irq.args(2, 0));
    const lastAdd = queue.emitKind(TK.op_add, irq.args(3, 0));

    const firstLit = queue.emitKind(TK.lit_number, irq.args(4, 0));
    var lastLit = firstLit;
    for (1..70) |i| {
        lastLit = queue.emitKind(TK.lit_number, irq.args(@intCast(i + 4), 0));
    }

    const firstUse = queue.emitKind(TK.ir_use, irq.args(74, 0));
    const lastUse = queue.emitKind(TK.ir_use, irq.args(75, 0));

    try expectEqual(TK.op_add, queue.indexToKind(firstAdd));
    try expectEqual(TK.op_add, queue.indexToKind(lastAdd));
    try expectEqual(TK.lit_number, queue.indexToKind(firstLit));
    try expectEqual(TK.lit_number, queue.indexToKind(lastLit));
    try expectEqual(TK.ir_use, queue.indexToKind(firstUse));
    try expectEqual(TK.ir_use, queue.indexToKind(lastUse));
}

test "IR block map records emitted kinds but excludes block maps" {
    var kindCounts: [64]u32 = [_]u32{0} ** 64;
    kindCounts[@intFromEnum(TK.lit_number)] = 1;
    kindCounts[@intFromEnum(TK.op_add)] = 1;
    kindCounts[@intFromEnum(TK.ir_enter)] = 1;
    kindCounts[@intFromEnum(TK.ir_exit)] = 1;
    kindCounts[@intFromEnum(TK.ir_block_map)] = 1;

    var queue = try ir.IRQueue.init(std.testing.allocator);
    defer queue.deinit(std.testing.allocator);
    try queue.reserve(std.testing.allocator, kindCounts, 4);

    queue.startBlock();
    _ = queue.emitKind(TK.lit_number, irq.args(11, 0));
    _ = queue.emitKind(TK.op_add, irq.args(12, 0));
    _ = queue.endBlock();

    var blockMaps: [1]u32 = undefined;
    try expectEqual(@as(usize, 1), collectBlockMaps(&queue, &blockMaps));
    try expectEqual(expectedBlockMap(&[_]TK{ TK.op_add, TK.lit_number, TK.ir_exit, TK.ir_enter }), queue.get(blockMaps[0]).raw);
}

test "IR sibling block maps keep their masks separate" {
    var kindCounts: [64]u32 = [_]u32{0} ** 64;
    kindCounts[@intFromEnum(TK.lit_number)] = 1;
    kindCounts[@intFromEnum(TK.op_add)] = 1;
    kindCounts[@intFromEnum(TK.ir_enter)] = 2;
    kindCounts[@intFromEnum(TK.ir_exit)] = 2;
    kindCounts[@intFromEnum(TK.ir_block_map)] = 2;

    var queue = try ir.IRQueue.init(std.testing.allocator);
    defer queue.deinit(std.testing.allocator);
    try queue.reserve(std.testing.allocator, kindCounts, 4);

    queue.startBlock();
    _ = queue.emitKind(TK.lit_number, irq.args(1, 0));
    _ = queue.endBlock();

    queue.startBlock();
    _ = queue.emitKind(TK.op_add, irq.args(2, 0));
    _ = queue.endBlock();

    var blockMaps: [2]u32 = undefined;
    try expectEqual(@as(usize, 2), collectBlockMaps(&queue, &blockMaps));
    try expectEqual(expectedBlockMap(&[_]TK{ TK.lit_number, TK.ir_exit, TK.ir_enter }), queue.get(blockMaps[0]).raw);
    try expectEqual(expectedBlockMap(&[_]TK{ TK.op_add, TK.ir_exit, TK.ir_enter }), queue.get(blockMaps[1]).raw);
}

test "IR nested block plus continuation records separate block maps" {
    var kindCounts: [64]u32 = [_]u32{0} ** 64;
    kindCounts[@intFromEnum(TK.lit_number)] = 1;
    kindCounts[@intFromEnum(TK.op_add)] = 1;
    kindCounts[@intFromEnum(TK.ir_use)] = 1;
    kindCounts[@intFromEnum(TK.ir_enter)] = 3;
    kindCounts[@intFromEnum(TK.ir_exit)] = 3;
    kindCounts[@intFromEnum(TK.ir_block_map)] = 3;

    var queue = try ir.IRQueue.init(std.testing.allocator);
    defer queue.deinit(std.testing.allocator);
    try queue.reserve(std.testing.allocator, kindCounts, 4);

    queue.startBlock();
    _ = queue.emitKind(TK.lit_number, irq.args(1, 0));
    _ = queue.endBlock();

    queue.startBlock();
    _ = queue.emitKind(TK.op_add, irq.args(2, 0));
    _ = queue.endBlock();

    queue.startBlock();
    _ = queue.emitKind(TK.ir_use, irq.args(3, 0));
    _ = queue.endBlock();

    var blockMaps: [3]u32 = undefined;
    try expectEqual(@as(usize, 3), collectBlockMaps(&queue, &blockMaps));
    try expectEqual(expectedBlockMap(&[_]TK{ TK.lit_number, TK.ir_exit, TK.ir_enter }), queue.get(blockMaps[0]).raw);
    try expectEqual(expectedBlockMap(&[_]TK{ TK.op_add, TK.ir_exit, TK.ir_enter }), queue.get(blockMaps[1]).raw);
    try expectEqual(expectedBlockMap(&[_]TK{ TK.ir_exit, TK.ir_enter, TK.ir_use }), queue.get(blockMaps[2]).raw);
}

test "IR block iterator tracks membership by kind" {
    var kindCounts: [64]u32 = [_]u32{0} ** 64;
    kindCounts[@intFromEnum(TK.op_add)] = 3;
    kindCounts[@intFromEnum(TK.lit_number)] = 3;
    kindCounts[@intFromEnum(TK.ir_enter)] = 2;
    kindCounts[@intFromEnum(TK.ir_exit)] = 2;
    kindCounts[@intFromEnum(TK.ir_block_map)] = 2;

    var queue = try ir.IRQueue.init(std.testing.allocator);
    defer queue.deinit(std.testing.allocator);
    try queue.reserve(std.testing.allocator, kindCounts, 4);

    queue.startBlock();
    const firstAdd = queue.emitKind(TK.op_add, irq.args(1, 0));
    const firstLit = queue.emitKind(TK.lit_number, irq.args(2, 0));
    const secondLit = queue.emitKind(TK.lit_number, irq.args(3, 0));
    _ = queue.endBlock();

    queue.startBlock();
    const secondBlockFirstAdd = queue.emitKind(TK.op_add, irq.args(4, 0));
    const lastAdd = queue.emitKind(TK.op_add, irq.args(5, 0));
    const lastLit = queue.emitKind(TK.lit_number, irq.args(6, 0));
    _ = queue.endBlock();
    const firstExit = queue.kindRanges.reservedStart(@intFromEnum(TK.ir_exit));
    const firstEnter = queue.kindRanges.reservedStart(@intFromEnum(TK.ir_enter));

    var blockMaps: [2]u32 = undefined;
    try expectEqual(@as(usize, 2), collectBlockMaps(&queue, &blockMaps));

    var blockIter = queue.blockIterator();
    try expect(blockIter.hasMoreBlocks());
    blockIter.nextBlock();
    try expectEqual(@as(u32, 5), blockIter.blockLen());
    try expectInCurrentBlock(&blockIter, firstAdd);
    try expectInCurrentBlock(&blockIter, firstLit);
    try expectInCurrentBlock(&blockIter, secondLit);
    try expectInCurrentBlock(&blockIter, firstExit);
    try expectInCurrentBlock(&blockIter, firstEnter);
    try expectNotInCurrentBlock(&blockIter, secondBlockFirstAdd);
    try expectNotInCurrentBlock(&blockIter, lastLit);
    try expectNotInCurrentBlock(&blockIter, blockMaps[0]);
    try expectEqual(@as(?u32, 0), blockIter.getBlockLocalIndex(firstAdd));
    try expectEqual(@as(?u32, 1), blockIter.getBlockLocalIndex(firstLit));
    try expectEqual(@as(?u32, 2), blockIter.getBlockLocalIndex(secondLit));
    try expectEqual(@as(?u32, 3), blockIter.getBlockLocalIndex(firstExit));
    try expectEqual(@as(?u32, 4), blockIter.getBlockLocalIndex(firstEnter));
    try expectEqual(@as(?u32, null), blockIter.getBlockLocalIndex(secondBlockFirstAdd));
    try expectEqual(@as(?u32, null), blockIter.getBlockLocalIndex(blockMaps[0]));
    var kind = blockIter.nextKind().?;
    try expectEqual(TK.op_add, kind);
    try expectBlockRange(&blockIter, kind, firstAdd, firstAdd + 1);
    kind = blockIter.nextKind().?;
    try expectEqual(TK.lit_number, kind);
    try expectBlockRange(&blockIter, kind, firstLit, secondLit + 1);
    kind = blockIter.nextKind().?;
    try expectEqual(TK.ir_exit, kind);
    try expectBlockRange(&blockIter, kind, firstExit, firstExit + 1);
    kind = blockIter.nextKind().?;
    try expectEqual(TK.ir_enter, kind);
    try expectBlockRange(&blockIter, kind, firstEnter, firstEnter + 1);
    try expectEqual(@as(?TK, null), blockIter.nextKind());

    try expect(blockIter.hasMoreBlocks());
    blockIter.nextBlock();
    try expectEqual(@as(u32, 5), blockIter.blockLen());
    try expectNotInCurrentBlock(&blockIter, firstAdd);
    try expectNotInCurrentBlock(&blockIter, secondLit);
    try expectInCurrentBlock(&blockIter, secondBlockFirstAdd);
    try expectInCurrentBlock(&blockIter, lastAdd);
    try expectInCurrentBlock(&blockIter, lastLit);
    try expectInCurrentBlock(&blockIter, firstExit + 1);
    try expectInCurrentBlock(&blockIter, firstEnter + 1);
    try expectNotInCurrentBlock(&blockIter, blockMaps[1]);
    try expectEqual(@as(?u32, 0), blockIter.getBlockLocalIndex(secondBlockFirstAdd));
    try expectEqual(@as(?u32, 1), blockIter.getBlockLocalIndex(lastAdd));
    try expectEqual(@as(?u32, 2), blockIter.getBlockLocalIndex(lastLit));
    try expectEqual(@as(?u32, 3), blockIter.getBlockLocalIndex(firstExit + 1));
    try expectEqual(@as(?u32, 4), blockIter.getBlockLocalIndex(firstEnter + 1));
    try expectEqual(@as(?u32, null), blockIter.getBlockLocalIndex(firstAdd));
    try expectEqual(@as(?u32, null), blockIter.getBlockLocalIndex(blockMaps[1]));
    kind = blockIter.nextKind().?;
    try expectEqual(TK.op_add, kind);
    try expectBlockRange(&blockIter, kind, secondBlockFirstAdd, lastAdd + 1);
    kind = blockIter.nextKind().?;
    try expectEqual(TK.lit_number, kind);
    try expectBlockRange(&blockIter, kind, lastLit, lastLit + 1);
    kind = blockIter.nextKind().?;
    try expectEqual(TK.ir_exit, kind);
    try expectBlockRange(&blockIter, kind, firstExit + 1, firstExit + 2);
    kind = blockIter.nextKind().?;
    try expectEqual(TK.ir_enter, kind);
    try expectBlockRange(&blockIter, kind, firstEnter + 1, firstEnter + 2);
    try expectEqual(@as(?TK, null), blockIter.nextKind());
    try expect(!blockIter.hasMoreBlocks());

    blockIter.initIterator(&queue);
    try expect(blockIter.hasMoreBlocks());
    blockIter.nextBlock();
    try expectEqual(@as(u32, 5), blockIter.blockLen());
    try expectInCurrentBlock(&blockIter, firstAdd);
}

test "IR block iterator reads boundaries across bitset masks" {
    var kindCounts: [64]u32 = [_]u32{0} ** 64;
    kindCounts[@intFromEnum(TK.lit_number)] = 130;
    kindCounts[@intFromEnum(TK.ir_enter)] = 3;
    kindCounts[@intFromEnum(TK.ir_exit)] = 3;
    kindCounts[@intFromEnum(TK.ir_block_map)] = 3;

    var queue = try ir.IRQueue.init(std.testing.allocator);
    defer queue.deinit(std.testing.allocator);
    try queue.reserve(std.testing.allocator, kindCounts, 4);

    queue.startBlock();
    const firstLit = queue.emitKind(TK.lit_number, irq.args(1, 0));
    _ = queue.endBlock();

    queue.startBlock();
    const secondBlockFirstLit = queue.emitKind(TK.lit_number, irq.args(2, 0));
    var secondBlockLastLit = secondBlockFirstLit;
    for (0..69) |i| {
        secondBlockLastLit = queue.emitKind(TK.lit_number, irq.args(@intCast(i + 3), 0));
    }
    _ = queue.endBlock();

    queue.startBlock();
    const thirdBlockFirstLit = queue.emitKind(TK.lit_number, irq.args(72, 0));
    var lastLit = thirdBlockFirstLit;
    for (0..58) |i| {
        lastLit = queue.emitKind(TK.lit_number, irq.args(@intCast(i + 73), 0));
    }
    _ = queue.endBlock();

    var blockIter = queue.blockIterator();
    blockIter.nextBlock();
    try expectEqual(@as(u32, 3), blockIter.blockLen());
    try expectInCurrentBlock(&blockIter, firstLit);
    try expectNotInCurrentBlock(&blockIter, secondBlockFirstLit);

    blockIter.nextBlock();
    try expectEqual(@as(u32, 72), blockIter.blockLen());
    try expectNotInCurrentBlock(&blockIter, firstLit);
    try expectInCurrentBlock(&blockIter, secondBlockFirstLit);
    try expectInCurrentBlock(&blockIter, secondBlockLastLit);
    try expectNotInCurrentBlock(&blockIter, thirdBlockFirstLit);

    blockIter.nextBlock();
    try expectEqual(@as(u32, 61), blockIter.blockLen());
    try expectNotInCurrentBlock(&blockIter, secondBlockLastLit);
    try expectInCurrentBlock(&blockIter, thirdBlockFirstLit);
    try expectInCurrentBlock(&blockIter, lastLit);
    try expect(!blockIter.hasMoreBlocks());
}

test "IR lower maps parsed scope tokens to block maps and continuation" {
    const tokens = [_]tok.Token{
        tok.AUX_STREAM_START,
        tok.Token.lex(TK.lit_number, 1, 1),
        tok.createToken(TK.grp_indent),
        tok.Token.lex(TK.lit_number, 2, 1),
        tok.createToken(TK.grp_dedent),
    };

    var parsedQ = try ir.TokenQueue.init(std.testing.allocator);
    defer parsedQ.deinit();
    try parsedQ.reserve(tokens.len);
    for (tokens) |token| parsedQ.push(token);

    var parserCounts: [64]u32 = [_]u32{0} ** 64;
    parserCounts[@intFromEnum(TK.lit_number)] = 2;
    parserCounts[@intFromEnum(TK.grp_indent)] = 1;
    parserCounts[@intFromEnum(TK.grp_dedent)] = 1;
    const kindCounts = ir.IR.calcKindCounts(parserCounts);

    var queue = try ir.IRQueue.init(std.testing.allocator);
    defer queue.deinit(std.testing.allocator);
    try queue.reserve(std.testing.allocator, kindCounts, 4);

    var lowering = ir.IR.init(std.testing.allocator, &parsedQ, &queue);
    const exitIdx = try lowering.lower();

    var blockMaps: [3]u32 = undefined;
    try expectEqual(@as(usize, 3), collectBlockMaps(&queue, &blockMaps));
    try expectEqual(TK.ir_exit, queue.indexToKind(exitIdx));
    try expectEqual(expectedBlockMap(&[_]TK{ TK.lit_number, TK.ir_exit, TK.ir_enter }), queue.get(blockMaps[0]).raw);
    try expectEqual(expectedBlockMap(&[_]TK{ TK.lit_number, TK.ir_exit, TK.ir_enter }), queue.get(blockMaps[1]).raw);
    try expectEqual(expectedBlockMap(&[_]TK{ TK.ir_exit, TK.ir_enter }), queue.get(blockMaps[2]).raw);

    const firstExit = queue.kindRanges.reservedStart(@intFromEnum(TK.ir_exit));
    const firstEnter = queue.kindRanges.reservedStart(@intFromEnum(TK.ir_enter));
    try expectEqual(irq.args(firstEnter, @as(u32, 0)), queue.get(firstExit));
    try expectEqual(irq.args(firstEnter + 1, @as(u32, 1)), queue.get(firstExit + 1));
    try expectEqual(irq.args(firstEnter + 2, firstEnter + 2), queue.get(firstExit + 2));

    var blockIter = queue.blockIterator();
    try expect(blockIter.hasMoreBlocks());
    blockIter.nextBlock();
    try expectInCurrentBlock(&blockIter, @as(u32, 0));
    try expectInCurrentBlock(&blockIter, firstExit);
    try expectInCurrentBlock(&blockIter, firstEnter);
    try expectNotInCurrentBlock(&blockIter, @as(u32, 1));
    try expectNotInCurrentBlock(&blockIter, exitIdx);

    try expect(blockIter.hasMoreBlocks());
    blockIter.nextBlock();
    try expectNotInCurrentBlock(&blockIter, @as(u32, 0));
    try expectNotInCurrentBlock(&blockIter, firstExit);
    try expectNotInCurrentBlock(&blockIter, firstEnter);
    try expectInCurrentBlock(&blockIter, @as(u32, 1));
    try expectInCurrentBlock(&blockIter, firstExit + 1);
    try expectInCurrentBlock(&blockIter, firstEnter + 1);
    try expectNotInCurrentBlock(&blockIter, exitIdx);

    try expect(blockIter.hasMoreBlocks());
    blockIter.nextBlock();
    try expectNotInCurrentBlock(&blockIter, @as(u32, 0));
    try expectNotInCurrentBlock(&blockIter, @as(u32, 1));
    try expectNotInCurrentBlock(&blockIter, firstExit);
    try expectNotInCurrentBlock(&blockIter, firstEnter);
    try expectInCurrentBlock(&blockIter, firstEnter + 2);
    try expectInCurrentBlock(&blockIter, exitIdx);
    try expect(!blockIter.hasMoreBlocks());
}
