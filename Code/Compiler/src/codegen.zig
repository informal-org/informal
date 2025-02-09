const std = @import("std");
const arm = @import("arm.zig");
const tok = @import("token.zig");
const parser = @import("parser.zig");
const bitset = @import("bitset.zig");
const resolution = @import("resolution.zig");

const Allocator = std.mem.Allocator;
const Token = tok.Token;
const StringArrayHashMap = std.array_hash_map.StringArrayHashMap;
const TK = tok.Kind;
const print = std.debug.print;
const platform = @import("platform.zig");

const DEBUG = true;

pub const Syscall = platform.Syscall;

pub const Codegen = struct {
    // Converts parsed token stream into assembly.

    const Self = @This();
    allocator: Allocator,
    objCode: std.ArrayList(u32),
    registerMap: bitset.BitSet32 = bitset.BitSet32.initEmpty(), // Bitmap of which registers are in use.
    buffer: []const u8,
    regStack: u64 = 0,

    // Constant references need to be resolved at the very end. This points to the last ref location in the binary.
    // Once the full binary is generated, we'll walk through and fix these. Pre-fixup, each index will reference the previous.
    strConstRefTail: usize = 0, // Last string constant reference in the parser queue (for fixup linked-list).
    // objConstRefTail: u32 = 0,
    // pqStrConstRefTail: u32 = 0, // Last constant reference in the parser queue for constant address fixup.
    // constLengthOffsets: std.ArrayList(u32), // Const ID -> Length. Later used to computed cumulative offsets.

    // const CONST_BASE_REG = arm.Reg.x20;

    pub fn init(allocator: Allocator, buffer: []const u8) Self {
        return Self{ .objCode = std.ArrayList(u32).init(allocator), .buffer = buffer, .regStack = 0, .allocator = allocator };
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
        self.registerMap.unset(@intFromEnum(reg));
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

    pub fn fixupConstRefs(self: *Self, parsedQueue: []Token, strConsts: *StringArrayHashMap(u64)) !void {
        // Constnat references appear after the code, so their relative address is unknown until we know the total code size.
        // So during code-generation, we emit just the constant ID to the object code locations.
        // Then reuse the token-space as linked-list links - An absolute reference to the associated object-code location
        // and a relative location to the previous constant reference.

        // Once the binary is fully generated, walk it and fixup references to the constant pool using these two linked

        // Compute the absolute position of each constant.
        // TODO: Cumulative constant offset is useful during macho generation. We should pass it in.
        var cumOffset: usize = 0;
        var constOffsets = try self.allocator.alloc(u32, strConsts.count());
        defer self.allocator.free(constOffsets);

        // Using the lengths from here does pollute the cache a bit with unnecessary string data.
        // But it avoids needing to store the lengths separately.
        for (0.., strConsts.keys()) |index, strElem| {
            cumOffset += strElem.len;
            constOffsets[index] = @truncate(cumOffset);
        }

        // Compute where the constants are supposed to start.
        // Might be possible to simplify this calculation, but this works.
        // TODO: We'll need to handle multiple-pages in the future for larger programs.
        const codeSize = self.objCode.items.len * 4;
        const totalEnd = std.mem.alignBackward(u64, 0x4000 - codeSize - cumOffset - 16, 16);
        const constStart: u12 = @truncate(totalEnd + codeSize - cumOffset);

        // Index safety - since the zero index in the parser queue is always reserved for the start-node,
        // it'll never contain a constant. So we can safely use it as a sentinel value.
        while (self.strConstRefTail != 0) {
            // Arg0 is absolute binary location. Arg1 is relative offset to previous const in parser queue.
            const tailNode = parsedQueue[self.strConstRefTail];
            const objIndex = tailNode.data.value.arg0;
            self.strConstRefTail = self.strConstRefTail - tailNode.data.value.arg1;
            // TODO: Future - need additional bounds safety checking here.
            const constId = self.objCode.items[objIndex];

            // Replace it with the computed position for that constant.
            const constOffset = constOffsets[constId] + constStart;

            // TODO: We can stuff the proper register into the flags / kind fields.
            const instr = arm.addi(arm.Reg.x1, arm.Reg.x1, @truncate(constOffset));
            self.objCode.items[objIndex] = instr;
        }
    }

    pub fn emitAll(self: *Self, tokenQueue: []Token, strConsts: *StringArrayHashMap(u64)) !void {
        if (DEBUG) {
            print("\n------------- Codegen --------------- \n", .{});
        }

        // Reserve a couple of registers.
        self.registerMap.set(0);
        self.registerMap.set(1);
        self.registerMap.set(2);
        // self.registerMap.set(@intFromEnum(CONST_BASE_REG));

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
                TK.lit_string => {
                    const offsetReg = arm.Reg.x1; // self.getFreeReg(); // TODO
                    self.pushReg(offsetReg);

                    // The constant table location isn't known yet.
                    // Instead, we save the constant ID as a placeholder into the bytecode.
                    // In the parser queue, save the bytecode index and a relative offset to the previous string constant.
                    // The absolute positions will be fixed up after codegen is complete.
                    const constId = token.data.value.arg0;
                    const constLen = token.data.value.arg1;
                    const lenReg = self.getFreeReg();
                    print("Const id {d}, len {d} lenreg {any}\n", .{ constId, constLen, lenReg });

                    if (constLen > (2 << 13)) {
                        print("Compiler internal error - string constant len overflows current encoding: {any}\n", .{constLen});
                    }
                    self.pushReg(lenReg);
                    try self.objCode.append(arm.movz(lenReg, @truncate(constLen)));

                    // Resolving the address pool requires a few instructions.
                    // TODO: This will need to support other registers, rather than a fixed x1.
                    try self.objCode.append(arm.adrp(arm.Reg.x1, 0));
                    try self.objCode.append(constId);
                    const placeholderIndex = self.objCode.items.len - 1;

                    const tokenQueueOffset = index - self.strConstRefTail;
                    if (tokenQueueOffset > (2 << 16)) {
                        // TODO: We can handle this better in the future - use an overflow queue, and a sentinel value to indicate to look there.
                        print("Compiler internal error - String constant offset is too large: {any}\n", .{tokenQueueOffset});
                    }
                    tokenQueue[index] = Token.lex(token.kind, @truncate(placeholderIndex), @truncate(tokenQueueOffset));
                    self.strConstRefTail = index;
                },
                TK.identifier => {
                    if (token.aux.declaration) {
                        reg = self.getFreeReg();
                        self.pushReg(reg);
                        // Save which register this identifier is associated with to the parsed queue so future refs can look it up.
                        tokenQueue[index] = token.assignReg(@intFromEnum(reg));
                        if (DEBUG) {
                            print("DECL @{any}, {s}\n", .{ index, @tagName(reg) });
                        }
                    } else {
                        // Find what register this identifier is at by following the usage chain.
                        const offset = token.data.value.arg1;
                        const prevRefDecIndex = resolution.applyOffset(@truncate(index), offset);
                        const register = tokenQueue[prevRefDecIndex].data.value.arg0;
                        if (DEBUG) {
                            const signedOffset: i16 = @bitCast(offset);
                            print("REF @{any}, x{any} offset {any}\n", .{ prevRefDecIndex, register, signedOffset });
                        }
                        reg = @enumFromInt(register);
                        self.pushReg(reg);

                        // Save that register to this identifier's location.
                        tokenQueue[index] = token.assignReg(@intFromEnum(reg));
                    }
                },
                TK.call_identifier => {
                    // TODO: Support for our own functions.
                    // For now, this code is just dealing with syscalls.
                    // TODO: lookup the syscall and how many arguments it requires in a small table by syscall ID.
                    const arg2 = self.popReg();
                    const arg1 = self.popReg();
                    try self.objCode.append(arm.mov(arm.Reg.x2, arg2));
                    try self.objCode.append(arm.mov(arm.Reg.x1, arg1));
                    try self.objCode.append(arm.movz(arm.Reg.x0, 1));
                    try self.objCode.append(arm.movz(arm.Reg.x16, 4));
                    try self.objCode.append(arm.svc(0x80));
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
        print("Final register {any}\n", .{reg});
        try self.emit_syscall(Syscall.exit, reg);
        try self.fixupConstRefs(tokenQueue, strConsts);

        // print("Total instructions")
    }
};

const constants = @import("constants.zig");
test {
    if (constants.DISABLE_ZIG_LAZY) {
        @import("std").testing.refAllDecls(Codegen);
    }
}
