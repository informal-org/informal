const std = @import("std");
const arm = @import("arm.zig");
const tok = @import("token.zig");
const parser = @import("parser.zig");
const bitset = @import("bitset.zig");

const Allocator = std.mem.Allocator;
const Token = tok.Token;
const TK = Token.Kind;
const print = std.debug.print;

pub const Syscall = enum(u16) {
    exit = 1,
};

pub const Codegen = struct {
    // Converts parsed token stream into assembly.

    const Self = @This();
    objCode: std.ArrayList(u32),
    registerMap: bitset.BitSet32 = bitset.BitSet32.initEmpty(), // Bitmap of which registers are in use.
    buffer: []const u8,

    pub fn init(allocator: Allocator, buffer: []const u8) Self {
        return Self{ .objCode = std.ArrayList(u32).init(allocator), .buffer = buffer };
    }

    pub fn deinit(self: *Self) void {
        self.objCode.deinit();
    }

    pub fn getFreeReg(self: *Self) arm.Reg {
        const freeCount = self.registerMap.count();
        self.registerMap.set(freeCount);
        return @enumFromInt(freeCount);
    }

    pub fn freeReg(self: *Self, reg: arm.Reg) void {
        self.registerMap.clear(@intFromEnum(reg));
    }

    pub fn emit(self: *Self, token: Token) !void {
        // try self.objCode.append(token);
        switch (token.kind) {
            TK.lit_number => {
                const reg = self.getFreeReg();
                const value = self.buffer[token.data.range.offset .. token.data.range.offset + token.data.range.length];
                const imm16 = std.fmt.parseInt(u16, value, 10) catch unreachable;
                print("emitting {any} to reg {any}\n", .{ imm16, reg });

                const instr: u32 = @as(u32, @bitCast(arm.MOVW_IMM{
                    .opc = arm.MOVW_IMM.OpCode.MOVZ,
                    .imm16 = imm16,
                    .rd = reg,
                }));
                try self.objCode.append(instr);
            },
            TK.op_add => {},
            else => {
                print("unhandled token {any}\n", .{token});
            },
        }
    }

    pub fn emit_syscall(self: *Self, syscall: Syscall) !void {
        // Load syscall #1 - exit - to ABI syscall register.
        // assert the syscall register is free.
        if (self.registerMap.isSet(16)) {
            return error.SyscallRegisterAlreadyInUse;
        }

        const instr: u32 = @as(u32, @bitCast(arm.MOVW_IMM{
            .opc = arm.MOVW_IMM.OpCode.MOVZ,
            .imm16 = @intFromEnum(syscall),
            .rd = arm.Reg.x16,
        }));
        try self.objCode.append(instr);

        // Syscall - exit 42 (so we can read the code out from bash).
        try self.objCode.append(@as(u32, @bitCast(arm.SVC{ .imm16 = arm.SVC.SYSCALL })));
    }

    pub fn emitAll(self: *Self, tokenQueue: []Token) !void {
        for (tokenQueue) |token| {
            try self.emit(token);
        }
        try self.emit_syscall(Syscall.exit);

        // print("Total instructions")
    }
};
