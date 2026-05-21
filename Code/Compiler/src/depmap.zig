const std = @import("std");
const irq = @import("irq.zig");
const tok = @import("token.zig");
const bitset = @import("bitset.zig");

const Allocator = std.mem.Allocator;
const IRQueue = irq.IRQueue(irq.Node);
const BlockIterator = @TypeOf(@as(*const IRQueue, undefined).blockIterator());
const TK = tok.Kind;

pub const DepMap = struct {
    const Self = @This();
    const ArrayList = std.array_list.Aligned(u64, null);
    const InputSet = std.bit_set.DynamicBitSetUnmanaged;
    const MAX_INPUTS = 32;
    const LAST_INPUT_ID = 63;

    const SavedInput = packed struct {
        index: u32,
        value: u64,
    };

    const BlockState = struct {
        irQ: *const IRQueue,
        blockIter: *const BlockIterator,
        deps: []u64,
        refs: []u64,
        knownInputs: *InputSet,
        inputStack: [MAX_INPUTS]SavedInput = undefined,
        inputStackLen: u8 = 0,
        nextInputId: u8 = LAST_INPUT_ID,

        fn init(depMap: *Self, irQ: *const IRQueue, blockIter: *const BlockIterator) BlockState {
            return .{
                .irQ = irQ,
                .blockIter = blockIter,
                .deps = depMap.depsList.items,
                .refs = depMap.refsList.items,
                .knownInputs = &depMap.knownInputs,
            };
        }

        fn finish(self: *BlockState) void {
            while (self.inputStackLen > 0) {
                self.inputStackLen -= 1;
                const saved = self.inputStack[self.inputStackLen];
                self.knownInputs.unset(saved.index);
                self.deps[saved.index] = saved.value;
            }
        }

        fn addNodeDependencies(self: *BlockState, index: u32, kind: TK, node: irq.Node) void {
            self.deps[index] = 0;

            if (bitset.isKind(tok.BINARY_OPS, kind)) {
                self.addDependency(index, node.args.left);
                self.addDependency(index, node.args.right);
                return;
            }
            if (bitset.isKind(tok.UNARY_OPS, kind)) {
                self.addDependency(index, node.args.left);
                return;
            }

            switch (kind) {
                TK.ir_exit, TK.ir_enter, TK.ir_def, TK.ir_use, TK.ir_arg => {
                    self.addDependency(index, node.args.left);
                    self.addDependency(index, node.args.right);
                },
                TK.ir_param => {
                    self.addDependency(index, node.args.left);
                    if (node.args.right != 0) self.addDependency(index, node.args.right);
                },
                TK.ir_frame => if (node.args.right != 0) self.addDependency(index, node.args.left),
                else => {},
            }
        }

        fn addDependency(self: *BlockState, index: u32, dependencyIndex: u32) void {
            if (dependencyIndex == index) return;
            std.debug.assert(dependencyIndex < self.irQ.list.items.len);
            const dependencyLocalIndex = self.blockIter.getBlockLocalIndex(dependencyIndex) orelse {
                self.deps[index] |= self.inputBit(dependencyIndex);
                return;
            };
            self.deps[index] |= dependencyBit(dependencyLocalIndex);
            self.refs[dependencyIndex] |= dependencyBit(self.blockIter.getBlockLocalIndex(index) orelse unreachable);
        }

        fn dependencyBit(localIndex: u32) u64 {
            std.debug.assert(localIndex < 64);
            return @as(u64, 1) << @as(u6, @intCast(localIndex));
        }

        fn inputBit(self: *BlockState, dependencyIndex: u32) u64 {
            if (self.knownInputs.isSet(dependencyIndex)) {
                const id = self.deps[dependencyIndex];
                std.debug.assert(id < 64);
                return @as(u64, 1) << @as(u6, @intCast(id));
            }

            std.debug.assert(self.inputStackLen < MAX_INPUTS);
            self.inputStack[self.inputStackLen] = .{
                .index = dependencyIndex,
                .value = self.deps[dependencyIndex],
            };
            self.inputStackLen += 1;

            const id: u6 = @intCast(self.nextInputId);
            self.knownInputs.set(dependencyIndex);
            self.deps[dependencyIndex] = id;
            self.nextInputId -= 1;
            return @as(u64, 1) << id;
        }
    };

    depsList: ArrayList,
    refsList: ArrayList,
    knownInputs: InputSet = .{},

    pub fn init(allocator: Allocator) !Self {
        return Self{
            .depsList = try ArrayList.initCapacity(allocator, 0),
            .refsList = try ArrayList.initCapacity(allocator, 0),
        };
    }

    pub fn reserve(self: *Self, allocator: Allocator, irQ: *const IRQueue) !void {
        const totalLen = irQ.list.items.len;
        try self.depsList.resize(allocator, totalLen);
        @memset(self.depsList.items, 0);
        try self.refsList.resize(allocator, totalLen);
        @memset(self.refsList.items, 0);

        try self.knownInputs.resize(allocator, totalLen, false);
        self.knownInputs.unsetAll();
    }

    pub fn deinit(self: *Self, allocator: Allocator) void {
        self.knownInputs.deinit(allocator);
        self.refsList.deinit(allocator);
        self.depsList.deinit(allocator);
    }

    pub fn build(self: *Self, irQ: *const IRQueue) void {
        std.debug.assert(self.depsList.items.len == irQ.list.items.len);
        std.debug.assert(self.refsList.items.len == irQ.list.items.len);

        var blockIter = irQ.blockIterator();
        while (blockIter.hasMoreBlocks()) {
            blockIter.nextBlock();
            self.buildBlock(irQ, &blockIter);
        }
    }

    pub fn get(self: *const Self, index: u32) u64 {
        std.debug.assert(index < self.depsList.items.len);
        return self.depsList.items[index];
    }

    pub fn refs(self: *const Self, index: u32) u64 {
        std.debug.assert(index < self.refsList.items.len);
        return self.refsList.items[index];
    }

    fn buildBlock(self: *Self, irQ: *const IRQueue, blockIter: anytype) void {
        var blockState = BlockState.init(self, irQ, blockIter);

        while (blockIter.nextKind()) |kind| {
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
