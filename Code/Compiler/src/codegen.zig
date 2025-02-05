const std = @import("std");
const arm = @import("arm.zig");
const tok = @import("token.zig");
const parser = @import("parser.zig");
const bitset = @import("bitset.zig");
const ns = @import("namespace.zig");

const Allocator = std.mem.Allocator;
const Token = tok.Token;
const TK = tok.Kind;
const print = std.debug.print;
const platform = @import("platform.zig");

const DEBUG = true;

pub const Syscall = platform.Syscall;

pub const Codegen = struct {
    // Converts parsed token stream into assembly.

    const Self = @This();
    objCode: std.ArrayList(u32),
    registerMap: bitset.BitSet32 = bitset.BitSet32.initEmpty(), // Bitmap of which registers are in use.
    buffer: []const u8,
    regStack: u64 = 0,

    pub fn init(allocator: Allocator, buffer: []const u8) Self {
        return Self{ .objCode = std.ArrayList(u32).init(allocator), .buffer = buffer, .regStack = 0 };
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

    pub fn emit_syscall(self: *Self, syscall: Syscall, arg: arm.Reg) !void {
        // Load syscall #1 - exit - to ABI syscall register.
        // assert the syscall register is free.
        if (self.registerMap.isSet(16)) {
            return error.SyscallRegisterAlreadyInUse;
        }

        try self.objCode.append(arm.orr(arm.Reg.x0, arg, arm.WZR));
        try self.objCode.append(arm.movz(arm.Reg.x16, @intFromEnum(syscall)));

        // Syscall - with an exit code we can read from bash.
        try self.objCode.append(arm.svc(0));
    }

    pub fn pushReg(self: *Self, reg: arm.Reg) void {
        self.regStack = (self.regStack << 5) | @intFromEnum(reg);
    }

    pub fn popReg(self: *Self) arm.Reg {
        const reg: arm.Reg = @enumFromInt(self.regStack & 0b11111);
        self.regStack = (self.regStack >> 5);
        return reg;
    }

    pub fn emitAll(self: *Self, tokenQueue: []Token) !void {
        var reg = arm.Reg.x0;
        for (tokenQueue, 0..) |token, index| {
            // try self.emit(token);
            switch (token.kind) {
                TK.lit_number => {
                    // regStack = (regStack << 5) | @intFromEnum(reg); // Push the current register.
                    reg = self.getFreeReg();
                    self.pushReg(reg);
                    // const value = self.buffer[token.data.range.offset .. token.data.range.offset + token.data.range.length];
                    const imm16: u16 = @truncate(token.data.value.arg0);
                    // const imm16 = std.fmt.parseInt(u16, value, 10) catch unreachable;
                    try self.objCode.append(arm.movz(reg, imm16));
                },
                TK.identifier => {
                    if (token.aux.declaration) {
                        reg = self.getFreeReg();
                        self.pushReg(reg);
                        // Save which register this identifier is associated with to the parsed queue so future refs can look it up.
                        tokenQueue[index] = token.assignReg(@intFromEnum(reg));
                        if (DEBUG) {
                            print("DECL {any}, x{any}\n", .{ index, reg });
                        }
                    } else {
                        // Find what register this identifier is at by following the usage chain.
                        const offset = token.data.value.arg1;
                        const prevRefDecIndex = ns.applyOffset(@truncate(index), offset);
                        const register = tokenQueue[prevRefDecIndex].data.value.arg0;
                        if (DEBUG) {
                            print("REF {any}, x{any} offset {any}\n", .{ prevRefDecIndex, register, offset });
                        }
                        reg = @enumFromInt(register);
                        self.pushReg(reg);

                        // Save that register to this identifier's location.
                        tokenQueue[index] = token.assignReg(@intFromEnum(reg));
                    }
                },
                TK.op_assign_eq => {
                    const value = self.popReg();
                    const identifier = self.popReg();
                    const instr = arm.mov(identifier, value);
                    try self.objCode.append(instr);
                    self.pushReg(identifier);
                },
                TK.op_add => {
                    const rd = self.popReg(); // arm.Reg.x0;
                    const rn = self.popReg();
                    const rm = rd; // @enumFromInt(reg);
                    self.pushReg(rd);
                    const instr = arm.add(rd, rn, rm);
                    try self.objCode.append(instr);
                },
                TK.op_mul => {
                    const rd = self.popReg();
                    const rn = self.popReg();
                    const rm = rd;
                    self.pushReg(rd);
                    const instr = arm.mul(rd, rn, rm);

                    try self.objCode.append(instr);
                },
                TK.aux_stream_start => {},
                else => {
                    tok.print_token("Unhandled token in Codegen: {any}\n", token, self.buffer);
                },
            }
        }
        try self.emit_syscall(Syscall.exit, reg);

        // print("Total instructions")
    }
};

test {
    @import("std").testing.refAllDecls(Codegen);
}
