const std = @import("std");
const BitSet64 = @import("../bitset.zig").BitSet64;
const blk = @import("blocks.zig");
const Kind = @import("../token.zig").Kind;
const Blocks = blk.Blocks;
const BlockIter = blk.BlockIter(blk.Direction.forward);
const IRQueue = @import("irq.zig").IRQueue;

// Deps and refs for a single IR node.
pub const IrNodeRefs = struct {
    const Self = @This();
    deps: BitSet64, // Inputs to this IR node. What it depends on.
    refs: BitSet64, // Outputs. What it's used by within this block. Cross-block uses are tracked through frames.
    inputBlock: u16 = 0,
    inputId: u8 = 0,
};

pub const DepMap = struct {
    const Self = @This();
    deps: std.MultiArrayList(IrNodeRefs),
    irq: *IRQueue,
    blockIter: *BlockIter,

    pub fn init(allocator: std.mem.Allocator, len: usize) !Self {
        var deps = try std.MultiArrayList(IrNodeRefs).initCapacity(allocator, len);
        for (0..len) |_| {
            const nodeRef = IrNodeRefs{ .deps = BitSet64.initEmpty(), .refs = BitSet64.initEmpty(), .inputBlock = 0, .inputId = 0 };
            deps.appendAssumeCapacity(nodeRef);
        }

        return Self{ .deps = deps };
    }

    pub fn getLocalIndex(self: *Self, blockIter: BlockIter, index: usize) u8 {
        const node = self.irq.tokensByKind.items[index];
        const kind = @intFromEnum(node.kind);
        std.debug.assert(kind < 64);
        const kindStart = self.blockIter.startRanges.kindRanges[kind];
        const kindEnd = self.blockIter.endRanges.kindRanges[kind];
        // If it's within that range, it's within the local block.
        // Else, assign an input index for it.
        // TODO: Need to double-check boundary conditions here. Not sure if this shoudl be <= / >=
        if(index > kindStart & index < kindEnd) {
            // Base offset. Mask kinds by this kind index 1, to see which kind this is.
            // Then the op is nth set bit.
        }
    }

    pub fn addDependency(self: *Self, block: *blk.Block, kind: Kind, index: u32) void {
        const irNode = self.irq.tokensByKind.items[index];
        switch (kind) {
            .lit_number => {},
            .op_add, .op_mul => {
                const left = irNode.data.irags.left;
                const right = irNode.data.irags.right;
            },
        }
    }

    pub fn build(self: *Self, blocks: *Blocks, irq: *IRQueue) void {
        self.irq = irq;
        self.blockIter =
        var blockIter = BlockIter.init(&blocks);
        while (blockIter.nextBlock()) |block| {
            // var nextInputId = 0;
            while (blockIter.kindIter.next()) |kind| {
                const count = blockIter.countIter.next() orelse unreachable;
                std.debug.print("Got block .{} kind .{} count .{}\n", .{ block, kind, count });
            }
        }
    }
};
