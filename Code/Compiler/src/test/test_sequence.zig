const std = @import("std");
const bitset = @import("../bitset.zig");
const depmap = @import("../depmap.zig");
const ir = @import("../ir.zig");
const irq = @import("../irq.zig");
const sequence = @import("../sequence.zig");
const tok = @import("../token.zig");

const BitSet = bitset.BitSet64;
const TK = tok.Kind;
const expectEqualSlices = std.testing.expectEqualSlices;

fn bit(index: u6) u64 {
    return @as(u64, 1) << index;
}

fn layer(mask: u64) BitSet {
    return BitSet{ .mask = mask };
}

fn buildMaps(queue: *const ir.IRQueue) !depmap.DepMap {
    var maps = try depmap.DepMap.init(std.testing.allocator);
    errdefer maps.deinit(std.testing.allocator);
    try maps.reserve(std.testing.allocator, queue);
    maps.build(queue);
    return maps;
}

fn buildSequence(queue: *const ir.IRQueue, maps: *const depmap.DepMap) !sequence.Sequence {
    var seq = try sequence.Sequence.init(std.testing.allocator);
    errdefer seq.deinit(std.testing.allocator);
    try seq.reserve(std.testing.allocator, queue, maps);
    seq.build(queue, maps);
    return seq;
}

test "Sequence emits simple expression dependencies before output" {
    var kindCounts: [64]u32 = [_]u32{0} ** 64;
    kindCounts[@intFromEnum(TK.op_add)] = 1;
    kindCounts[@intFromEnum(TK.lit_number)] = 2;
    kindCounts[@intFromEnum(TK.ir_enter)] = 1;
    kindCounts[@intFromEnum(TK.ir_exit)] = 1;

    var queue = try ir.IRQueue.init(std.testing.allocator);
    defer queue.deinit(std.testing.allocator);
    try queue.reserve(std.testing.allocator, kindCounts, 4);

    queue.startBlock();
    const left = queue.emitKind(TK.lit_number, irq.args(1, 0));
    const right = queue.emitKind(TK.lit_number, irq.args(3, 0));
    const add = queue.emitKind(TK.op_add, irq.args(left, right));
    queue.pushArg(add, 0);
    _ = queue.endBlock();

    var maps = try buildMaps(&queue);
    defer maps.deinit(std.testing.allocator);
    var seq = try buildSequence(&queue, &maps);
    defer seq.deinit(std.testing.allocator);

    try expectEqualSlices(usize, &[_]usize{2}, seq.blockLayerLengths.items);
    try expectEqualSlices(BitSet, &[_]BitSet{ layer(bit(1) | bit(2)), layer(bit(0)) }, seq.layersList.items);
}

test "Sequence emits nested expression leaves before inner operations" {
    var kindCounts: [64]u32 = [_]u32{0} ** 64;
    kindCounts[@intFromEnum(TK.op_add)] = 2;
    kindCounts[@intFromEnum(TK.op_mul)] = 1;
    kindCounts[@intFromEnum(TK.lit_number)] = 4;
    kindCounts[@intFromEnum(TK.ir_enter)] = 1;
    kindCounts[@intFromEnum(TK.ir_exit)] = 1;

    var queue = try ir.IRQueue.init(std.testing.allocator);
    defer queue.deinit(std.testing.allocator);
    try queue.reserve(std.testing.allocator, kindCounts, 4);

    queue.startBlock();
    const one = queue.emitKind(TK.lit_number, irq.args(1, 0));
    const two = queue.emitKind(TK.lit_number, irq.args(2, 0));
    const three = queue.emitKind(TK.lit_number, irq.args(3, 0));
    const four = queue.emitKind(TK.lit_number, irq.args(4, 0));
    const left = queue.emitKind(TK.op_add, irq.args(one, two));
    const right = queue.emitKind(TK.op_add, irq.args(three, four));
    const mul = queue.emitKind(TK.op_mul, irq.args(left, right));
    queue.pushArg(mul, 0);
    _ = queue.endBlock();

    var maps = try buildMaps(&queue);
    defer maps.deinit(std.testing.allocator);
    var seq = try buildSequence(&queue, &maps);
    defer seq.deinit(std.testing.allocator);

    try expectEqualSlices(usize, &[_]usize{3}, seq.blockLayerLengths.items);
    try expectEqualSlices(BitSet, &[_]BitSet{
        layer(bit(3) | bit(4) | bit(5) | bit(6)),
        layer(bit(0) | bit(1)),
        layer(bit(2)),
    }, seq.layersList.items);
}

test "Sequence does not re-emit shared direct and indirect dependencies" {
    var kindCounts: [64]u32 = [_]u32{0} ** 64;
    kindCounts[@intFromEnum(TK.op_add)] = 2;
    kindCounts[@intFromEnum(TK.lit_number)] = 2;
    kindCounts[@intFromEnum(TK.ir_enter)] = 1;
    kindCounts[@intFromEnum(TK.ir_exit)] = 1;

    var queue = try ir.IRQueue.init(std.testing.allocator);
    defer queue.deinit(std.testing.allocator);
    try queue.reserve(std.testing.allocator, kindCounts, 4);

    queue.startBlock();
    const shared = queue.emitKind(TK.lit_number, irq.args(1, 0));
    const other = queue.emitKind(TK.lit_number, irq.args(2, 0));
    const inner = queue.emitKind(TK.op_add, irq.args(shared, other));
    const outer = queue.emitKind(TK.op_add, irq.args(inner, shared));
    queue.pushArg(outer, 0);
    _ = queue.endBlock();

    var maps = try buildMaps(&queue);
    defer maps.deinit(std.testing.allocator);
    var seq = try buildSequence(&queue, &maps);
    defer seq.deinit(std.testing.allocator);

    try expectEqualSlices(usize, &[_]usize{4}, seq.blockLayerLengths.items);
    try expectEqualSlices(BitSet, &[_]BitSet{ layer(bit(2)), layer(bit(3)), layer(bit(0)), layer(bit(1)) }, seq.layersList.items);
}

test "Sequence records per-block layer lengths and advances dependency offsets" {
    var kindCounts: [64]u32 = [_]u32{0} ** 64;
    kindCounts[@intFromEnum(TK.op_add)] = 1;
    kindCounts[@intFromEnum(TK.lit_number)] = 2;
    kindCounts[@intFromEnum(TK.ir_enter)] = 2;
    kindCounts[@intFromEnum(TK.ir_exit)] = 2;

    var queue = try ir.IRQueue.init(std.testing.allocator);
    defer queue.deinit(std.testing.allocator);
    try queue.reserve(std.testing.allocator, kindCounts, 4);

    queue.startBlock();
    const input = queue.emitKind(TK.lit_number, irq.args(1, 0));
    queue.pushArg(input, 0);
    _ = queue.endBlock();

    queue.startBlock();
    const local = queue.emitKind(TK.lit_number, irq.args(2, 0));
    const add = queue.emitKind(TK.op_add, irq.args(input, local));
    queue.pushArg(add, 0);
    _ = queue.endBlock();

    var maps = try buildMaps(&queue);
    defer maps.deinit(std.testing.allocator);
    var seq = try buildSequence(&queue, &maps);
    defer seq.deinit(std.testing.allocator);

    try expectEqualSlices(usize, &[_]usize{ 1, 2 }, seq.blockLayerLengths.items);
    try expectEqualSlices(BitSet, &[_]BitSet{ layer(bit(0)), layer(bit(1)), layer(bit(0)) }, seq.layersList.items);
}

test "Sequence records zero layers for external and enter block results" {
    var kindCounts: [64]u32 = [_]u32{0} ** 64;
    kindCounts[@intFromEnum(TK.lit_number)] = 1;
    kindCounts[@intFromEnum(TK.ir_enter)] = 3;
    kindCounts[@intFromEnum(TK.ir_exit)] = 3;

    var queue = try ir.IRQueue.init(std.testing.allocator);
    defer queue.deinit(std.testing.allocator);
    try queue.reserve(std.testing.allocator, kindCounts, 4);

    queue.startBlock();
    const input = queue.emitKind(TK.lit_number, irq.args(1, 0));
    queue.pushArg(input, 0);
    _ = queue.endBlock();

    queue.startBlock();
    queue.pushArg(input, 0);
    _ = queue.endBlock();

    queue.startBlock();
    _ = queue.endBlock();

    var maps = try buildMaps(&queue);
    defer maps.deinit(std.testing.allocator);
    var seq = try buildSequence(&queue, &maps);
    defer seq.deinit(std.testing.allocator);

    try expectEqualSlices(usize, &[_]usize{ 1, 0, 0 }, seq.blockLayerLengths.items);
    try expectEqualSlices(BitSet, &[_]BitSet{layer(bit(0))}, seq.layersList.items);
}
