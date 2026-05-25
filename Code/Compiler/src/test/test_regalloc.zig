const std = @import("std");
const bitset = @import("../bitset.zig");
const depmap = @import("../depmap.zig");
const ir = @import("../ir.zig");
const irq = @import("../irq.zig");
const regalloc = @import("../regalloc.zig");
const sequence = @import("../sequence.zig");
const tok = @import("../token.zig");

const TK = tok.Kind;
const expect = std.testing.expect;
const expectEqual = std.testing.expectEqual;

const Pipeline = struct {
    maps: depmap.DepMap,
    seq: sequence.Sequence,
    regs: regalloc.RegAlloc,

    fn deinit(self: *Pipeline) void {
        self.regs.deinit();
        self.seq.deinit(std.testing.allocator);
        self.maps.deinit(std.testing.allocator);
    }
};

fn buildPipeline(queue: *const ir.IRQueue, free_registers: bitset.BitSet64) !Pipeline {
    var maps = try depmap.DepMap.init(std.testing.allocator);
    errdefer maps.deinit(std.testing.allocator);
    try maps.reserve(std.testing.allocator, queue);
    maps.build(queue);

    var seq = try sequence.Sequence.init(std.testing.allocator);
    errdefer seq.deinit(std.testing.allocator);
    try seq.reserve(std.testing.allocator, queue, &maps);
    seq.build(queue, &maps);

    var regs = try regalloc.RegAlloc.init(std.testing.allocator, free_registers);
    errdefer regs.deinit();
    try regs.reserve(queue, &maps, &seq);
    try regs.build(queue, &maps, &seq);

    return .{ .maps = maps, .seq = seq, .regs = regs };
}

fn popToken(regs: *regalloc.RegAlloc) tok.Token {
    return regs.popToken() orelse unreachable;
}

test "RegAlloc assigns registers walking sequence layers backwards" {
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
    const right = queue.emitKind(TK.lit_number, irq.args(2, 0));
    const add = queue.emitKind(TK.op_add, irq.args(left, right));
    queue.pushArg(add, 0);
    _ = queue.endBlock();

    var pipeline = try buildPipeline(&queue, bitset.lowBits(2));
    defer pipeline.deinit();

    try expectEqual(@as(usize, 3), pipeline.regs.tokenCount());

    const first = popToken(&pipeline.regs);
    try expectEqual(TK.lit_number, first.kind);
    try expectEqual(@as(u32, 1), first.data.reg_literal.value_ref);
    try expectEqual(regalloc.registerLocation(0), first.data.reg_literal.result);

    const second = popToken(&pipeline.regs);
    try expectEqual(TK.lit_number, second.kind);
    try expectEqual(@as(u32, 2), second.data.reg_literal.value_ref);
    try expectEqual(regalloc.registerLocation(1), second.data.reg_literal.result);

    const add_token = popToken(&pipeline.regs);
    try expectEqual(TK.op_add, add_token.kind);
    try expectEqual(regalloc.registerLocation(0), add_token.data.regalloc.left);
    try expectEqual(regalloc.registerLocation(1), add_token.data.regalloc.right);
    try expectEqual(regalloc.registerLocation(0), add_token.data.regalloc.result);

    try expect(pipeline.regs.popToken() == null);
}

test "RegAlloc emits spill load and store tokens with LRU register reuse" {
    var kindCounts: [64]u32 = [_]u32{0} ** 64;
    kindCounts[@intFromEnum(TK.op_add)] = 3;
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
    const output = queue.emitKind(TK.op_add, irq.args(left, right));
    queue.pushArg(output, 0);
    _ = queue.endBlock();

    var pipeline = try buildPipeline(&queue, bitset.lowBits(2));
    defer pipeline.deinit();

    var stored_slots = std.bit_set.IntegerBitSet(64).initEmpty();
    var saw_load_after_store = false;
    while (pipeline.regs.popToken()) |token| {
        switch (token.kind) {
            TK.op_store => {
                try expect(regalloc.isSpill(token.data.regalloc.left));
                try expectEqual(regalloc.NO_LOCATION, token.data.regalloc.result);
                stored_slots.set(@intCast(regalloc.spillSlot(token.data.regalloc.left)));
            },
            TK.op_load => {
                try expect(regalloc.isSpill(token.data.regalloc.right));
                try expectEqual(regalloc.NO_LOCATION, token.data.regalloc.result);
                const slot: usize = @intCast(regalloc.spillSlot(token.data.regalloc.right));
                if (stored_slots.isSet(slot)) saw_load_after_store = true;
            },
            else => {},
        }
    }

    try expect(saw_load_after_store);
}
