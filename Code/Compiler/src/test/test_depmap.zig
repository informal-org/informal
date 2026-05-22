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

test "DepMap emits entries in block-local order" {
    var kindCounts: [64]u32 = [_]u32{0} ** 64;
    kindCounts[@intFromEnum(TK.op_add)] = 1;
    kindCounts[@intFromEnum(TK.lit_number)] = 2;
    kindCounts[@intFromEnum(TK.ir_enter)] = 1;
    kindCounts[@intFromEnum(TK.ir_exit)] = 1;
    kindCounts[@intFromEnum(TK.ir_block_map)] = 1;

    var queue = try ir.IRQueue.init(std.testing.allocator);
    defer queue.deinit(std.testing.allocator);
    try queue.reserve(std.testing.allocator, kindCounts, 4);

    queue.startBlock();
    const left = queue.emitKind(TK.lit_number, irq.args(11, 0));
    const right = queue.emitKind(TK.lit_number, irq.args(12, 0));
    const add = queue.emitKind(TK.op_add, irq.args(left, right));
    _ = queue.endBlock();

    var maps = try depmap.DepMap.init(std.testing.allocator);
    defer maps.deinit(std.testing.allocator);
    try maps.reserve(std.testing.allocator, &queue);
    maps.build(&queue);

    _ = add;

    try expectEqual(@as(usize, 5), maps.depsList.items.len);
    try expectEqual(bit(1) | bit(2), maps.get(0));
    try expectEqual(@as(u64, 0), maps.get(1));
    try expectEqual(@as(u64, 0), maps.get(2));
    try expectEqual(bit(4), maps.get(3));
    try expectEqual(@as(u64, 0), maps.get(4));
    try expectEqual(@as(u64, 0), maps.refs(0));
    try expectEqual(bit(0), maps.refs(1));
    try expectEqual(bit(0), maps.refs(2));
    try expectEqual(@as(u64, 0), maps.refs(3));
    try expectEqual(bit(3), maps.refs(4));
}

test "DepMap assigns external inputs from the high bit end" {
    var kindCounts: [64]u32 = [_]u32{0} ** 64;
    kindCounts[@intFromEnum(TK.op_add)] = 1;
    kindCounts[@intFromEnum(TK.lit_number)] = 2;
    kindCounts[@intFromEnum(TK.ir_enter)] = 2;
    kindCounts[@intFromEnum(TK.ir_exit)] = 2;
    kindCounts[@intFromEnum(TK.ir_block_map)] = 2;

    var queue = try ir.IRQueue.init(std.testing.allocator);
    defer queue.deinit(std.testing.allocator);
    try queue.reserve(std.testing.allocator, kindCounts, 4);

    queue.startBlock();
    const input = queue.emitKind(TK.lit_number, irq.args(11, 0));
    _ = queue.endBlock();

    queue.startBlock();
    const local = queue.emitKind(TK.lit_number, irq.args(12, 0));
    const add = queue.emitKind(TK.op_add, irq.args(input, local));
    _ = queue.endBlock();

    var maps = try depmap.DepMap.init(std.testing.allocator);
    defer maps.deinit(std.testing.allocator);
    try maps.reserve(std.testing.allocator, &queue);
    maps.build(&queue);

    _ = add;

    try expectEqual(@as(usize, 7), maps.depsList.items.len);
    try expectEqual(@as(u64, 0), maps.get(0));
    try expectEqual(bit(2), maps.get(1));
    try expectEqual(@as(u64, 0), maps.get(2));
    try expectEqual(bit(63) | bit(1), maps.get(3));
    try expectEqual(@as(u64, 0), maps.get(4));
    try expectEqual(bit(3), maps.get(5));
    try expectEqual(@as(u64, 0), maps.get(6));
    try expectEqual(@as(u64, 0), maps.refs(0));
    try expectEqual(@as(u64, 0), maps.refs(1));
    try expectEqual(bit(1), maps.refs(2));
    try expectEqual(@as(u64, 0), maps.refs(3));
    try expectEqual(bit(0), maps.refs(4));
    try expectEqual(@as(u64, 0), maps.refs(5));
    try expectEqual(bit(2), maps.refs(6));
}

test "DepMap reuses external input IDs within a block" {
    var kindCounts: [64]u32 = [_]u32{0} ** 64;
    kindCounts[@intFromEnum(TK.op_add)] = 1;
    kindCounts[@intFromEnum(TK.lit_number)] = 1;
    kindCounts[@intFromEnum(TK.ir_enter)] = 2;
    kindCounts[@intFromEnum(TK.ir_exit)] = 2;
    kindCounts[@intFromEnum(TK.ir_block_map)] = 2;

    var queue = try ir.IRQueue.init(std.testing.allocator);
    defer queue.deinit(std.testing.allocator);
    try queue.reserve(std.testing.allocator, kindCounts, 4);

    queue.startBlock();
    const input = queue.emitKind(TK.lit_number, irq.args(11, 0));
    _ = queue.endBlock();

    queue.startBlock();
    const add = queue.emitKind(TK.op_add, irq.args(input, input));
    _ = queue.endBlock();

    var maps = try depmap.DepMap.init(std.testing.allocator);
    defer maps.deinit(std.testing.allocator);
    try maps.reserve(std.testing.allocator, &queue);
    maps.build(&queue);

    _ = add;

    try expectEqual(@as(usize, 6), maps.depsList.items.len);
    try expectEqual(@as(u64, 0), maps.get(0));
    try expectEqual(bit(2), maps.get(1));
    try expectEqual(@as(u64, 0), maps.get(2));
    try expectEqual(bit(63), maps.get(3));
    try expectEqual(bit(2), maps.get(4));
    try expectEqual(@as(u64, 0), maps.get(5));
    try expectEqual(@as(u64, 0), maps.refs(0));
    try expectEqual(@as(u64, 0), maps.refs(1));
    try expectEqual(bit(1), maps.refs(2));
    try expectEqual(@as(u64, 0), maps.refs(3));
    try expectEqual(@as(u64, 0), maps.refs(4));
    try expectEqual(bit(1), maps.refs(5));
}

test "DepMap keeps external input IDs block-local" {
    var kindCounts: [64]u32 = [_]u32{0} ** 64;
    kindCounts[@intFromEnum(TK.op_add)] = 2;
    kindCounts[@intFromEnum(TK.lit_number)] = 2;
    kindCounts[@intFromEnum(TK.ir_enter)] = 2;
    kindCounts[@intFromEnum(TK.ir_exit)] = 2;
    kindCounts[@intFromEnum(TK.ir_block_map)] = 2;

    var queue = try ir.IRQueue.init(std.testing.allocator);
    defer queue.deinit(std.testing.allocator);
    try queue.reserve(std.testing.allocator, kindCounts, 4);

    queue.startBlock();
    const left = queue.emitKind(TK.lit_number, irq.args(11, 0));
    const right = queue.emitKind(TK.lit_number, irq.args(12, 0));
    const producer = queue.emitKind(TK.op_add, irq.args(left, right));
    _ = queue.endBlock();

    queue.startBlock();
    const consumer = queue.emitKind(TK.op_add, irq.args(producer, left));
    _ = queue.endBlock();

    var maps = try depmap.DepMap.init(std.testing.allocator);
    defer maps.deinit(std.testing.allocator);
    try maps.reserve(std.testing.allocator, &queue);
    maps.build(&queue);

    _ = consumer;

    try expectEqual(@as(usize, 8), maps.depsList.items.len);
    try expectEqual(bit(1) | bit(2), maps.get(0));
    try expectEqual(@as(u64, 0), maps.get(1));
    try expectEqual(@as(u64, 0), maps.get(2));
    try expectEqual(bit(4), maps.get(3));
    try expectEqual(@as(u64, 0), maps.get(4));
    try expectEqual(bit(63) | bit(62), maps.get(5));
    try expectEqual(bit(2), maps.get(6));
    try expectEqual(@as(u64, 0), maps.get(7));
    try expectEqual(@as(u64, 0), maps.refs(0));
    try expectEqual(bit(0), maps.refs(1));
    try expectEqual(bit(0), maps.refs(2));
    try expectEqual(@as(u64, 0), maps.refs(3));
    try expectEqual(bit(3), maps.refs(4));
    try expectEqual(@as(u64, 0), maps.refs(5));
    try expectEqual(@as(u64, 0), maps.refs(6));
    try expectEqual(bit(1), maps.refs(7));
}
