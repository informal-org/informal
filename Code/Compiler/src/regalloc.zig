const std = @import("std");
const bitset = @import("bitset.zig");
const depmap = @import("depmap.zig");
const irq = @import("irq.zig");
const lru = @import("lru.zig");
const sequence = @import("sequence.zig");
const tok = @import("token.zig");

const Allocator = std.mem.Allocator;
const BitSet = bitset.BitSet64;
const DepMap = depmap.DepMap;
const IRQueue = irq.IRQueue(irq.Node);
const BlockIterator = @TypeOf(@as(*const IRQueue, undefined).blockIterator());
const Sequence = sequence.Sequence;
const TK = tok.Kind;
const Token = tok.Token;

pub const MAX_REGISTERS = 64;
pub const UNASSIGNED_LOCATION = std.math.maxInt(u24);
pub const FREED_LOCATION = UNASSIGNED_LOCATION - 1;
pub const NO_LOCATION = UNASSIGNED_LOCATION - 2;
pub const SPILL_BASE = @as(u24, 1) << 23;
const FIRST_SENTINEL = NO_LOCATION;
const NO_NODE = std.math.maxInt(u32);

const RecentRegisters = lru.Lru(MAX_REGISTERS);

pub const RegAlloc = struct {
    const Self = @This();
    const TokenList = std.array_list.Aligned(Token, null);
    const LocationList = std.array_list.Aligned(u24, null);

    allocator: Allocator,
    register_count: u8,
    token_stack: TokenList,
    locations: LocationList,
    free_registers: BitSet = BitSet.initEmpty(),
    recent_registers: RecentRegisters = .{},
    register_values: [MAX_REGISTERS]u32 = [_]u32{NO_NODE} ** MAX_REGISTERS,
    next_spill_slot: u24 = 0,

    pub fn init(allocator: Allocator, register_count: u8) !Self {
        if (register_count == 0 or register_count > MAX_REGISTERS) return error.InvalidRegisterCount;
        return .{
            .allocator = allocator,
            .register_count = register_count,
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
        const output = try self.declareResult(index);
        const operands = try self.operandsFor(irQ, kind, node, output);

        try self.pushToken(Token.regAlloc(kind, operands[0], operands[1]));
    }

    fn reset(self: *Self) void {
        self.token_stack.clearRetainingCapacity();
        @memset(self.locations.items, UNASSIGNED_LOCATION);
        self.free_registers = bitset.lowBits(self.register_count);
        self.recent_registers = .{};
        self.register_values = [_]u32{NO_NODE} ** MAX_REGISTERS;
        self.next_spill_slot = 0;
    }

    fn declareResult(self: *Self, index: u32) !u24 {
        const current_location = self.location(index);
        if (isRegister(current_location, self.register_count)) {
            const reg: u8 = @intCast(current_location);
            self.freeRegister(reg);
            self.setLocation(index, FREED_LOCATION);
            return current_location;
        }

        if (isSpill(current_location)) {
            const spill_location = current_location;
            const reg = try self.allocateRegisterFor(index);
            try self.emitStore(reg, spill_location);
            self.freeRegister(reg);
            self.setLocation(index, FREED_LOCATION);
            return registerLocation(reg);
        }

        std.debug.assert(current_location == UNASSIGNED_LOCATION);
        const reg = try self.allocateRegisterFor(index);
        self.freeRegister(reg);
        self.setLocation(index, FREED_LOCATION);
        return registerLocation(reg);
    }

    fn operandsFor(self: *Self, irQ: *const IRQueue, kind: TK, node: irq.Node, output: u24) ![2]u24 {
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

        return .{ output, NO_LOCATION };
    }

    fn useDependency(self: *Self, index: u32) !u24 {
        const current_location = self.location(index);
        if (isRegister(current_location, self.register_count)) {
            self.recent_registers.set(@intCast(current_location));
            return current_location;
        }

        if (isSpill(current_location)) {
            const spill_location = current_location;
            const reg = try self.allocateRegisterFor(index);
            try self.emitStore(reg, spill_location);
            return registerLocation(reg);
        }

        std.debug.assert(current_location == UNASSIGNED_LOCATION);
        return registerLocation(try self.allocateRegisterFor(index));
    }

    fn allocateRegisterFor(self: *Self, index: u32) !u8 {
        if (self.free_registers.findFirstSet()) |free_register| {
            return self.assignRegister(index, @intCast(free_register));
        }

        const spilled_register = try self.spillLruRegister();
        self.free_registers.set(spilled_register);
        return self.assignRegister(index, spilled_register);
    }

    fn assignRegister(self: *Self, index: u32, reg: u8) u8 {
        std.debug.assert(reg < self.register_count);
        std.debug.assert(self.free_registers.isSet(reg));
        self.free_registers.unset(reg);
        self.setLocation(index, registerLocation(reg));
        self.register_values[reg] = index;
        self.recent_registers.set(reg);
        return reg;
    }

    fn spillLruRegister(self: *Self) !u8 {
        const reg = self.recent_registers.popLru() orelse return error.NoRegisterToSpill;
        const index = self.register_values[reg];
        std.debug.assert(index != NO_NODE);

        const spill_location = try self.nextSpillLocation();
        self.setLocation(index, spill_location);
        self.register_values[reg] = NO_NODE;
        try self.emitLoad(reg, spill_location);
        return reg;
    }

    fn nextSpillLocation(self: *Self) !u24 {
        if (self.next_spill_slot >= FIRST_SENTINEL - SPILL_BASE) return error.TooManySpills;
        const spill_location = SPILL_BASE + self.next_spill_slot;
        self.next_spill_slot += 1;
        return spill_location;
    }

    fn freeRegister(self: *Self, reg: u8) void {
        std.debug.assert(reg < self.register_count);
        self.free_registers.set(reg);
        self.recent_registers.remove(reg);
        self.register_values[reg] = NO_NODE;
    }

    fn location(self: *const Self, index: u32) u24 {
        return self.locations.items[index];
    }

    fn setLocation(self: *Self, index: u32, new_location: u24) void {
        self.locations.items[index] = new_location;
    }

    fn pushToken(self: *Self, token: Token) !void {
        try self.token_stack.append(self.allocator, token);
    }

    fn emitLoad(self: *Self, reg: u8, spill_location: u24) !void {
        try self.pushToken(Token.regAlloc(TK.op_load, registerLocation(reg), spill_location));
    }

    fn emitStore(self: *Self, reg: u8, spill_location: u24) !void {
        try self.pushToken(Token.regAlloc(TK.op_store, spill_location, registerLocation(reg)));
    }
};

pub fn registerLocation(reg: u8) u24 {
    std.debug.assert(reg < MAX_REGISTERS);
    return @intCast(reg);
}

pub fn isRegister(location: u24, register_count: u8) bool {
    return location < register_count;
}

pub fn isSpill(location: u24) bool {
    return location >= SPILL_BASE and location < FIRST_SENTINEL;
}

pub fn spillSlot(location: u24) u24 {
    std.debug.assert(isSpill(location));
    return location - SPILL_BASE;
}
