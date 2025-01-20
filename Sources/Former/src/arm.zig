const std = @import("std");

// Architecture support for 64 bit ARM (AARCH64).
// We only support the 64 bit variant.
// Reference:
// https://developer.arm.com/documentation/ddi0602/2024-12/Index-by-Encoding?lang=en

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

// SF bit.
pub const MODE_A32: u1 = 0;
pub const MODE_A64: u1 = 1;

pub const ArmInstruction = union(enum) {
    SME: MatrixEncoding,
    SVE: VectorEncoding,
    DataProcessingImmediate: ImmediateEncoding,
    Branch: BranchEncoding,
    DataProcessingRegister: RegisterEncoding,
    DataProcessingAdvanced: FloatEncoding, // Scalar Floating-Point and Advanced SIMD
    LoadStore: LoadStoreEncoding,
};

pub const MatrixEncoding = packed struct(u32) { _: u32 };
pub const VectorEncoding = packed struct(u32) { _: u32 };

////////////////////////////////////////////////////////////////////////////////
//                   Data Processing - Immediate
////////////////////////////////////////////////////////////////////////////////

// pub const ImmediateEncoding = packed struct(u32) { _: u32 };
pub const ImmediateEncoding = union(enum) {
    ImmOneSource: ImmOneSourceEncoding,
    ImmPcRel: ImmPcRelEncoding,
    ImmAddSub: ImmAddSubEncoding,
    ImmAddSubTags: ImmAddSubTagsEncoding,
    ImmMinMax: ImmMinMaxEncoding,
    ImmLogical: ImmLogicalEncoding,
    ImmMovWide: ImmMovWideEncoding,
    ImmBitfield: ImmBitfieldEncoding,
    ImmExtract: ImmExtractEncoding,
};

pub const ImmOneSourceEncoding = packed struct(u32) {
    // Depends on FEAT_PAuth_LR feature.
    rd: Reg,
    imm16: u16,
    opc: OpCode,
    _: u8 = 0b11_100_111,
    sf: u1 = MODE_A64,

    pub const OpCode = enum(u2) { AUTIASPPC = 0b00, AUTIBSPPC = 0b01 };
};

pub const ImmPcRelEncoding = packed struct(u32) {
    rd: Reg,
    immhi: u19,
    _: 0b100_00,
    immlo: u2,
    op: OpCode,

    pub const OpCode = enum(u1) { ADR = 0, ADRP = 1 };
};

pub const ImmAddSubEncoding = packed struct(u32) {
    // Add / Sub
    rd: Reg,
    rn: Reg,
    imm12: u12,
    shift: u1 = 0, // 1 = LSL #12
    _: u6 = 0b100_010,
    set_flags: u1 = 0,
    op: OpCode,
    mode: u1 = MODE_A64, //

    pub const OpCode = enum(u1) {
        ADD = 0,
        SUB = 1,
    };
};

pub const ImmAddSubTagsEncoding = packed struct(u32) {
    // Used for adding to memory with memory tagging for protection checks.
    // Depends on FEAT_MTE Feature.
    rd: Reg,
    rn: Reg,
    imm4: u4,
    op3: u2,
    imm6: u6,
    _: u7 = 0b100_0110,
    s: u1,
    op: OpCode,
    sf: u1 = MODE_A64,

    pub const OpCode = enum(u1) {
        ADDG = 0,
        SUBG = 1,
    };
};
pub const ImmMinMaxEncoding = packed struct(u32) {
    // Depends on FEAT_CSSC Feature.
    rd: Reg,
    rn: Reg,
    imm8: u8,
    opc: u4,
    _: 0b100_0111,
    s: 0, // Fixed to 0.
    op: 0, // Fixed to 0
    sf: u1 = MODE_A64,

    pub const OpCode = enum(u4) {
        SMAX = 0b0000, // Signed maximum of source reg and immediate, written to destination reg.
        UMAX = 0b0001, // Unsigned max
        SMIN = 0b0010, // Signed min
        UMIN = 0b0011, // Unsigned min
    };
};

pub const ImmLogicalEncoding = packed struct(u32) {
    rd: Reg,
    rn: Reg,
    imms: u6,
    immr: u6,
    N: u1 = 0, // An extra bit of immediate only used in 64 bit mode.
    _: 0b100_100,
    op: OpCode,
    sf: u1 = MODE_A64,

    pub const OpCode = enum(u1) {
        AND = 0b00, // AND register and immediate. Write to destination register.
        ORR = 0b01, // Bitwise OR. Alias of MOV (bitmask immediate).
        EOR = 0b10, // Exclusive OR.
        ANDS = 0b11, // Bitwise AND, updates condition flags. Alias of TST immediate.
    };
};
pub const ImmMovWideEncoding = packed struct(u32) {
    rd: Reg,
    imm16: u16,
    hw: ShiftAmount = ShiftAmount.LSL_0,
    // Shift amount. 0X pattern for 32 bit mode, and 2 bits for 64 bit mode.
    // 0, 16, 32 or 48.
    _: 0b100_101,
    opc: OpCode,
    sf: u1 = MODE_A64,

    pub const OpCode = enum(u2) {
        MOVN = 0b00, // Move wide with NOT. Moves the inverse of the optionally-shifted 16 bit imm.
        MOVZ = 0b10, // Move wide with zero.
        MOVK = 0b11, // Move wide with keep. Keeps other bits unchanged in the register.
    };

    pub const ShiftAmount = enum(u2) {
        LSL_0 = 0b00,
        LSL_16 = 0b01,
        LSL_32 = 0b10, // 64 bit mode only.
        LSL_48 = 0b11, // 64 bit mode only
    };
};
pub const ImmBitfieldEncoding = packed struct(u32) {
    // SBFM = Signed Bitfield Move
    // If imms >= immr, copy (imms-immr+1) bits from position immr in source reg to the LSB bits of destination reg.
    // Take bits immr through imms and rotate right by immr, sign fill upper bits.
    // If imms < immr, copy (imms+1) bits from LSB of source to (regsize-immr) of the dest.
    // Take imms+1 low bits and rotate right by immr sign fill upper bits.
    // Destination bits below bitfield are set to zero, and bits above are set to a copy of the most significant bit of the bitfield.

    // See https://devblogs.microsoft.com/oldnewthing/20220803-00/?p=106941
    // UBFM = Unsigned bitfield move.
    // UBFX = Unsigned bitfield extract.
    // [................bbbbbbbb....] -> [000000000000000000000000bbbbbbbb]

    // UBFIZ = Unsigned bitfield insert into zeroes
    // When immr > imms
    // Reinterprets UBFM as bitfield insertion and reinterprets right-rot as left-shift.
    // [........................bbbbbbbb] -> [00000000000000000bbbbbbbb0000]

    // BFXIL = Like the other two, but leaves the unsued bits as-is rather than filling with 0 or sign.
    // BFC = Clear w bits starting at lsb with zero.

    rd: Reg,
    rn: Reg,
    imms: u6,
    immr: u6,
    N: u1 = 1, // 0 in 32 bit mode. 1 in 64 bit mode.
    _: 0b100_110,
    opc: OpCode,
    sf: u1 = MODE_A64,

    pub const OpCode = enum(u2) {
        SBFM = 0b00,
        BFM = 0b01,
        UBFM = 0b10,
    };
};
pub const ImmExtractEncoding = packed struct(u32) {
    // Reference - https://devblogs.microsoft.com/oldnewthing/20220803-00/?p=106941
    // Just one opcode defined. EXTR - Word/Double-word extraction.
    // Extract a register from a pair of registers.
    // [Rn..... [NNNN]][[MMMMMMMM]....... Rm] -> [NNNNMMMMMMMM]
    // RN and RM registers concantenated in big-endian order.

    rd: Reg,
    rn: Reg,
    imms: u6, // 0xxxxx in 32 bit mode. LSB pos from which to extract. 0-31 / 0-63
    rm: Reg,
    o0: u1 = 0,
    N: u1 = 1, // 0 in 32 bit mode. 1 in 64 bit mode.
    op21: u2 = 0b00,
    sf: u1 = MODE_A64,
};

////////////////////////////////////////////////////////////////////////////////
//           Branch, Exception Generating and System Instructions
////////////////////////////////////////////////////////////////////////////////

pub const BranchEncoding = union(enum) {
    BrConditionalEncoding: BrConditional,
};

pub const Cond = enum(u4) {
    EQ = 0b0000, // Equal. Z == 1
    NE = 0b0001, // Not equal. Z==0
    CS = 0b0010, // Carry Set. C==1 (Or HS - Unsigned Higher or same)
    CC = 0b0011, // Carry Clear. C==0 (Unsigned lower)
    MI = 0b0100, // Minus. N==1
    PL = 0b0101, // Plus. N==0
    VS = 0b0110, // Signed Overflow. V==1
    VC = 0b0111, // No signed overflow. V==0
    HI = 0b1000, // Unsigned Higher. C==1 && Z==0
    LS = 0b1001, // Unsigned Lower or Same. C==0 || Z==0
    GE = 0b1010, // Signed Greater than or Equal. N==V
    LT = 0b1011, // Signed Less Than. N!=V
    GT = 0b1100, // Signed Greater Than. Z==0 && N==V.
    LE = 0b1101, // Signed Less than or Equal. Z==1 || N!=V
    AL = 0b1110, // Always
    NV = 0b1111, // Never
};

pub const BrConditional = packed struct(u32) {
    //
    cond: Cond,
    op: OpCode,
    offset: u19, // PC Relative offset.
    _: 0b010_101_00,

    pub const OpCode = enum(u1) {
        B = 0, // Conditional branch to label at PC relative offset. hint that it's not a subroutine call or ret.
        BC = 1, // Feature - FEAT_HBC. Branch consistent conditionally. Hint that it's likely to branch consistently and is very unlikely to change direction.
    };
};

pub const MiscBranchImm = packed struct(u32) {
    // Return from subroutine with enhanced pointer auth using an immediate offset.
    // Authenticates the address in LR
    // SP - first modifier.
    // Imm value subtracted from SP as second mod.
    // and specified key (A or B based on instruction) and branches to the authenticated address.
    // With hint that it's a subroutine return.
    op2: 0b11111,
    offset: u16,
    opc: OpCode,
    _: 0b010_101_01,

    // Depends on FEAT_PAuth_LR
    pub const OpCode = enum(u3) {
        RETAASPPC = 0b000,
        RETABSPPC = 0b001,
    };
};

// Compare bytes/halfwords in registers and branch.
// Feature - FEAT_CMPBR
pub const CompareAndBranch = packed struct(u32) {
    // Hints that not a subroutine call or ret.
    // Doesn't affect the condition flags.

    rt: Reg, // Test register.
    label: u9, // Label to branch to. Offset from PC, -1024 to 1020, as imm9 * 4.
    halfword: u1 = 0, // 0 = byte, 1 = halfword,
    _: 1,
    rm: Reg,
    cc: OpCode,
    __: 0b011_101_00,

    pub const OpCode = enum(u3) {
        GT = 0b000, // Greater than. ([N]eg and o[V]erflow flags)
        GE = 0b001, // Greater than or equal.
        HI = 0b010, // Unsigned higher. (CZ flags)
        HS = 0b011, // Unsigned Higher or same
        EQ = 0b110,
        NE = 0b111,
    };
};

// Exception Generation
pub const ExceptionCall = packed struct(u32) {
    ll: OpCode.LL,
    _: 0b000,
    imm16: u16,
    opc: OpCode.OPC,
    __: 0b110_101_00,

    pub const OpCode = packed struct(u5) {
        opc: OPC,
        ll: LL,

        pub const OPC = enum(u3) {
            SVC_HVC_SMC = 0b000,
            BRK = 0b001,
            HLT = 0b010,
            TCANCEL = 0b11,
            DCPS = 0b101,
        };

        pub const LL = enum(u2) {
            SVC = 0b01,
            HVC = 0b10,
            SMC = 0b11,
            BRK_HLT_TCANCEL = 0b00,
            DCPS1 = 0b01,
            DCPS2 = 0b10,
            DCPS3 = 0b11,
        };
    };
};

pub const RegisterEncoding = packed struct(u32) { _: u32 };
pub const FloatEncoding = packed struct(u32) { _: u32 };
pub const LoadStoreEncoding = packed struct(u32) { _: u32 };

pub const MOVW_IMM = packed struct(u32) {
    rd: Reg,
    imm16: u16,
    hw: u2 = 0b00,
    _movw_imm: u6 = 0b100_101,
    opc: OpCode,
    sf: u1 = MODE_A64,

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
    option: Option64 = Option64.UXTX_LSL, // UXTX_LSL?
    rm: Reg, // Second source register
    _: u10 = 0b00_0101_1001, // Fixed opcode for ADD (register)
    sf: u1 = MODE_A64, // 1 = 64-bit operation, 0 = 32-bit operation

    pub const Option64 = enum(u3) {
        UXTB = 0b000, // Unsigned zero-extend byte.
        UXTH = 0b001, // Unsigned zero-extend halfword.
        UXTW = 0b010, // Unsigned zero-extend word.
        UXTX_LSL = 0b011, // Unsigned zero-extend / logical shift left.
        SXTB = 0b100, // Signed extend byte.
        SXTH = 0b101, // Signed extend halfword.
        SXTW = 0b110, // Signed extend word.
        SXTX = 0b111,
    };
};

pub const ADD_IMM = packed struct(u32) {
    rd: Reg,
    rn: Reg,
    imm12: u12,
    sh: u1 = 0, // 1 = LSL 12.
    _: u8 = 0b00100010,
    sf: u1 = MODE_A64, // 64-bit mode
};

pub const AND_IMM = packed struct(u32) {
    rd: Reg,
    rn: Reg,
    // imms: u6,
    // immr: u6,
    // n: u1,
    mask: u13, // 13 bits in 64 bit mode.
    _: u8 = 0b0010_0100,
    sf: u1 = 1,
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
