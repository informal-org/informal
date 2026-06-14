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
    inputStart: u8 = 0,
    nextLocalId: u8 = 0,

    pub fn init(allocator: std.mem.Allocator, irq: *IRQueue) !Self {
        const len = irq.tokensByKind.items.len;
        var deps = try std.MultiArrayList(IrNodeRefs).initCapacity(allocator, len);
        for (0..len) |_| {
            const nodeRef = IrNodeRefs{ .deps = BitSet64.initEmpty(), .refs = BitSet64.initEmpty(), .inputBlock = 0, .inputId = 0 };
            deps.appendAssumeCapacity(nodeRef);
        }

        return Self{ .deps = deps, .irq = irq };
    }

    pub fn deinit(self: *Self, allocator: std.mem.Allocator) void {
        self.deps.deinit(allocator);
    }

    pub fn getLocalIndex(self: *Self, blockIndex: u32, index: u24) u8 {
        const elemBlock = self.deps.items(.inputBlock)[index];
        if (elemBlock == blockIndex) {
            // This is already a block-local numbering.
            return self.deps.items(.inputId)[index];
        } else {
            // It's an block-external input we haven't seen before. Assign it the next ID.
            const elemId = self.nextLocalId;
            std.debug.assert(self.nextLocalId < 64);
            self.deps.items(.inputBlock)[index] = blockIndex;
            self.deps.items(.inputId)[index] = elemId;
            self.nextLocalId += 1;
            return elemId;
        }
    }

    fn trackDep(self: *Self, elemIndex: u32, refIndex: u24, elemLocal: u8, refLocal: u8) void {
        self.deps.items(.deps)[elemIndex].set(refLocal);
        if (refLocal < self.inputStart) {
            // It's a local element. Track deps.
            self.deps.items(.refs)[refIndex].set(elemLocal);
        }
    }

    pub fn addDependency(self: *Self, blockIndex: u32, kind: Kind, index: u32) void {
        std.debug.assert(self.deps.items(.inputBlock)[index] == blockIndex);
        const currentId = self.deps.items(.inputId)[index];
        const irNode = self.irq.tokensByKind.items[index];
        switch (kind) {
            .lit_number => {},
            .op_add, .op_mul => {
                const left = irNode.data.irags.left;
                self.trackDep(index, left, currentId, self.getLocalIndex(blockIndex, left));
                const right = irNode.data.irags.right;
                self.trackDep(index, right, currentId, self.getLocalIndex(blockIndex, right));
            },
        }
    }

    fn assignLocalNumbering(self: *Self, blockIter: *BlockIter) void {
        // Iterate once to assign local numbering to all members of this block.
        // I've experimented with computing this on the fly (with end ranges and a cumulative base per kind), but this ends up more simpler and more efficient
        // and trades off space we need to allocate anyway for input ID numbering.
        self.nextLocalId = 0;
        while (blockIter.kindIter.next()) |kind| {
            var kindRange = blockIter.nextRange(kind) orelse unreachable;
            while (kindRange.next()) |i| {
                self.deps.items(.inputBlock)[i] = blockIter.blockIndex;
                self.deps.items(.inputId)[i] = self.nextLocalId;
                self.nextLocalId += 1;
            }
        }
        self.inputStart = self.nextLocalId;
        blockIter.resetIter();
    }

    pub fn build(self: *Self, blocks: *Blocks) void {
        var blockIter = BlockIter.init(blocks);
        while (blockIter.nextBlock()) |_| {
            self.assignLocalNumbering(&blockIter);
            while (blockIter.kindIter.next()) |kind| {
                var kindRange = blockIter.nextRange(kind) orelse unreachable;
                while (kindRange.next()) |i| {
                    self.addDependency(blockIter.blockIndex, kind, i);
                }
            }
        }
    }
};
