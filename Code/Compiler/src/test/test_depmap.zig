const std = @import("std");
const depmap = @import("../depmap.zig");
const ir = @import("../ir.zig");
const irq = @import("../irq.zig");
const tok = @import("../token.zig");

const TK = tok.Kind;
const expectEqual = std.testing.expectEqual;

fn bit(id: u6) u64 {
    return @as(u64, 1) << id;
}

test "DepMap assigns local block IDs by block kind ranges" {
    var kindCounts: [64]u32 = [_]u32{0} ** 64;
    kindCounts[@intFromEnum(TK.op_add)] = 1;
    kindCounts[@intFromEnum(TK.lit_number)] = 2;
    kindCounts[@intFromEnum(TK.ir_block_map)] = 1;

    var queue = try ir.IRQueue.init(std.testing.allocator);
    defer queue.deinit(std.testing.allocator);
    try queue.reserve(std.testing.allocator, kindCounts, 4);

    queue.startBlock();
    const left = queue.emitKind(TK.lit_number, irq.args(11, 0));
    const right = queue.emitKind(TK.lit_number, irq.args(12, 0));
    const add = queue.emitKind(TK.op_add, irq.args(left, right));
    queue.endBlock();

    var maps = try depmap.DepMap.init(std.testing.allocator);
    defer maps.deinit(std.testing.allocator);
    try maps.reserve(std.testing.allocator, &queue);
    maps.build(&queue);

    try expectEqual(bit(1) | bit(2), maps.get(add));
    try expectEqual(@as(u64, 0), maps.get(left));
    try expectEqual(@as(u64, 0), maps.get(right));
}

test "DepMap assigns external inputs from the high bit end" {
    var kindCounts: [64]u32 = [_]u32{0} ** 64;
    kindCounts[@intFromEnum(TK.op_add)] = 1;
    kindCounts[@intFromEnum(TK.lit_number)] = 2;
    kindCounts[@intFromEnum(TK.ir_block_map)] = 2;

    var queue = try ir.IRQueue.init(std.testing.allocator);
    defer queue.deinit(std.testing.allocator);
    try queue.reserve(std.testing.allocator, kindCounts, 4);

    queue.startBlock();
    const input = queue.emitKind(TK.lit_number, irq.args(11, 0));
    queue.endBlock();

    queue.startBlock();
    const local = queue.emitKind(TK.lit_number, irq.args(12, 0));
    const add = queue.emitKind(TK.op_add, irq.args(input, local));
    queue.endBlock();

    var maps = try depmap.DepMap.init(std.testing.allocator);
    defer maps.deinit(std.testing.allocator);
    try maps.reserve(std.testing.allocator, &queue);
    maps.build(&queue);

    try expectEqual(bit(63) | bit(1), maps.get(add));
    try expectEqual(@as(u64, 0), maps.get(input));
}

test "DepMap reuses external input IDs within a block" {
    var kindCounts: [64]u32 = [_]u32{0} ** 64;
    kindCounts[@intFromEnum(TK.op_add)] = 1;
    kindCounts[@intFromEnum(TK.lit_number)] = 1;
    kindCounts[@intFromEnum(TK.ir_block_map)] = 2;

    var queue = try ir.IRQueue.init(std.testing.allocator);
    defer queue.deinit(std.testing.allocator);
    try queue.reserve(std.testing.allocator, kindCounts, 4);

    queue.startBlock();
    const input = queue.emitKind(TK.lit_number, irq.args(11, 0));
    queue.endBlock();

    queue.startBlock();
    const add = queue.emitKind(TK.op_add, irq.args(input, input));
    queue.endBlock();

    var maps = try depmap.DepMap.init(std.testing.allocator);
    defer maps.deinit(std.testing.allocator);
    try maps.reserve(std.testing.allocator, &queue);
    maps.build(&queue);

    try expectEqual(bit(63), maps.get(add));
}

test "DepMap keeps external input IDs block-local" {
    var kindCounts: [64]u32 = [_]u32{0} ** 64;
    kindCounts[@intFromEnum(TK.op_add)] = 2;
    kindCounts[@intFromEnum(TK.lit_number)] = 2;
    kindCounts[@intFromEnum(TK.ir_block_map)] = 2;

    var queue = try ir.IRQueue.init(std.testing.allocator);
    defer queue.deinit(std.testing.allocator);
    try queue.reserve(std.testing.allocator, kindCounts, 4);

    queue.startBlock();
    const left = queue.emitKind(TK.lit_number, irq.args(11, 0));
    const right = queue.emitKind(TK.lit_number, irq.args(12, 0));
    const producer = queue.emitKind(TK.op_add, irq.args(left, right));
    queue.endBlock();

    queue.startBlock();
    const consumer = queue.emitKind(TK.op_add, irq.args(producer, left));
    queue.endBlock();

    var maps = try depmap.DepMap.init(std.testing.allocator);
    defer maps.deinit(std.testing.allocator);
    try maps.reserve(std.testing.allocator, &queue);
    maps.build(&queue);

    try expectEqual(bit(1) | bit(2), maps.get(producer));
    try expectEqual(bit(63) | bit(62), maps.get(consumer));
    try expectEqual(@as(u64, 0), maps.get(left));
    try expectEqual(@as(u64, 0), maps.get(right));
}
