const std = @import("std");
const ir = @import("../ir.zig");
const irq = @import("../irq.zig");
const tok = @import("../token.zig");

const TK = tok.Kind;
const expect = std.testing.expect;
const expectEqual = std.testing.expectEqual;
const KindBitSet = std.bit_set.IntegerBitSet(64);
const KindEndSet = std.bit_set.IntegerBitSet(64);

fn expectedBlockMap(kinds: []const TK) u64 {
    var set = KindBitSet.initEmpty();
    for (kinds) |kind| {
        set.set(@intFromEnum(kind));
    }
    return set.mask;
}

fn expectedBlockEndMap(lengths: []const u32) u64 {
    var set = KindEndSet.initEmpty();
    var localEnd: u32 = 0;
    for (lengths) |len| {
        localEnd += len;
        set.set(@intCast(localEnd - 1));
    }
    return set.mask;
}

fn expectBlockMap(queue: *const ir.IRQueue, blockIndex: u32, kinds: []const TK) !void {
    try expectEqual(expectedBlockMap(kinds), queue.blocks.block(blockIndex).kinds.mask);
}

fn expectBlockEndMap(queue: *const ir.IRQueue, blockIndex: u32, lengths: []const u32) !void {
    try expectEqual(expectedBlockEndMap(lengths), queue.blocks.block(blockIndex).ends.mask);
}

fn expectInCurrentBlock(blockIter: anytype, index: u32) !void {
    try expect(blockIter.blockIdToLocalId(index) != null);
}

fn expectNotInCurrentBlock(blockIter: anytype, index: u32) !void {
    try expect(blockIter.blockIdToLocalId(index) == null);
}

fn expectBlockRange(blockIter: anytype, kind: TK, start: u32, end: u32) !void {
    const range = blockIter.blockRange(kind);
    try expectEqual(start, range.start);
    try expectEqual(end, range.end);
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
    try expectEqual(0, kindCounts[@intFromEnum(TK.ir_block_map)]);
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
    try expectEqual(0, kindCounts[@intFromEnum(TK.ir_block_map)]);
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

test "IR blocks record emitted kinds and compact kind ends" {
    var kindCounts: [64]u32 = [_]u32{0} ** 64;
    kindCounts[@intFromEnum(TK.lit_number)] = 1;
    kindCounts[@intFromEnum(TK.op_add)] = 1;
    kindCounts[@intFromEnum(TK.ir_enter)] = 1;
    kindCounts[@intFromEnum(TK.ir_exit)] = 1;

    var queue = try ir.IRQueue.init(std.testing.allocator);
    defer queue.deinit(std.testing.allocator);
    try queue.reserve(std.testing.allocator, kindCounts, 4);

    queue.startBlock();
    _ = queue.emitKind(TK.lit_number, irq.args(11, 0));
    _ = queue.emitKind(TK.op_add, irq.args(12, 0));
    _ = queue.endBlock();

    try expectEqual(@as(u32, 1), queue.blocks.blockCount());
    try expectBlockMap(&queue, 0, &[_]TK{ TK.op_add, TK.lit_number, TK.ir_exit, TK.ir_enter });
    try expectBlockEndMap(&queue, 0, &[_]u32{ 1, 1, 1, 1 });
}

test "IR sibling blocks keep their masks separate" {
    var kindCounts: [64]u32 = [_]u32{0} ** 64;
    kindCounts[@intFromEnum(TK.lit_number)] = 1;
    kindCounts[@intFromEnum(TK.op_add)] = 1;
    kindCounts[@intFromEnum(TK.ir_enter)] = 2;
    kindCounts[@intFromEnum(TK.ir_exit)] = 2;

    var queue = try ir.IRQueue.init(std.testing.allocator);
    defer queue.deinit(std.testing.allocator);
    try queue.reserve(std.testing.allocator, kindCounts, 4);

    queue.startBlock();
    _ = queue.emitKind(TK.lit_number, irq.args(1, 0));
    _ = queue.endBlock();

    queue.startBlock();
    _ = queue.emitKind(TK.op_add, irq.args(2, 0));
    _ = queue.endBlock();

    try expectEqual(@as(u32, 2), queue.blocks.blockCount());
    try expectBlockMap(&queue, 0, &[_]TK{ TK.lit_number, TK.ir_exit, TK.ir_enter });
    try expectBlockEndMap(&queue, 0, &[_]u32{ 1, 1, 1 });
    try expectBlockMap(&queue, 1, &[_]TK{ TK.op_add, TK.ir_exit, TK.ir_enter });
    try expectBlockEndMap(&queue, 1, &[_]u32{ 1, 1, 1 });
}

test "IR nested block plus continuation records separate blocks" {
    var kindCounts: [64]u32 = [_]u32{0} ** 64;
    kindCounts[@intFromEnum(TK.lit_number)] = 1;
    kindCounts[@intFromEnum(TK.op_add)] = 1;
    kindCounts[@intFromEnum(TK.ir_use)] = 1;
    kindCounts[@intFromEnum(TK.ir_enter)] = 3;
    kindCounts[@intFromEnum(TK.ir_exit)] = 3;

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

    try expectEqual(@as(u32, 3), queue.blocks.blockCount());
    try expectBlockMap(&queue, 0, &[_]TK{ TK.lit_number, TK.ir_exit, TK.ir_enter });
    try expectBlockEndMap(&queue, 0, &[_]u32{ 1, 1, 1 });
    try expectBlockMap(&queue, 1, &[_]TK{ TK.op_add, TK.ir_exit, TK.ir_enter });
    try expectBlockEndMap(&queue, 1, &[_]u32{ 1, 1, 1 });
    try expectBlockMap(&queue, 2, &[_]TK{ TK.ir_exit, TK.ir_enter, TK.ir_use });
    try expectBlockEndMap(&queue, 2, &[_]u32{ 1, 1, 1 });
}

test "IR block iterator tracks membership by kind" {
    var kindCounts: [64]u32 = [_]u32{0} ** 64;
    kindCounts[@intFromEnum(TK.op_add)] = 3;
    kindCounts[@intFromEnum(TK.lit_number)] = 3;
    kindCounts[@intFromEnum(TK.ir_enter)] = 2;
    kindCounts[@intFromEnum(TK.ir_exit)] = 2;

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

    try expectEqual(@as(u32, 2), queue.blocks.blockCount());
    try expectEqual(@as(u32, 0), queue.kindRanges.reservedLen(@intFromEnum(TK.ir_block_map)));

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
    try expectEqual(@as(?u32, 0), blockIter.blockIdToLocalId(firstAdd));
    try expectEqual(@as(?u32, 1), blockIter.blockIdToLocalId(firstLit));
    try expectEqual(@as(?u32, 2), blockIter.blockIdToLocalId(secondLit));
    try expectEqual(@as(?u32, 3), blockIter.blockIdToLocalId(firstExit));
    try expectEqual(@as(?u32, 4), blockIter.blockIdToLocalId(firstEnter));
    try expectEqual(@as(?u32, null), blockIter.blockIdToLocalId(secondBlockFirstAdd));
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
    try expectEqual(@as(?u32, 0), blockIter.blockIdToLocalId(secondBlockFirstAdd));
    try expectEqual(@as(?u32, 1), blockIter.blockIdToLocalId(lastAdd));
    try expectEqual(@as(?u32, 2), blockIter.blockIdToLocalId(lastLit));
    try expectEqual(@as(?u32, 3), blockIter.blockIdToLocalId(firstExit + 1));
    try expectEqual(@as(?u32, 4), blockIter.blockIdToLocalId(firstEnter + 1));
    try expectEqual(@as(?u32, null), blockIter.blockIdToLocalId(firstAdd));
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

test "IR block iterator reads compact end map at 64 elements" {
    var kindCounts: [64]u32 = [_]u32{0} ** 64;
    kindCounts[@intFromEnum(TK.lit_number)] = 62;
    kindCounts[@intFromEnum(TK.ir_enter)] = 1;
    kindCounts[@intFromEnum(TK.ir_exit)] = 1;

    var queue = try ir.IRQueue.init(std.testing.allocator);
    defer queue.deinit(std.testing.allocator);
    try queue.reserve(std.testing.allocator, kindCounts, 4);

    queue.startBlock();
    const firstLit = queue.emitKind(TK.lit_number, irq.args(1, 0));
    var lastLit = firstLit;
    for (1..62) |i| {
        lastLit = queue.emitKind(TK.lit_number, irq.args(@intCast(i + 1), 0));
    }
    _ = queue.endBlock();
    const firstExit = queue.kindRanges.reservedStart(@intFromEnum(TK.ir_exit));
    const firstEnter = queue.kindRanges.reservedStart(@intFromEnum(TK.ir_enter));

    try expectEqual(@as(u32, 1), queue.blocks.blockCount());
    try expectBlockEndMap(&queue, 0, &[_]u32{ 62, 1, 1 });

    var blockIter = queue.blockIterator();
    blockIter.nextBlock();
    try expectEqual(@as(u32, 64), blockIter.blockLen());
    try expectInCurrentBlock(&blockIter, firstLit);
    try expectInCurrentBlock(&blockIter, lastLit);
    try expectEqual(@as(?u32, 61), blockIter.blockIdToLocalId(lastLit));
    var kind = blockIter.nextKind().?;
    try expectEqual(TK.lit_number, kind);
    try expectBlockRange(&blockIter, kind, firstLit, lastLit + 1);
    kind = blockIter.nextKind().?;
    try expectEqual(TK.ir_exit, kind);
    try expectBlockRange(&blockIter, kind, firstExit, firstExit + 1);
    kind = blockIter.nextKind().?;
    try expectEqual(TK.ir_enter, kind);
    try expectBlockRange(&blockIter, kind, firstEnter, firstEnter + 1);
    try expectEqual(@as(?TK, null), blockIter.nextKind());
    try expect(!blockIter.hasMoreBlocks());
}

test "IR lower maps parsed scope tokens to blocks and continuation" {
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

    try expectEqual(@as(u32, 3), queue.blocks.blockCount());
    try expectEqual(TK.ir_exit, queue.indexToKind(exitIdx));
    try expectBlockMap(&queue, 0, &[_]TK{ TK.lit_number, TK.ir_exit, TK.ir_enter });
    try expectBlockEndMap(&queue, 0, &[_]u32{ 1, 1, 1 });
    try expectBlockMap(&queue, 1, &[_]TK{ TK.lit_number, TK.ir_exit, TK.ir_enter });
    try expectBlockEndMap(&queue, 1, &[_]u32{ 1, 1, 1 });
    try expectBlockMap(&queue, 2, &[_]TK{ TK.ir_exit, TK.ir_enter });
    try expectBlockEndMap(&queue, 2, &[_]u32{ 1, 1 });

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
