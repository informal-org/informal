const std = @import("std");
const irq = @import("irq.zig");
const kind_ranges = @import("irq/kind_ranges.zig");
const tok = @import("token.zig");

const Allocator = std.mem.Allocator;
const IRQueue = irq.IRQueue(irq.Node);
const KIND_COUNT = kind_ranges.KIND_COUNT;
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

    const BlockIds = struct {
        kindOffsets: [KIND_COUNT]u8 = [_]u8{0} ** KIND_COUNT,
        len: u8 = 0,

        // Compute a cumulative sum of elements per kind to find offset base per kind.
        fn init(blockIter: anytype) BlockIds {
            var ids = BlockIds{};
            var nextLocalId: u8 = 0;
            var kindIter = blockIter.currentBlockKindMap().iterator(.{});
            while (kindIter.next()) |kindIndex| {
                ids.kindOffsets[kindIndex] = nextLocalId;
                const range = blockIter.currentBlockRange(kindIndex) orelse unreachable;
                const rangeLen: u8 = @intCast(range.len());
                nextLocalId += rangeLen;
                std.debug.assert(nextLocalId <= 64);
            }
            ids.len = nextLocalId;
            return ids;
        }

        fn localId(self: *const BlockIds, irQ: *const IRQueue, blockIter: anytype, index: u32) u6 {
            const kind = irQ.indexToKind(index);
            const kindIndex = @intFromEnum(kind);
            const relativeIndex = irQ.kindRanges.relativeIndex(kindIndex, index);
            const range = blockIter.currentBlockRange(kindIndex) orelse unreachable;
            const id = self.kindOffsets[kindIndex] + @as(u8, @intCast(relativeIndex - range.start));
            std.debug.assert(id < 64);
            return @intCast(id);
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
        self.depsList.clearRetainingCapacity();
        try self.depsList.ensureTotalCapacity(allocator, totalLen);
        self.depsList.appendNTimesAssumeCapacity(0, totalLen);

        try self.knownInputs.resize(allocator, totalLen, false);
        self.knownInputs.unsetAll();
    }

    pub fn deinit(self: *Self, allocator: Allocator) void {
        self.knownInputs.deinit(allocator);
        self.depsList.deinit(allocator);
    }

    pub fn build(self: *Self, irQ: *const IRQueue) void {
        std.debug.assert(self.depsList.items.len == irQ.list.items.len);
        // @memset(self.depsList.items, 0);
        // self.knownInputs.unsetAll();

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
        const blockIds = BlockIds.init(blockIter);
        var inputStack: [MAX_INPUTS]SavedInput = undefined;
        var inputStackLen: usize = 0;
        var nextInputId: u8 = LAST_INPUT_ID;

        while (blockIter.nextKind()) |kind| {
            while (blockIter.nextElement()) |index| {
                const node = irQ.get(index);
                var nodeDepMap: u64 = 0;
                self.addNodeDependencies(irQ, blockIter, &blockIds, &inputStack, &inputStackLen, &nextInputId, index, kind, node, &nodeDepMap);
                self.depsList.items[index] = nodeDepMap;
            }
        }

        while (inputStackLen > 0) {
            inputStackLen -= 1;
            const saved = inputStack[inputStackLen];
            self.knownInputs.unset(saved.index);
            self.depsList.items[saved.index] = saved.value;
        }
    }

    fn addNodeDependencies(
        self: *Self,
        irQ: *const IRQueue,
        blockIter: anytype,
        blockIds: *const BlockIds,
        inputStack: *[MAX_INPUTS]SavedInput,
        inputStackLen: *usize,
        nextInputId: *u8,
        index: u32,
        kind: TK,
        node: irq.Node,
        nodeDepMap: *u64,
    ) void {
        if (isUnaryOp(kind)) {
            self.addDependency(irQ, blockIter, blockIds, inputStack, inputStackLen, nextInputId, index, node.args.left, nodeDepMap);
            return;
        }

        if (isBinaryOp(kind)) {
            self.addDependency(irQ, blockIter, blockIds, inputStack, inputStackLen, nextInputId, index, node.args.left, nodeDepMap);
            self.addDependency(irQ, blockIter, blockIds, inputStack, inputStackLen, nextInputId, index, node.args.right, nodeDepMap);
            return;
        }

        switch (kind) {
            TK.ir_exit, TK.ir_enter => {
                self.addDependency(irQ, blockIter, blockIds, inputStack, inputStackLen, nextInputId, index, node.args.left, nodeDepMap);
                self.addDependency(irQ, blockIter, blockIds, inputStack, inputStackLen, nextInputId, index, node.args.right, nodeDepMap);
            },
            TK.ir_def, TK.ir_use => {
                self.addDependency(irQ, blockIter, blockIds, inputStack, inputStackLen, nextInputId, index, node.args.left, nodeDepMap);
                self.addDependency(irQ, blockIter, blockIds, inputStack, inputStackLen, nextInputId, index, node.args.right, nodeDepMap);
            },
            TK.ir_frame => {
                if (node.args.right != 0) {
                    self.addDependency(irQ, blockIter, blockIds, inputStack, inputStackLen, nextInputId, index, node.args.left, nodeDepMap);
                }
            },
            TK.ir_arg => {
                self.addDependency(irQ, blockIter, blockIds, inputStack, inputStackLen, nextInputId, index, node.args.left, nodeDepMap);
                self.addDependency(irQ, blockIter, blockIds, inputStack, inputStackLen, nextInputId, index, node.args.right, nodeDepMap);
            },
            TK.ir_param => {
                self.addDependency(irQ, blockIter, blockIds, inputStack, inputStackLen, nextInputId, index, node.args.left, nodeDepMap);
                if (node.args.right != 0) {
                    self.addDependency(irQ, blockIter, blockIds, inputStack, inputStackLen, nextInputId, index, node.args.right, nodeDepMap);
                }
            },
            else => {},
        }
    }

    fn addDependency(
        self: *Self,
        irQ: *const IRQueue,
        blockIter: anytype,
        blockIds: *const BlockIds,
        inputStack: *[MAX_INPUTS]SavedInput,
        inputStackLen: *usize,
        nextInputId: *u8,
        index: u32,
        dependencyIndex: u32,
        nodeDepMap: *u64,
    ) void {
        if (dependencyIndex == index) return;
        std.debug.assert(dependencyIndex < irQ.list.items.len);
        const bitId = if (blockIter.inCurrentBlock(dependencyIndex))
            blockIds.localId(irQ, blockIter, dependencyIndex)
        else
            self.inputId(dependencyIndex, inputStack, inputStackLen, nextInputId);
        nodeDepMap.* |= @as(u64, 1) << bitId;
    }

    fn inputId(
        self: *Self,
        dependencyIndex: u32,
        inputStack: *[MAX_INPUTS]SavedInput,
        inputStackLen: *usize,
        nextInputId: *u8,
    ) u6 {
        if (self.knownInputs.isSet(dependencyIndex)) {
            const id = self.depsList.items[dependencyIndex];
            std.debug.assert(id < 64);
            return @intCast(id);
        }

        std.debug.assert(inputStackLen.* < MAX_INPUTS);
        inputStack[inputStackLen.*] = .{
            .index = dependencyIndex,
            .value = self.depsList.items[dependencyIndex],
        };
        inputStackLen.* += 1;

        const id = nextInputId.*;
        self.knownInputs.set(dependencyIndex);
        self.depsList.items[dependencyIndex] = id;
        nextInputId.* -= 1;
        return @intCast(id);
    }
};

fn isUnaryOp(kind: TK) bool {
    return switch (kind) {
        TK.op_unary_minus,
        TK.op_not,
        => true,
        else => false,
    };
}

fn isBinaryOp(kind: TK) bool {
    return switch (kind) {
        TK.op_gte,
        TK.op_dbl_eq,
        TK.op_lte,
        TK.op_div_eq,
        TK.op_minus_eq,
        TK.op_plus_eq,
        TK.op_mul_eq,
        TK.op_not_eq,
        TK.op_choice,
        TK.op_pow,
        TK.op_gt,
        TK.op_assign_eq,
        TK.op_lt,
        TK.op_colon_assoc,
        TK.op_div,
        TK.op_dot_member,
        TK.op_sub,
        TK.op_add,
        TK.op_mul,
        TK.op_mod,
        TK.op_and,
        TK.op_or,
        TK.op_identifier,
        TK.op_in,
        TK.op_is,
        TK.op_as,
        => true,
        else => false,
    };
}
