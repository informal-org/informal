const std = @import("std");
const irq = @import("irq.zig");
const kind_ranges = @import("irq/kind_ranges.zig");
const tok = @import("token.zig");
const bitset = @import("bitset.zig");

const Allocator = std.mem.Allocator;
const IRQueue = irq.IRQueue(irq.Node);
const KIND_COUNT = kind_ranges.KIND_COUNT;
const KindBitSet = kind_ranges.KindBitSet;
const TK = tok.Kind;

pub const DepMap = struct {
    const Self = @This();
    const ArrayList = std.array_list.Aligned(u64, null);
    const MAX_INPUTS = 32;
    const LAST_INPUT_ID = 63;

    const BlockIds = struct {
        kindMap: KindBitSet = KindBitSet.initEmpty(),
        kindLocalBase: [KIND_COUNT]u8 = [_]u8{0} ** KIND_COUNT,
        kindStart: [KIND_COUNT]u32 = [_]u32{0} ** KIND_COUNT,
        kindEnd: [KIND_COUNT]u32 = [_]u32{0} ** KIND_COUNT,

        fn init(irQ: *const IRQueue, blockIter: anytype) BlockIds {
            var ids = BlockIds{};
            var nextLocalId: u8 = 0;
            ids.kindMap = blockIter.currentBlockKindMap();
            var kindIter = ids.kindMap.iterator(.{});
            while (kindIter.next()) |kindIndex| {
                const range = blockIter.currentBlockRange(kindIndex) orelse unreachable;
                const start = irQ.kindRanges.reservedStart(kindIndex) + range.start;
                const rangeLen = range.len();
                const end = start + rangeLen;
                const nextEnd = @as(u32, nextLocalId) + rangeLen;
                std.debug.assert(nextEnd <= 64);

                ids.kindLocalBase[kindIndex] = nextLocalId;
                ids.kindStart[kindIndex] = start;
                ids.kindEnd[kindIndex] = end;
                nextLocalId = @intCast(nextEnd);
            }
            return ids;
        }

        fn localId(self: *const BlockIds, irQ: *const IRQueue, index: u32) ?u6 {
            const kind = irQ.indexToKind(index);
            const kindIndex = @intFromEnum(kind);
            if (!self.kindMap.isSet(kindIndex)) return null;

            const start = self.kindStart[kindIndex];
            if (index < start or index >= self.kindEnd[kindIndex]) return null;

            const id = self.kindLocalBase[kindIndex] + @as(u8, @intCast(index - start));
            std.debug.assert(id < 64);
            return @intCast(id);
        }
    };

    const BlockState = struct {
        irQ: *const IRQueue,
        blockIds: BlockIds,
        inputIndices: [MAX_INPUTS]u32 = undefined,
        inputLen: u8 = 0,

        fn init(irQ: *const IRQueue, blockIter: anytype) BlockState {
            return .{
                .irQ = irQ,
                .blockIds = BlockIds.init(irQ, blockIter),
            };
        }

        fn addNodeDependencies(self: *BlockState, index: u32, kind: TK, node: irq.Node) u64 {
            if (bitset.isKind(tok.BINARY_OPS, kind)) {
                return self.dependencyBit(index, node.args.left) |
                    self.dependencyBit(index, node.args.right);
            }
            if (bitset.isKind(tok.UNARY_OPS, kind)) {
                return self.dependencyBit(index, node.args.left);
            }

            return switch (kind) {
                TK.ir_exit, TK.ir_enter, TK.ir_def, TK.ir_use, TK.ir_arg => self.dependencyBit(index, node.args.left) |
                    self.dependencyBit(index, node.args.right),
                TK.ir_param => self.dependencyBit(index, node.args.left) |
                    if (node.args.right != 0) self.dependencyBit(index, node.args.right) else 0,
                TK.ir_frame => if (node.args.right != 0) self.dependencyBit(index, node.args.left) else 0,
                else => 0,
            };
        }

        fn dependencyBit(self: *BlockState, index: u32, dependencyIndex: u32) u64 {
            if (dependencyIndex == index) return 0;
            std.debug.assert(dependencyIndex < self.irQ.list.items.len);
            const localId = self.blockIds.localId(self.irQ, dependencyIndex) orelse return self.inputBit(dependencyIndex);
            return @as(u64, 1) << localId;
        }

        fn inputBit(self: *BlockState, dependencyIndex: u32) u64 {
            // Linear time - O(inputs).
            for (self.inputIndices[0..self.inputLen], 0..) |inputIndex, inputOffset| {
                if (inputIndex == dependencyIndex) return inputOffsetBit(@intCast(inputOffset));
            }

            std.debug.assert(self.inputLen < MAX_INPUTS);
            const inputOffset = self.inputLen;
            self.inputIndices[inputOffset] = dependencyIndex;
            self.inputLen += 1;
            return inputOffsetBit(inputOffset);
        }

        fn inputOffsetBit(inputOffset: u8) u64 {
            const id: u6 = @intCast(LAST_INPUT_ID - inputOffset);
            return @as(u64, 1) << id;
        }
    };

    depsList: ArrayList,

    pub fn init(allocator: Allocator) !Self {
        return Self{
            .depsList = try ArrayList.initCapacity(allocator, 0),
        };
    }

    pub fn reserve(self: *Self, allocator: Allocator, irQ: *const IRQueue) !void {
        const totalLen = irQ.list.items.len;
        try self.depsList.resize(allocator, totalLen);
        @memset(self.depsList.items, 0);
    }

    pub fn deinit(self: *Self, allocator: Allocator) void {
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
        var blockState = BlockState.init(irQ, blockIter);

        while (blockIter.nextKind()) |kind| {
            while (blockIter.nextElement()) |index| {
                const node = irQ.get(index);
                self.depsList.items[index] = blockState.addNodeDependencies(index, kind, node);
            }
        }
    }
};
