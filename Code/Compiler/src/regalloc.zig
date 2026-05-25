const std = @import("std");
const bitset = @import("bitset.zig");
const depmap = @import("depmap.zig");
const irq = @import("irq.zig");
const registerpool = @import("registerpool.zig");
const sequence = @import("sequence.zig");
const tok = @import("token.zig");

const Allocator = std.mem.Allocator;
const BitSet = bitset.BitSet64;
const DepMap = depmap.DepMap;
const IRQueue = irq.IRQueue(irq.Node);
const BlockIterator = @TypeOf(@as(*const IRQueue, undefined).blockIterator());
const RegisterPool = registerpool.RegisterPool;
const Sequence = sequence.Sequence;
const TK = tok.Kind;
const Token = tok.Token;

// Backward linear-scan allocator. Walks each block's Sequence layers in reverse,
// so a node is first seen at its last use (where we allocate) and last seen at its
// definition (where we free). Tokens are pushed in reverse program order; popToken
// then yields them forward for codegen. See Docs/Specs/regalloc.md.

pub const MAX_REGISTERS = registerpool.MAX_REGISTERS;
// u16 location encoding: [0, MAX_REGISTERS) = register, [SPILL_BASE, FIRST_SENTINEL)
// = spill slot, top three values = sentinels. Disjoint ranges keep isRegister/isSpill
// as simple range checks.
pub const UNASSIGNED_LOCATION = std.math.maxInt(u16);
pub const FREED_LOCATION = UNASSIGNED_LOCATION - 1;
pub const NO_LOCATION = UNASSIGNED_LOCATION - 2;
pub const SPILL_BASE = @as(u16, 1) << 15;
const FIRST_SENTINEL = NO_LOCATION;

pub const RegAlloc = struct {
    const Self = @This();
    const TokenList = std.array_list.Aligned(Token, null);
    const LocationList = std.array_list.Aligned(u16, null);

    allocator: Allocator,
    register_pool: RegisterPool,
    token_stack: TokenList,
    locations: LocationList,
    next_spill_slot: u16 = 0,

    pub fn init(allocator: Allocator, free_registers: BitSet) !Self {
        return .{
            .allocator = allocator,
            .register_pool = try RegisterPool.init(free_registers),
            .token_stack = try TokenList.initCapacity(allocator, 0),
            .locations = try LocationList.initCapacity(allocator, 0),
        };
    }

    pub fn deinit(self: *Self) void {
        self.locations.deinit(self.allocator);
        self.token_stack.deinit(self.allocator);
    }

    pub fn reserve(self: *Self, irQ: *const IRQueue, maps: *const DepMap, seq: *const Sequence) !void {
        _ = maps;
        try self.token_stack.ensureTotalCapacity(self.allocator, irQ.list.items.len + seq.layersList.items.len);
        try self.locations.resize(self.allocator, irQ.list.items.len);
    }

    pub fn popToken(self: *Self) ?Token {
        return self.token_stack.pop();
    }

    pub fn tokenCount(self: *const Self) usize {
        return self.token_stack.items.len;
    }

    pub fn spillSlotCount(self: *const Self) u16 {
        return self.next_spill_slot;
    }

    pub fn build(self: *Self, irQ: *const IRQueue, maps: *const DepMap, seq: *const Sequence) !void {
        _ = maps;
        self.reset();

        var layer_start: usize = 0;
        var block_iter = irQ.blockIterator();
        var block_index: usize = 0;
        while (block_iter.hasMoreBlocks()) : (block_index += 1) {
            block_iter.nextBlock();
            const layer_count = seq.blockLayerLengths.items[block_index];
            const layers = seq.layersList.items[layer_start..][0..layer_count];
            try self.buildBlock(irQ, &block_iter, layers);
            layer_start += layer_count;
        }

        std.debug.assert(layer_start == seq.layersList.items.len);
    }

    fn buildBlock(self: *Self, irQ: *const IRQueue, block_iter: *const BlockIterator, layers: []const BitSet) !void {
        // Layers walked last-to-first (backward). Within a layer the order is free
        // since members are mutually independent; @clz pops high bit first.
        var layer_index = layers.len;
        while (layer_index > 0) {
            layer_index -= 1;
            var layer_mask = layers[layer_index].mask;
            while (layer_mask != 0) {
                const local_index: u6 = @intCast(63 - @clz(layer_mask));
                layer_mask &= ~(@as(u64, 1) << local_index);
                try self.processElement(irQ, block_iter.toAbsoluteIndex(local_index));
            }
        }
    }

    fn processElement(self: *Self, irQ: *const IRQueue, index: u32) !void {
        const kind = irQ.indexToKind(index);
        const node = irQ.get(index);
        // Finalize the result first so its register is free when we allocate operands
        // — lets a binary op reuse the result reg as an input without an extra spill.
        const result = try self.declareResult(index);
        if (bitset.isKind(tok.LITERALS, kind)) {
            try self.pushToken(Token.regLiteral(kind, node.args.left, result));
            return;
        }

        const operands = try self.operandsFor(irQ, kind, node);

        try self.pushToken(Token.regAlloc(kind, operands[0], operands[1], result));
    }

    fn reset(self: *Self) void {
        self.token_stack.clearRetainingCapacity();
        @memset(self.locations.items, UNASSIGNED_LOCATION);
        self.register_pool.reset();
        self.next_spill_slot = 0;
    }

    fn declareResult(self: *Self, index: u32) !u16 {
        // The slot tells us what later-program-order consumers (visited earlier in
        // this backward walk) already chose for this value.
        const current_location = self.location(index);
        if (isRegister(current_location)) {
            // A consumer pinned it to this register — the producer writes there.
            const reg: u8 = @intCast(current_location);
            self.register_pool.free(reg);
            self.setLocation(index, FREED_LOCATION);
            return current_location;
        }

        if (isSpill(current_location)) {
            // Consumers reload from this spill slot; allocate a reg, write, then store
            // so the spill is materialized right after the producer in forward order.
            const spill_location = current_location;
            const reg = try self.allocateRegisterFor(index);
            try self.emitStore(reg, spill_location);
            self.register_pool.free(reg);
            self.setLocation(index, FREED_LOCATION);
            return registerLocation(reg);
        }

        std.debug.assert(current_location == UNASSIGNED_LOCATION);
        // Reached only for live-output nodes whose value the block didn't otherwise need.
        const reg = try self.allocateRegisterFor(index);
        self.register_pool.free(reg);
        self.setLocation(index, FREED_LOCATION);
        return registerLocation(reg);
    }

    fn operandsFor(self: *Self, irQ: *const IRQueue, kind: TK, node: irq.Node) ![2]u16 {
        _ = irQ;
        if (bitset.isKind(tok.BINARY_OPS, kind)) {
            return .{
                try self.useDependency(node.args.left),
                try self.useDependency(node.args.right),
            };
        }

        if (bitset.isKind(tok.UNARY_OPS, kind)) {
            return .{
                try self.useDependency(node.args.left),
                NO_LOCATION,
            };
        }

        return .{ NO_LOCATION, NO_LOCATION };
    }

    fn useDependency(self: *Self, index: u32) !u16 {
        const current_location = self.location(index);
        if (isRegister(current_location)) {
            // Another later-program-order consumer already pinned the dep. Touch the
            // LRU so an upcoming allocation in this same op doesn't evict it.
            self.register_pool.touch(@intCast(current_location));
            return current_location;
        }

        if (isSpill(current_location)) {
            // Dep was previously evicted; allocate a reg here and store to the spill
            // slot so other consumers reloading from it see the same value.
            const spill_location = current_location;
            const reg = try self.allocateRegisterFor(index);
            try self.emitStore(reg, spill_location);
            return registerLocation(reg);
        }

        std.debug.assert(current_location == UNASSIGNED_LOCATION);
        // First (= latest-in-program-order) consumer of this dep; this register becomes
        // its home until the producer is reached and frees it in declareResult.
        return registerLocation(try self.allocateRegisterFor(index));
    }

    fn allocateRegisterFor(self: *Self, index: u32) !u8 {
        const allocation = try self.register_pool.allocate(index);
        if (allocation.evicted) |evicted_index| {
            // The pool picked an occupant to evict. Assign it a spill slot and emit
            // a load so that, in forward order, the evicted value is restored before
            // its (later-in-program) consumer runs.
            const spill_location = try self.nextSpillLocation();
            self.setLocation(evicted_index, spill_location);
            try self.emitLoad(allocation.register, spill_location);
        }
        self.setLocation(index, registerLocation(allocation.register));
        return allocation.register;
    }

    fn nextSpillLocation(self: *Self) !u16 {
        if (self.next_spill_slot >= FIRST_SENTINEL - SPILL_BASE) return error.TooManySpills;
        const spill_location = SPILL_BASE + self.next_spill_slot;
        self.next_spill_slot += 1;
        return spill_location;
    }

    fn location(self: *const Self, index: u32) u16 {
        return self.locations.items[index];
    }

    fn setLocation(self: *Self, index: u32, new_location: u16) void {
        self.locations.items[index] = new_location;
    }

    fn pushToken(self: *Self, token: Token) !void {
        try self.token_stack.append(self.allocator, token);
    }

    fn emitLoad(self: *Self, reg: u8, spill_location: u16) !void {
        try self.pushToken(Token.regAlloc(TK.op_load, registerLocation(reg), spill_location, NO_LOCATION));
    }

    fn emitStore(self: *Self, reg: u8, spill_location: u16) !void {
        try self.pushToken(Token.regAlloc(TK.op_store, spill_location, registerLocation(reg), NO_LOCATION));
    }
};

pub fn registerLocation(reg: u8) u16 {
    std.debug.assert(reg < MAX_REGISTERS);
    return @intCast(reg);
}

pub fn isRegister(location: u16) bool {
    return location < MAX_REGISTERS;
}

pub fn isSpill(location: u16) bool {
    return location >= SPILL_BASE and location < FIRST_SENTINEL;
}

pub fn spillSlot(location: u16) u16 {
    std.debug.assert(isSpill(location));
    return location - SPILL_BASE;
}
