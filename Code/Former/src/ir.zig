const std = @import("std");
const print = std.debug.print;
const Allocator = std.mem.Allocator;

const NormalOp = packed struct(u64) {
    // A three-address code instruction
    // The indexes specify what is referenced.
    // Result implicitly goes to its index in the operator array.
    // Some operations reference the token queue (for constants, etc.)
    // There are ops to reference results from other blocks (left = block, right = var)
    op: u16,
    left: u16,
    right: u16,
};

pub const IR = struct {
    const Self = @This();
    allocator: Allocator,

    pub fn init(allocator: Allocator) Self {
        return Self{ .allocator = allocator };
    }

    pub fn deinit(self: *Self) void {
        // self.allocator.free(self);
    }
};
