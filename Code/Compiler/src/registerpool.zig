const std = @import("std");
const bitset = @import("bitset.zig");
const lru = @import("lru.zig");

pub const MAX_REGISTERS = 64;

const BitSet = bitset.BitSet64;
const RecentRegisters = lru.Lru(MAX_REGISTERS);
const NO_NODE = std.math.maxInt(u32);

pub const RegisterPool = struct {
    const Self = @This();

    pub const Allocation = struct {
        register: u8,
        evicted: ?u32 = null,
    };

    register_pool: BitSet, // Base set of available registers we can allocate from. Not mutated.
    free_registers: BitSet = BitSet.initEmpty(),
    recent_registers: RecentRegisters = .{},
    register_values: [MAX_REGISTERS]u32 = [_]u32{NO_NODE} ** MAX_REGISTERS,

    pub fn init(free_registers: BitSet) !Self {
        if (free_registers.mask == 0) return error.InvalidRegisterSet;

        var self = Self{ .register_pool = free_registers };
        self.reset();
        return self;
    }

    pub fn reset(self: *Self) void {
        self.free_registers = self.register_pool;
        self.recent_registers = .{};
        self.register_values = [_]u32{NO_NODE} ** MAX_REGISTERS;
    }

    pub fn allocate(self: *Self, index: u32) !Allocation {
        if (self.free_registers.findFirstSet()) |free_register| {
            const reg: u8 = @intCast(free_register);
            self.assign(index, reg);
            return .{ .register = reg };
        }

        const reg = self.recent_registers.popLru() orelse return error.NoRegisterToSpill;
        const evicted = self.register_values[reg];
        std.debug.assert(evicted != NO_NODE);

        self.register_values[reg] = NO_NODE;
        self.assign(index, reg);
        return .{ .register = reg, .evicted = evicted };
    }

    pub fn free(self: *Self, reg: u8) void {
        std.debug.assert(self.register_pool.isSet(reg));
        self.free_registers.set(reg);
        self.recent_registers.remove(reg);
        self.register_values[reg] = NO_NODE;
    }

    pub fn touch(self: *Self, reg: u8) void {
        std.debug.assert(self.register_pool.isSet(reg));
        std.debug.assert(!self.free_registers.isSet(reg));
        std.debug.assert(self.register_values[reg] != NO_NODE);
        self.recent_registers.set(reg);
    }

    fn assign(self: *Self, index: u32, reg: u8) void {
        std.debug.assert(self.register_pool.isSet(reg));
        std.debug.assert(self.register_values[reg] == NO_NODE);
        self.free_registers.unset(reg);
        self.register_values[reg] = index;
        self.recent_registers.set(reg);
    }
};

test "RegisterPool allocates free registers before eviction" {
    var pool = try RegisterPool.init(bitset.lowBits(2));

    const first = try pool.allocate(10);
    try std.testing.expectEqual(@as(u8, 0), first.register);
    try std.testing.expectEqual(@as(?u32, null), first.evicted);

    const second = try pool.allocate(11);
    try std.testing.expectEqual(@as(u8, 1), second.register);
    try std.testing.expectEqual(@as(?u32, null), second.evicted);

    const third = try pool.allocate(12);
    try std.testing.expectEqual(@as(u8, 0), third.register);
    try std.testing.expectEqual(@as(?u32, 10), third.evicted);
}

test "RegisterPool touch protects a register from LRU eviction" {
    var pool = try RegisterPool.init(bitset.lowBits(2));

    const first = try pool.allocate(10);
    _ = try pool.allocate(11);
    pool.touch(first.register);

    const third = try pool.allocate(12);
    try std.testing.expectEqual(@as(u8, 1), third.register);
    try std.testing.expectEqual(@as(?u32, 11), third.evicted);
}

test "RegisterPool free releases a register for reuse" {
    var pool = try RegisterPool.init(bitset.lowBits(2));

    const first = try pool.allocate(10);
    _ = try pool.allocate(11);
    pool.free(first.register);

    const third = try pool.allocate(12);
    try std.testing.expectEqual(first.register, third.register);
    try std.testing.expectEqual(@as(?u32, null), third.evicted);
}

test "RegisterPool only allocates explicit free registers" {
    var free_registers = BitSet.initEmpty();
    free_registers.set(2);
    free_registers.set(4);
    var pool = try RegisterPool.init(free_registers);

    const first = try pool.allocate(10);
    try std.testing.expectEqual(@as(u8, 2), first.register);

    const second = try pool.allocate(11);
    try std.testing.expectEqual(@as(u8, 4), second.register);

    const third = try pool.allocate(12);
    try std.testing.expectEqual(@as(u8, 2), third.register);
    try std.testing.expectEqual(@as(?u32, 10), third.evicted);

    pool.reset();
    const after_reset = try pool.allocate(13);
    try std.testing.expectEqual(@as(u8, 2), after_reset.register);
}
