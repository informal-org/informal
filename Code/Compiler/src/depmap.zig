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
    const MAX_INPUTS = 32;
    const LAST_INPUT_ID = 63;

    const BlockState = struct {
        blockIter: *const BlockIterator,
        blockOutputStart: u32,
        deps: []BitSet,
        refs: []BitSet,
        inputIds: []u8,
        inputStack: [MAX_INPUTS]u32 = undefined,
        inputStackLen: u8 = 0,
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

        fn finish(self: *BlockState) void {
            while (self.inputStackLen > 0) {
                self.inputStackLen -= 1;
                const index = self.inputStack[self.inputStackLen];
                self.inputIds[index] = 0;
            }
        }

        fn addNodeDependencies(self: *BlockState, index: u32, kind: TK, node: irq.Node) void {
            const localIndex = self.blockIter.blockIdToLocalId(index) orelse unreachable;
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

        fn addDependency(self: *BlockState, localIndex: u32, dependencyIndex: u32) void {
            std.debug.assert(dependencyIndex < self.inputIds.len);
            const outputSlot = self.blockOutputStart + localIndex;
            const dependencyLocalIndex = self.blockIter.blockIdToLocalId(dependencyIndex) orelse {
                self.deps[outputSlot].setUnion(self.inputBit(dependencyIndex));
                return;
            };
            if (dependencyLocalIndex == localIndex) return;
            self.deps[outputSlot].set(dependencyLocalIndex);
            self.refs[self.blockOutputStart + dependencyLocalIndex].set(localIndex);
        }

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

            std.debug.assert(self.nextInputId >= self.blockIter.blockLen());
            const id: u6 = @intCast(self.nextInputId);
            self.inputIds[dependencyIndex] = id;
            self.nextInputId -= 1;
            var result = BitSet.initEmpty();
            result.set(id);
            return result;
        }
    };

    depsList: MapList,
    refsList: MapList,
    inputIdsList: InputIdList,

    pub fn init(allocator: Allocator) !Self {
        return Self{
            .depsList = try MapList.initCapacity(allocator, 0),
            .refsList = try MapList.initCapacity(allocator, 0),
            .inputIdsList = try InputIdList.initCapacity(allocator, 0),
        };
    }

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

        blockState.finish();
    }
};
