const std = @import("std");
const bitset = @import("bitset.zig");
const depmap = @import("depmap.zig");
const irq = @import("irq.zig");
const tok = @import("token.zig");

const Allocator = std.mem.Allocator;
const DepMap = depmap.DepMap;
const IRQueue = irq.IRQueue(irq.Node);
const BlockIterator = @TypeOf(@as(*const IRQueue, undefined).blockIterator());
const TK = tok.Kind;
const BitSet = bitset.BitSet64;

pub const Sequence = struct {
    const Self = @This();
    const LayerList = std.array_list.Aligned(BitSet, null);
    const BlockLayerLengthList = std.array_list.Aligned(usize, null);

    layersList: LayerList,
    blockLayerLengths: BlockLayerLengthList,
    depMapOffset: usize = 0,

    pub fn init(allocator: Allocator) !Self {
        return Self{
            .layersList = try LayerList.initCapacity(allocator, 0),
            .blockLayerLengths = try BlockLayerLengthList.initCapacity(allocator, 0),
        };
    }

    pub fn deinit(self: *Self, allocator: Allocator) void {
        self.blockLayerLengths.deinit(allocator);
        self.layersList.deinit(allocator);
    }

    pub fn reserve(self: *Self, allocator: Allocator, irQ: *const IRQueue, maps: *const DepMap) !void {
        self.layersList.clearRetainingCapacity();
        self.blockLayerLengths.clearRetainingCapacity();
        try self.layersList.ensureTotalCapacity(allocator, maps.depsList.items.len);
        try self.blockLayerLengths.ensureTotalCapacity(allocator, irQ.blocks.blockCount());
        self.depMapOffset = 0;
    }

    pub fn build(self: *Self, irQ: *const IRQueue, maps: *const DepMap) void {
        self.layersList.clearRetainingCapacity();
        self.blockLayerLengths.clearRetainingCapacity();
        self.depMapOffset = 0;

        var blockIter = irQ.blockIterator();
        while (blockIter.hasMoreBlocks()) {
            blockIter.nextBlock();
            const layerStart = self.layersList.items.len;
            self.buildBlock(irQ, maps, &blockIter);
            self.blockLayerLengths.appendAssumeCapacity(self.layersList.items.len - layerStart);
            self.depMapOffset += blockIter.blockLen();
        }

        std.debug.assert(self.depMapOffset == maps.depsList.items.len);
    }

    pub fn buildBlock(self: *Self, irQ: *const IRQueue, maps: *const DepMap, blockIter: *const BlockIterator) void {
        const outputLocalIndex = blockOutputLocalIndex(irQ, blockIter) orelse return;
        const blockLen: usize = blockIter.blockLen();
        std.debug.assert(blockLen <= 64);
        const blockDeps = maps.depsList.items[self.depMapOffset..][0..blockLen];
        const blockRefs = maps.refsList.items[self.depMapOffset..][0..blockLen];

        var output = BitSet.initEmpty();
        output.set(outputLocalIndex);

        var needed = output;
        // blockLen low bits are for block refs. Remaining high bits are for inputs external to block.
        var available = bitset.lowBits(blockLen).complement();
        var needsToCheck = output;

        while (needsToCheck.mask != 0) {
            var metNeeds = BitSet.initEmpty();
            var newNeeds = BitSet.initEmpty();

            var check = needsToCheck.iterator(.{});
            while (check.next()) |localIndex| {
                const deps = blockDeps[localIndex];
                const unmet = deps.differenceWith(available);

                if (unmet.mask == 0) {
                    metNeeds.set(localIndex);
                } else {
                    newNeeds.setUnion(unmet);
                }
            }

            std.debug.assert(metNeeds.mask != 0 or newNeeds.mask != 0);
            needed.setUnion(newNeeds);

            if (metNeeds.mask != 0) {
                self.layersList.appendAssumeCapacity(metNeeds);

                var met = metNeeds.iterator(.{});
                while (met.next()) |localIndex| {
                    const refs = blockRefs[localIndex].intersectWith(needed);
                    newNeeds.setUnion(refs);
                }

                available.setUnion(metNeeds);
                needed = needed.differenceWith(metNeeds);
            }

            needsToCheck = newNeeds.intersectWith(needed);
        }
    }
};

fn blockOutputLocalIndex(irQ: *const IRQueue, blockIter: *const BlockIterator) ?u32 {
    const exitRange = blockIter.blockRange(TK.ir_exit);
    std.debug.assert(exitRange.len() == 1);

    const outputIndex = irQ.get(exitRange.start).args.right;
    const outputLocalIndex = blockIter.blockIdToLocalId(outputIndex) orelse return null;
    if (irQ.indexToKind(outputIndex) == TK.ir_enter) return null;
    return outputLocalIndex;
}
