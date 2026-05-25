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

    register_count: u8,
    free_registers: BitSet = BitSet.initEmpty(),
    recent_registers: RecentRegisters = .{},
    register_values: [MAX_REGISTERS]u32 = [_]u32{NO_NODE} ** MAX_REGISTERS,

    pub fn init(register_count: u8) !Self {
        if (register_count == 0 or register_count > MAX_REGISTERS) return error.InvalidRegisterCount;

        var self = Self{ .register_count = register_count };
        self.reset();
        return self;
    }

    pub fn registerCount(self: *const Self) u8 {
        return self.register_count;
    }

    pub fn reset(self: *Self) void {
        self.free_registers = bitset.lowBits(self.register_count);
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
        std.debug.assert(reg < self.register_count);
        self.free_registers.set(reg);
        self.recent_registers.remove(reg);
        self.register_values[reg] = NO_NODE;
    }

    pub fn touch(self: *Self, reg: u8) void {
        std.debug.assert(reg < self.register_count);
        std.debug.assert(!self.free_registers.isSet(reg));
        std.debug.assert(self.register_values[reg] != NO_NODE);
        self.recent_registers.set(reg);
    }

    fn assign(self: *Self, index: u32, reg: u8) void {
        std.debug.assert(reg < self.register_count);
        std.debug.assert(self.register_values[reg] == NO_NODE);
        self.free_registers.unset(reg);
        self.register_values[reg] = index;
        self.recent_registers.set(reg);
    }
};

test "RegisterPool allocates free registers before eviction" {
    var pool = try RegisterPool.init(2);

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
    var pool = try RegisterPool.init(2);

    const first = try pool.allocate(10);
    _ = try pool.allocate(11);
    pool.touch(first.register);

    const third = try pool.allocate(12);
    try std.testing.expectEqual(@as(u8, 1), third.register);
    try std.testing.expectEqual(@as(?u32, 11), third.evicted);
}

test "RegisterPool free releases a register for reuse" {
    var pool = try RegisterPool.init(2);

    const first = try pool.allocate(10);
    _ = try pool.allocate(11);
    pool.free(first.register);

    const third = try pool.allocate(12);
    try std.testing.expectEqual(first.register, third.register);
    try std.testing.expectEqual(@as(?u32, null), third.evicted);
}
