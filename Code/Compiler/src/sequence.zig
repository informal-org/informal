// Instruction scheduling — see Docs/Specs/ir_sequence.md for the full
// specification.
//
// Sequence turns each IR block's kind-major layout into a layered schedule.
// A layer is a BitSet64 of block-local indices whose dependencies are all
// already satisfied; the backend may emit nodes within a layer in any
// order. Layers from every block are concatenated into `layersList`, with
// `blockLayerLengths[b]` recording how many layers belong to block b.
//
// The walk is demand-driven from each block's output node (the value
// referenced by the block's ir_exit). External inputs (values produced
// outside the block) live in the high bits of every bitset — they start
// pre-marked available; in-block bits start unavailable and flip as their
// layer is emitted. Anything not reachable from the output is silently
// dropped, so dead code never appears in the schedule.
//
// Reads `DepMap` (deps + refs masks per node) — see depmap.zig.

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

    // Flat stream of layers across every block, concatenated in block order.
    // Each layer's bits are block-local indices — only meaningful relative
    // to the block the layer came from.
    layersList: LayerList,
    // Per-block count of layers contributed to `layersList`. A block that
    // produces no value (e.g. ir_exit forwards an external value) records 0.
    blockLayerLengths: BlockLayerLengthList,
    // Running offset into DepMap.depsList / refsList during build. Advances
    // by blockLen per block; final value must equal depsList.items.len.
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

    // Sized so build() never reallocates: worst case is one layer per node
    // (each layer holds a single bit). That bound is loose but cheap.
    pub fn reserve(self: *Self, allocator: Allocator, irQ: *const IRQueue, maps: *const DepMap) !void {
        self.layersList.clearRetainingCapacity();
        self.blockLayerLengths.clearRetainingCapacity();
        try self.layersList.ensureTotalCapacity(allocator, maps.depsList.items.len);
        try self.blockLayerLengths.ensureTotalCapacity(allocator, irQ.blocks.blockCount());
        self.depMapOffset = 0;
    }

    // Schedule each block independently. depMapOffset walks DepMap in lock
    // step with the block iterator so each block's deps/refs slice starts
    // at the offset and runs for blockLen entries.
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

        // Sum of blockLens across all blocks must exactly cover DepMap.
        std.debug.assert(self.depMapOffset == maps.depsList.items.len);
    }

    // Schedule one block by expanding backward from its output, then
    // emitting nodes in layers as their dependencies become available.
    // See ir_sequence.md for the worked example.
    pub fn buildBlock(self: *Self, irQ: *const IRQueue, maps: *const DepMap, blockIter: *const BlockIterator) void {
        // No live output (empty block, or exit forwards an external value):
        // contribute zero layers but still consume the block's DepMap slice.
        const outputLocalIndex = blockOutputLocalIndex(irQ, blockIter) orelse return;
        const blockLen: usize = blockIter.blockLen();
        std.debug.assert(blockLen <= 64);
        const blockDeps = maps.depsList.items[self.depMapOffset..][0..blockLen];
        const blockRefs = maps.refsList.items[self.depMapOffset..][0..blockLen];

        var output = BitSet.initEmpty();
        output.set(outputLocalIndex);

        // `needed`        — transitive predecessors of the output, still to schedule.
        // `available`     — bits already produced; external inputs start available.
        // `needsToCheck`  — candidates whose dep status to inspect this round.
        var needed = output;
        // Low `blockLen` bits are in-block locals (initially unavailable).
        // High bits are external input IDs assigned by DepMap (pre-available).
        var available = bitset.lowBits(blockLen).complement();
        var needsToCheck = output;

        while (needsToCheck.mask != 0) {
            var metNeeds = BitSet.initEmpty();
            var newNeeds = BitSet.initEmpty();

            // Classify each candidate: deps fully met → schedule this round;
            // otherwise pull its unmet deps into the frontier for next round.
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

            // Progress invariant: every iteration either schedules a layer
            // or expands `needed`. Otherwise the loop wouldn't terminate.
            std.debug.assert(metNeeds.mask != 0 or newNeeds.mask != 0);
            needed.setUnion(newNeeds);

            if (metNeeds.mask != 0) {
                self.layersList.appendAssumeCapacity(metNeeds);

                // Now that these nodes are produced, their parents (refs)
                // may have become schedulable — queue any that are still
                // pending so we re-check them next round.
                var met = metNeeds.iterator(.{});
                while (met.next()) |localIndex| {
                    const refs = blockRefs[localIndex].intersectWith(needed);
                    newNeeds.setUnion(refs);
                }

                available.setUnion(metNeeds);
                needed = needed.differenceWith(metNeeds);
            }

            // Only chase nodes still in `needed` — avoids re-checking
            // already-scheduled nodes or external inputs.
            needsToCheck = newNeeds.intersectWith(needed);
        }
    }
};

// Pick the block-local index of the value the block's ir_exit returns.
// Returns null — i.e. "no live output to schedule from" — when:
//   - the output value lives outside this block (forwarded from an outer
//     block, so the inner block has nothing to compute), or
//   - the output is the block's own ir_enter placeholder (empty block /
//     unit result).
// Every block has exactly one ir_exit by construction.
fn blockOutputLocalIndex(irQ: *const IRQueue, blockIter: *const BlockIterator) ?u32 {
    const exitRange = blockIter.blockRange(TK.ir_exit);
    std.debug.assert(exitRange.len() == 1);

    const outputIndex = irQ.get(exitRange.start).args.right;
    const outputLocalIndex = blockIter.toBlockRelativeIndex(outputIndex) orelse return null;
    if (irQ.indexToKind(outputIndex) == TK.ir_enter) return null;
    return outputLocalIndex;
}
