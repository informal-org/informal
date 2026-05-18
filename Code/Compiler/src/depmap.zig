const std = @import("std");
const irq = @import("irq.zig");
const tok = @import("token.zig");
const bitset = @import("bitset.zig");

const Allocator = std.mem.Allocator;
const IRQueue = irq.IRQueue(irq.Node);
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
        deps: []u64,
        knownInputs: *InputSet,
        inputStack: [MAX_INPUTS]SavedInput = undefined,
        inputStackLen: u8 = 0,
        nextInputId: u8 = LAST_INPUT_ID,

        fn init(depMap: *Self, irQ: *const IRQueue) BlockState {
            return .{
                .irQ = irQ,
                .deps = depMap.depsList.items,
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

        fn addNodeDependencies(self: *BlockState, blockIter: anytype, index: u32, kind: TK, node: irq.Node) u64 {
            if (bitset.isKind(tok.BINARY_OPS, kind)) {
                return self.dependencyBit(blockIter, index, node.args.left) |
                    self.dependencyBit(blockIter, index, node.args.right);
            }
            if (bitset.isKind(tok.UNARY_OPS, kind)) {
                return self.dependencyBit(blockIter, index, node.args.left);
            }

            return switch (kind) {
                TK.ir_exit, TK.ir_enter, TK.ir_def, TK.ir_use, TK.ir_arg => self.dependencyBit(blockIter, index, node.args.left) |
                    self.dependencyBit(blockIter, index, node.args.right),
                TK.ir_param => self.dependencyBit(blockIter, index, node.args.left) |
                    if (node.args.right != 0) self.dependencyBit(blockIter, index, node.args.right) else 0,
                TK.ir_frame => if (node.args.right != 0) self.dependencyBit(blockIter, index, node.args.left) else 0,
                else => 0,
            };
        }

        fn dependencyBit(self: *BlockState, blockIter: anytype, index: u32, dependencyIndex: u32) u64 {
            if (dependencyIndex == index) return 0;
            std.debug.assert(dependencyIndex < self.irQ.list.items.len);
            const localIndex = blockIter.getBlockLocalIndex(dependencyIndex) orelse return self.inputBit(dependencyIndex);
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
    knownInputs: InputSet = .{},

    pub fn init(allocator: Allocator) !Self {
        return Self{
            .depsList = try ArrayList.initCapacity(allocator, 0),
        };
    }

    pub fn reserve(self: *Self, allocator: Allocator, irQ: *const IRQueue) !void {
        const totalLen = irQ.list.items.len;
        try self.depsList.resize(allocator, totalLen);
        @memset(self.depsList.items, 0);

        try self.knownInputs.resize(allocator, totalLen, false);
        self.knownInputs.unsetAll();
    }

    pub fn deinit(self: *Self, allocator: Allocator) void {
        self.knownInputs.deinit(allocator);
        self.depsList.deinit(allocator);
    }

    pub fn build(self: *Self, irQ: *const IRQueue) void {
        std.debug.assert(self.depsList.items.len == irQ.list.items.len);

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

    fn buildBlock(self: *Self, irQ: *const IRQueue, blockIter: anytype) void {
        var blockState = BlockState.init(self, irQ);

        while (blockIter.nextKind()) |kind| {
            while (blockIter.nextElement()) |index| {
                const node = irQ.get(index);
                self.depsList.items[index] = blockState.addNodeDependencies(blockIter, index, kind, node);
            }
        }

        blockState.finish();
    }
};
