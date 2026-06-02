const std = @import("std");
const IRQueue = @import("irq.zig").IRQueue;
const TokenQueue = @import("../lexer.zig").TokenQueue;

pub const IR = struct {
    const Self = @This();

    irq: *IRQueue,

    pub fn init(irq: *IRQueue) !Self {
        return Self{ .irq = irq };
    }

    pub fn lower(self: *Self, parsedQ: *TokenQueue) void {
        for (parsedQ.list.items) |token| {
            switch (token.kind) {
                .lit_number => self.irq.emitKind(token),
                .op_add, .op_mul => self.irq.emitBinary(token),
            }
        }
    }
};
