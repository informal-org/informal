const std = @import("std");
const ir = @import("../ir.zig");
const irq = @import("../irq.zig");
const tok = @import("../token.zig");

const TK = tok.Kind;
const expectEqual = std.testing.expectEqual;

test "IR counts include parser counts and exit plumbing" {
    var counts: [64]u32 = [_]u32{0} ** 64;
    counts[@intFromEnum(TK.lit_number)] = 3;
    counts[@intFromEnum(TK.ir_use)] = 2;
    counts[@intFromEnum(TK.ir_def)] = 1;

    const kindCounts = ir.IR.calcKindCounts(counts);

    try expectEqual(3, kindCounts[@intFromEnum(TK.lit_number)]);
    try expectEqual(2, kindCounts[@intFromEnum(TK.ir_use)]);
    try expectEqual(1, kindCounts[@intFromEnum(TK.ir_def)]);
    try expectEqual(1, kindCounts[@intFromEnum(TK.ir_frame)]);
    try expectEqual(1, kindCounts[@intFromEnum(TK.ir_send)]);
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
