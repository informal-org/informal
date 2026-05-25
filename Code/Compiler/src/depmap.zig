// Dependency map — see Docs/Specs/ir_sequence.md for the full specification.
//
// DepMap records, for every IR node, two 64-bit masks expressed in
// block-local bit positions:
//   - deps[s] — which nodes this one consumes
//   - refs[s] — which in-block nodes consume this one (reverse edges)
// Both arrays are indexed by the slot `blockOutputStart + localIndex` —
// the same offset Sequence walks during scheduling.
//
// Within a block:
//   - In-block nodes occupy the low `blockLen` bits.
//   - External values (referenced from an enclosing block) get synthetic
//     input IDs in the high bits, allocated downward from bit 63. The
//     MAX_INPUTS cap + blockLen ≤ 64 cap keeps local and input bit ranges
//     from colliding.
// `inputIdsList` is scratch keyed by absolute IR index that memoizes the
// per-block external-id assignment so a value referenced twice reuses one
// bit. BlockState.finish() clears just the entries the block touched.

const std = @import("std");
const irq = @import("irq.zig");
const tok = @import("token.zig");
const bitset = @import("bitset.zig");

const Allocator = std.mem.Allocator;
const IRQueue = irq.IRQueue(irq.Node);
const BlockIterator = @TypeOf(@as(*const IRQueue, undefined).blockIterator());
const TK = tok.Kind;
const BitSet = bitset.BitSet64;

pub const DepMap = struct {
    const Self = @This();
    const MapList = std.array_list.Aligned(BitSet, null);
    const InputIdList = std.array_list.Aligned(u8, null);
    // Per-block cap on distinct external inputs. Leaves bits 32..63 for
    // input IDs, low bits 0..31 free for in-block locals (blockLen ≤ 64
    // overall, but inputs alone must not eat into the local range).
    const MAX_INPUTS = 32;
    // External input IDs are allocated downward from bit 63.
    const LAST_INPUT_ID = 63;

    // Per-block working state. Lives only during buildBlock; `finish()`
    // resets `inputIds` entries this block touched so the next block sees
    // a zeroed scratch without an O(N) memset.
    const BlockState = struct {
        blockIter: *const BlockIterator,
        // Offset into deps/refs where this block's run begins.
        blockOutputStart: u32,
        deps: []BitSet,
        refs: []BitSet,
        inputIds: []u8,
        // Absolute IR indices we assigned an input ID to this block.
        // Used by finish() to clear just those entries.
        inputStack: [MAX_INPUTS]u32 = undefined,
        inputStackLen: u8 = 0,
        // Next input bit to hand out (allocates downward toward blockLen).
        nextInputId: u8 = LAST_INPUT_ID,

        fn init(depMap: *Self, blockIter: *const BlockIterator, blockOutputStart: u32) BlockState {
            return .{
                .blockIter = blockIter,
                .blockOutputStart = blockOutputStart,
                .deps = depMap.depsList.items,
                .refs = depMap.refsList.items,
                .inputIds = depMap.inputIdsList.items,
            };
        }

        // Roll back this block's input-id assignments so the next block
        // starts with a clean scratch. Pays O(inputs) instead of O(N).
        fn finish(self: *BlockState) void {
            while (self.inputStackLen > 0) {
                self.inputStackLen -= 1;
                const index = self.inputStack[self.inputStackLen];
                self.inputIds[index] = 0;
            }
        }

        // Decide which of `node`'s args are dataflow deps based on `kind`,
        // and record each one. Kinds with no value inputs (literals etc.)
        // fall through to the `else` and contribute nothing.
        fn addNodeDependencies(self: *BlockState, index: u32, kind: TK, node: irq.Node) void {
            const localIndex = self.blockIter.toBlockRelativeIndex(index) orelse unreachable;
            self.deps[self.blockOutputStart + localIndex] = BitSet.initEmpty();

            if (bitset.isKind(tok.BINARY_OPS, kind)) {
                self.addDependency(localIndex, node.args.left);
                self.addDependency(localIndex, node.args.right);
                return;
            }
            if (bitset.isKind(tok.UNARY_OPS, kind)) {
                self.addDependency(localIndex, node.args.left);
                return;
            }

            switch (kind) {
                TK.ir_exit, TK.ir_enter, TK.ir_def, TK.ir_use, TK.ir_arg => {
                    self.addDependency(localIndex, node.args.left);
                    self.addDependency(localIndex, node.args.right);
                },
                TK.ir_param => {
                    self.addDependency(localIndex, node.args.left);
                    if (node.args.right != 0) self.addDependency(localIndex, node.args.right);
                },
                TK.ir_frame => if (node.args.right != 0) self.addDependency(localIndex, node.args.left),
                else => {},
            }
        }

        // Record one dep edge. Three cases:
        //   - dependency is outside this block → assign/lookup an input bit
        //     in the high range; no reverse-ref entry (producer is elsewhere).
        //   - dependency is the node itself → drop. `ir_enter` uses
        //     args(enterIdx, enterIdx) as a placeholder and relies on this.
        //   - dependency is in-block → set the forward dep bit and the
        //     mirroring ref bit.
        fn addDependency(self: *BlockState, localIndex: u32, dependencyIndex: u32) void {
            std.debug.assert(dependencyIndex < self.inputIds.len);
            const outputSlot = self.blockOutputStart + localIndex;
            const dependencyLocalIndex = self.blockIter.toBlockRelativeIndex(dependencyIndex) orelse {
                self.deps[outputSlot].setUnion(self.inputBit(dependencyIndex));
                return;
            };
            if (dependencyLocalIndex == localIndex) return;
            self.deps[outputSlot].set(dependencyLocalIndex);
            self.refs[self.blockOutputStart + dependencyLocalIndex].set(localIndex);
        }

        // Look up (or allocate) the high-bit input ID for an external
        // value, returned as a single-bit mask ready to union into deps.
        // Repeated uses of the same external value reuse the same bit.
        fn inputBit(self: *BlockState, dependencyIndex: u32) BitSet {
            const existingId = self.inputIds[dependencyIndex];
            if (existingId != 0) {
                std.debug.assert(existingId < 64);
                var result = BitSet.initEmpty();
                result.set(existingId);
                return result;
            }

            std.debug.assert(self.inputStackLen < MAX_INPUTS);
            self.inputStack[self.inputStackLen] = dependencyIndex;
            self.inputStackLen += 1;

            // Input IDs grow downward from bit 63; this assert guarantees
            // they never collide with the low blockLen bits used for locals.
            std.debug.assert(self.nextInputId >= self.blockIter.blockLen());
            const id: u6 = @intCast(self.nextInputId);
            self.inputIds[dependencyIndex] = id;
            self.nextInputId -= 1;
            var result = BitSet.initEmpty();
            result.set(id);
            return result;
        }
    };

    // Forward deps: depsList[s].bit[i] set ⇔ node at slot s consumes the
    // value at local index i (or input id i, if i is in the high range).
    depsList: MapList,
    // Reverse refs: refsList[s].bit[i] set ⇔ node at slot s is consumed by
    // the in-block node at local index i. External consumers are not
    // recorded — refs is intentionally per-block.
    refsList: MapList,
    // Scratch keyed by absolute IR index: per-block external-input ID
    // assignment. Zero means "not yet assigned in the current block."
    inputIdsList: InputIdList,

    pub fn init(allocator: Allocator) !Self {
        return Self{
            .depsList = try MapList.initCapacity(allocator, 0),
            .refsList = try MapList.initCapacity(allocator, 0),
            .inputIdsList = try InputIdList.initCapacity(allocator, 0),
        };
    }

    // Size deps/refs to one slot per IR node (the sum of blockLens across
    // every block) and zero everything. inputIds is keyed by absolute IR
    // index, so it matches irQ.list.items.len.
    pub fn reserve(self: *Self, allocator: Allocator, irQ: *const IRQueue) !void {
        const totalLen = irQ.list.items.len;
        try self.depsList.resize(allocator, totalLen);
        @memset(self.depsList.items, BitSet.initEmpty());
        try self.refsList.resize(allocator, totalLen);
        @memset(self.refsList.items, BitSet.initEmpty());

        try self.inputIdsList.resize(allocator, irQ.list.items.len);
        @memset(self.inputIdsList.items, 0);
    }

    pub fn deinit(self: *Self, allocator: Allocator) void {
        self.inputIdsList.deinit(allocator);
        self.refsList.deinit(allocator);
        self.depsList.deinit(allocator);
    }

    // Walk every block in source order. blockOutputStart advances by
    // blockLen per block; final value must exactly cover depsList — the
    // same invariant Sequence relies on with its depMapOffset.
    pub fn build(self: *Self, irQ: *const IRQueue) void {
        std.debug.assert(self.refsList.items.len == self.depsList.items.len);
        std.debug.assert(self.inputIdsList.items.len == irQ.list.items.len);

        var blockIter = irQ.blockIterator();
        var blockOutputStart: u32 = 0;
        while (blockIter.hasMoreBlocks()) {
            blockIter.nextBlock();
            self.buildBlock(irQ, &blockIter, blockOutputStart);
            blockOutputStart += blockIter.blockLen();
        }
        std.debug.assert(@as(usize, blockOutputStart) == self.depsList.items.len);
    }

    pub fn get(self: *const Self, index: u32) BitSet {
        std.debug.assert(index < self.depsList.items.len);
        return self.depsList.items[index];
    }

    pub fn refs(self: *const Self, index: u32) BitSet {
        std.debug.assert(index < self.refsList.items.len);
        return self.refsList.items[index];
    }

    // Fill deps/refs for one block. Iterating kinds-then-indices visits
    // every node in the block exactly once, in the same kind-major order
    // used everywhere else (so local indices line up).
    fn buildBlock(self: *Self, irQ: *const IRQueue, blockIter: anytype, blockOutputStart: u32) void {
        var blockState = BlockState.init(self, blockIter, blockOutputStart);

        var kindIter = blockIter.kindIterator();
        while (kindIter.next()) |kind| {
            const range = blockIter.blockRange(kind);
            var index = range.start;
            while (index < range.end) : (index += 1) {
                const node = irQ.get(index);
                blockState.addNodeDependencies(index, kind, node);
            }
        }

        // Clear this block's footprint in inputIds before the next block.
        blockState.finish();
    }
};
