const std = @import("std");
const arm = @import("arm.zig");
const tok = @import("token.zig");
const parser = @import("parser.zig");
const bitset = @import("bitset.zig");

const Allocator = std.mem.Allocator;
const Token = tok.Token;
const TK = Token.Kind;
const print = std.debug.print;
const platform = @import("platform.zig");

pub const Syscall = platform.Syscall;

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
                // print("emitting {any} to reg {any}\n", .{ imm16, reg });
                try self.objCode.append(arm.movz(reg, imm16));
            },
            TK.op_add => {
                const rd = arm.Reg.x0;
                const rn: arm.Reg = @enumFromInt(self.registerMap.count() - 1);
                const rm: arm.Reg = @enumFromInt(self.registerMap.count() - 2);

                const instr: u32 = @as(u32, @bitCast(arm.ADD_XREG{
                    .rd = rd,
                    .rn = rn,
                    // .option = arm.ADD_XREG.Option64.UXTB,
                    .rm = rm,
                }));
                try self.objCode.append(instr);
            },
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

        // const verify_addimm = arm.ADD_IMM{
        //     .rd = arm.Reg.x0,
        //     .rn = arm.Reg.x0,
        //     .imm12 = 10,
        //     .sh = 0,
        // };
        // try self.objCode.append(@as(u32, @bitCast(verify_addimm)));

        // const verify_addimm = arm.ImmAddSub{
        //     .rd = arm.Reg.x0,
        //     .rn = arm.Reg.x0,
        //     .imm12 = 10,
        //     .op = arm.ImmAddSub.Op.ADD,
        // };
        // try self.objCode.append(verify_addimm.encode());

        // try self.objCode.append(arm.addi(arm.Reg.x0, arm.Reg.x0, 10));

        // const verify_and_imm = arm.AND_IMM{
        //     .rd = arm.Reg.x0,
        //     .rn = arm.Reg.x0,
        //     .mask = 0b01,
        // };
        // try self.objCode.append(@as(u32, @bitCast(verify_and_imm)));

        try self.objCode.append(arm.movz(arm.Reg.x16, @intFromEnum(syscall)));

        // Syscall - exit 42 (so we can read the code out from bash).
        try self.objCode.append(arm.svc(syscall));
    }

    pub fn emitAll(self: *Self, tokenQueue: []Token) !void {
        for (tokenQueue) |token| {
            try self.emit(token);
        }
        try self.emit_syscall(Syscall.exit);

        // print("Total instructions")
    }
};
