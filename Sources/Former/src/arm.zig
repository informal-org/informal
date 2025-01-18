const std = @import("std");

// Architecture support for 64 bit ARM (AARCH64).
// We only support the 64 bit variant.

pub const Reg = enum(u5) {
    x0 = 0,
    x1 = 1,
    x2 = 2,
    x3 = 3,
    x4 = 4,
    x5 = 5,
    x6 = 6,
    x7 = 7,
    x8 = 8,
    x9 = 9,
    x10 = 10,
    x11 = 11,
    x12 = 12,
    x13 = 13,
    x14 = 14,
    x15 = 15,
    x16 = 16,
    x17 = 17,
    x18 = 18,
    x19 = 19,
    x20 = 20,
    x21 = 21,
    x22 = 22,
    x23 = 23,
    x24 = 24,
    x25 = 25,
    x26 = 26,
    x27 = 27,
    x28 = 28,
    x29 = 29,
    x30 = 30,
    x31 = 31,
};

pub const MOVW_IMM = packed struct(u32) {
    rd: Reg,
    imm16: u16,
    hw: u2 = 0b00,
    _movw_imm: u6 = 0b100_101,
    opc: OpCode,
    sf: u1 = 1,

    pub const OpCode = enum(u2) {
        MOVN = 0b00, // Move wide with NOT. Moves the inverse of the optionally-shifted 16 bit imm.
        MOVZ = 0b10, // Move wide with zero.
        MOVK = 0b11, // Move wide with keep. Keeps other bits unchanged in the register.
    };
};

// Add extended register
pub const ADD_XREG = packed struct(u32) {
    rd: Reg, // Destination register
    rn: Reg, // First source register
    shift: u3 = 0b000, // Cannot be 101, 110 or 111,
    option: Option64 = Option64.SXTX, // UXTX_LSL?
    rm: Reg, // Second source register
    _: u10 = 0b00_0101_1001, // Fixed opcode for ADD (register)
    sf: u1 = 1, // 1 = 64-bit operation, 0 = 32-bit operation

    pub const Option64 = enum(u3) {
        UXTB = 0b000, // Unsigned extend byte.
        UXTH = 0b001, // Unsigned extend halfword.
        UXTW = 0b010, // Unsigned extend word.
        UXTX_LSL = 0b011,
        SXTB = 0b100, // Signed extend byte.
        SXTH = 0b101, // Signed extend halfword.
        SXTW = 0b110, // Signed extend word.
        SXTX = 0b111,
    };
};

// Supervisor Call - Syscalls, traps, etc.
pub const SVC = packed struct(u32) {
    pub const SYSCALL = 0x80;

    _base: u5 = 0b00001,
    imm16: u16,
    _svc: u11 = 0b11010100_000,
};

const expect = std.testing.expect;

test "Test MOV" {
    const instr = MOVW_IMM{
        .opc = MOVW_IMM.OpCode.MOVZ,
        .imm16 = 42,
        .rd = Reg.x0,
    };

    // Expected bytes in little endian.
    try expect(std.mem.eql(u8, std.mem.asBytes(&instr), &[_]u8{ 0x40, 0x05, 0x80, 0xD2 }));

    // Reference for how this instruction is decoded:
    // 40 05 80 d2
    // Little endian order:
    // D2 80 05 40
    // 11010010 1000 0000 0000 0101 0100 0000
    // Decode:
    // 110 [1001] 0 1000 0000 0000 0101 0100 0000
    // 100x = data processing - immediate
    // 110 100[101] 000 0000 0000 0101 0100 0000
    // 101 = Move wide immediate
    // [1][10] [100101] [00] [0 0000 0000 0101 010 [0 0000]
    // SF = 1
    // OPC = 10
    // 100101
    // HW = 00
    // IMM16 = 0000000000101010 = 42!
    // Rd = x0
}
