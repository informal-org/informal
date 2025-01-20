const std = @import("std");

// Architecture support for 64 bit ARM (AARCH64).
// We only support the 64 bit variant.
// Reference:
// https://developer.arm.com/documentation/ddi0602/2024-12/Index-by-Encoding?lang=en

const platform = @import("platform.zig");

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
    ImmOneSourceEncoding: ImmOneSource,
    ImmPcRelEncoding: ImmPcRel,
    ImmAddSubEncoding: ImmAddSub,
    ImmAddSubTagsEncoding: ImmAddSubTags,
    ImmMinMaxEncoding: ImmMinMax,
    ImmLogicalEncoding: ImmLogical,
    ImmMovWideEncoding: ImmMovWide,
    ImmBitfieldEncoding: ImmBitfield,
    ImmExtractEncoding: ImmExtract,
};

pub const ImmOneSource = packed struct(u32) {
    const Self = @This();
    // Depends on FEAT_PAuth_LR feature.
    rd: Reg,
    imm16: u16,
    opc: Op,
    _: u8 = 0b11_100_111,
    sf: u1 = MODE_A64,

    pub const Op = enum(u2) { AUTIASPPC = 0b00, AUTIBSPPC = 0b01 };

    pub fn encode(self: Self) u32 {
        return @as(u32, @bitCast(self));
    }
};

pub const ImmPcRel = packed struct(u32) {
    const Self = @This();
    rd: Reg,
    immhi: u19,
    _: u5 = 0b100_00,
    immlo: u2,
    op: Op,

    pub const Op = enum(u1) { ADR = 0, ADRP = 1 };

    pub fn encode(self: Self) u32 {
        return @as(u32, @bitCast(self));
    }
};

pub const ImmAddSub = packed struct(u32) {
    const Self = @This();
    // Add / Sub
    rd: Reg,
    rn: Reg,
    imm12: u12,
    shift: u1 = 0, // 1 = LSL #12
    _: u6 = 0b100_010,
    set_flags: u1 = 0,
    op: Op,
    mode: u1 = MODE_A64, //

    pub const Op = enum(u1) {
        ADD = 0,
        SUB = 1,
    };

    pub fn encode(self: Self) u32 {
        return @as(u32, @bitCast(self));
    }

    pub fn init(rd: Reg, rn: Reg, imm12: u12, op: Op) u32 {
        return (Self{ .rd = rd, .rn = rn, .imm12 = imm12, .op = op }).encode();
    }
};

pub fn addi(rd: Reg, rn: Reg, imm12: u12) u32 {
    return ImmAddSub.init(rd, rn, imm12, ImmAddSub.Op.ADD);
}

pub fn subi(rd: Reg, rn: Reg, imm12: u12) u32 {
    return ImmAddSub.init(rd, rn, imm12, ImmAddSub.Op.SUB);
}

pub const ImmAddSubTags = packed struct(u32) {
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
pub const ImmMinMax = packed struct(u32) {
    const Self = @This();
    // Depends on FEAT_CSSC Feature.
    rd: Reg,
    rn: Reg,
    imm8: u8,
    opc: Op,
    _: u7 = 0b100_0111,
    s: 0, // Fixed to 0.
    op: 0, // Fixed to 0
    sf: u1 = MODE_A64,

    pub const Op = enum(u4) {
        SMAX = 0b0000, // Signed maximum of source reg and immediate, written to destination reg.
        UMAX = 0b0001, // Unsigned max
        SMIN = 0b0010, // Signed min
        UMIN = 0b0011, // Unsigned min
    };

    pub fn encode(self: Self) u32 {
        return @as(u32, @bitCast(self));
    }

    pub fn init(rd: Reg, rn: Reg, imm8: u8, op: Op) u32 {
        return (Self{ .rd = rd, .rn = rn, .imm8 = imm8, .op = op }).encode();
    }
};

pub fn smaxi(rd: Reg, rn: Reg, imm8: u8) u32 {
    return ImmMinMax.init(rd, rn, imm8, ImmMinMax.Op.SMAX);
}

pub fn umaxi(rd: Reg, rn: Reg, imm8: u8) u32 {
    return ImmMinMax.init(rd, rn, imm8, ImmMinMax.Op.UMAX);
}

pub fn smini(rd: Reg, rn: Reg, imm8: u8) u32 {
    return ImmMinMax.init(rd, rn, imm8, ImmMinMax.Op.SMIN);
}

pub fn umini(rd: Reg, rn: Reg, imm8: u8) u32 {
    return ImmMinMax.init(rd, rn, imm8, ImmMinMax.Op.UMIN);
}

pub const ImmLogical = packed struct(u32) {
    const Self = @This();
    rd: Reg,
    rn: Reg,
    imms: u6,
    immr: u6,
    N: u1 = 0, // An extra bit of immediate only used in 64 bit mode.
    _: u6 = 0b100_100,
    op: Op,
    sf: u1 = MODE_A64,

    pub const Op = enum(u1) {
        AND = 0b00, // AND register and immediate. Write to destination register.
        ORR = 0b01, // Bitwise OR. Alias of MOV (bitmask immediate).
        EOR = 0b10, // Exclusive OR.
        ANDS = 0b11, // Bitwise AND, updates condition flags. Alias of TST immediate.
    };

    pub fn encode(self: Self) u32 {
        return @as(u32, @bitCast(self));
    }

    pub fn init(rd: Reg, rn: Reg, bitmask: u13, op: Op) u32 {
        // bitmask = N:imms:immr
        const imms: u6 = bitmask & 0b111111;
        const immr: u6 = (bitmask >> 6) & 0b111111;
        const N: u1 = (bitmask >> 12) & 0b1;

        return (Self{ .rd = rd, .rn = rn, .imms = imms, .immr = immr, .N = N, .op = op }).encode();
    }
};

pub fn andi(rd: Reg, rn: Reg, bitmask: u13) u32 {
    return ImmLogical.init(rd, rn, bitmask, ImmLogical.Op.AND);
}

pub fn orri(rd: Reg, rn: Reg, bitmask: u13) u32 {
    return ImmLogical.init(rd, rn, bitmask, ImmLogical.Op.ORR);
}

pub fn eori(rd: Reg, rn: Reg, bitmask: u13) u32 {
    return ImmLogical.init(rd, rn, bitmask, ImmLogical.Op.EOR);
}

pub fn andsi(rd: Reg, rn: Reg, bitmask: u13) u32 {
    return ImmLogical.init(rd, rn, bitmask, ImmLogical.Op.ANDS);
}

pub const ImmMovWide = packed struct(u32) {
    const Self = @This();
    rd: Reg,
    imm16: u16,
    hw: Shift = Shift.LSL_0,
    // Shift amount. 0X pattern for 32 bit mode, and 2 bits for 64 bit mode.
    // 0, 16, 32 or 48.
    _: u6 = 0b100_101,
    opc: Op,
    sf: u1 = MODE_A64,

    pub const Op = enum(u2) {
        MOVN = 0b00, // Move wide with NOT. Moves the inverse of the optionally-shifted 16 bit imm.
        MOVZ = 0b10, // Move wide with zero.
        MOVK = 0b11, // Move wide with keep. Keeps other bits unchanged in the register.
    };

    pub const Shift = enum(u2) {
        LSL_0 = 0b00,
        LSL_16 = 0b01,
        LSL_32 = 0b10, // 64 bit mode only.
        LSL_48 = 0b11, // 64 bit mode only
    };

    pub fn encode(self: Self) u32 {
        return @as(u32, @bitCast(self));
    }

    pub fn init(rd: Reg, imm16: u16, hw: Shift, op: Op) u32 {
        return (Self{ .rd = rd, .imm16 = imm16, .hw = hw, .opc = op }).encode();
    }
};

pub fn movn(rd: Reg, imm16: u16) u32 {
    return ImmMovWide.init(rd, imm16, ImmMovWide.Shift.LSL_0, ImmMovWide.Op.MOVN);
}

pub fn movz(rd: Reg, imm16: u16) u32 {
    return ImmMovWide.init(rd, imm16, ImmMovWide.Shift.LSL_0, ImmMovWide.Op.MOVZ);
}

pub fn movk(rd: Reg, imm16: u16) u32 {
    return ImmMovWide.init(rd, imm16, ImmMovWide.Shift.LSL_0, ImmMovWide.Op.MOVK);
}

pub const ImmBitfield = packed struct(u32) {
    const Self = @This();
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
    opc: Op,
    sf: u1 = MODE_A64,

    pub const Op = enum(u2) {
        SBFM = 0b00,
        BFM = 0b01,
        UBFM = 0b10,
    };

    pub fn encode(self: Self) u32 {
        return @as(u32, @bitCast(self));
    }
};
pub const ImmExtract = packed struct(u32) {
    const Self = @This();
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

    pub fn encode(self: Self) u32 {
        return @as(u32, @bitCast(self));
    }
};

////////////////////////////////////////////////////////////////////////////////
//           Branch, Exception Generating and System Instructions
////////////////////////////////////////////////////////////////////////////////

pub const BranchEncoding = union(enum) {
    BrConditional: BrConditional,
    MiscBranchImm: MiscBranchImm,
    CompareAndBranch: CompareAndBranch,
    ExceptionCall: ExceptionCall,
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
    const Self = @This();
    cond: Cond,
    op: Op,
    offset: u19, // PC Relative offset.
    _: u8 = 0b010_101_00,

    pub const Op = enum(u1) {
        B = 0, // Conditional branch to label at PC relative offset. hint that it's not a subroutine call or ret.
        BC = 1, // Feature - FEAT_HBC. Branch consistent conditionally. Hint that it's likely to branch consistently and is very unlikely to change direction.
    };

    pub fn encode(self: Self) u32 {
        return @as(u32, @bitCast(self));
    }

    pub fn init(cond: Cond, offset: u19, op: Op) u32 {
        return (Self{ .cond = cond, .op = op, .offset = offset }).encode();
    }
};

pub fn b(cond: Cond, offset: u19) u32 {
    return BrConditional.init(cond, offset, BrConditional.Op.B);
}

pub fn bc(cond: Cond, offset: u19) u32 {
    return BrConditional.init(cond, offset, BrConditional.Op.BC);
}

pub const MiscBranchImm = packed struct(u32) {
    // Return from subroutine with enhanced pointer auth using an immediate offset.
    // Authenticates the address in LR
    // SP - first modifier.
    // Imm value subtracted from SP as second mod.
    // and specified key (A or B based on instruction) and branches to the authenticated address.
    // With hint that it's a subroutine return.
    op2: u5 = 0b11111,
    offset: u16,
    opc: OpCode,
    _: u8 = 0b010_101_01,

    // Depends on FEAT_PAuth_LR
    pub const OpCode = enum(u3) {
        RETAASPPC = 0b000,
        RETABSPPC = 0b001,
    };
};

// Compare bytes/halfwords in registers and branch.
// Feature - FEAT_CMPBR
pub const CompareAndBranch = packed struct(u32) {
    const Self = @This();
    // Hints that not a subroutine call or ret.
    // Doesn't affect the condition flags.

    rt: Reg, // Test register.
    label: u9, // Label to branch to. Offset from PC, -1024 to 1020, as imm9 * 4.
    halfword: u1 = 0, // 0 = byte, 1 = halfword,
    _: u1 = 1,
    rm: Reg,
    cc: Op,
    __: u8 = 0b011_101_00,

    pub const Op = enum(u3) {
        GT = 0b000, // Greater than. ([N]eg and o[V]erflow flags)
        GE = 0b001, // Greater than or equal.
        HI = 0b010, // Unsigned higher. (CZ flags)
        HS = 0b011, // Unsigned Higher or same
        EQ = 0b110,
        NE = 0b111,
    };

    pub fn encode(self: Self) u32 {
        return @as(u32, @bitCast(self));
    }

    pub fn init(rt: Reg, rm: Reg, label: u9, halfword: u1, cc: Op) u32 {
        return (Self{ .rt = rt, .label = label, .halfword = halfword, .rm = rm, .cc = cc }).encode();
    }
};

pub fn cbb(rt: Reg, rm: Reg, label: u9, cc: CompareAndBranch.Op) u32 {
    return CompareAndBranch.init(rt, rm, label, 0, cc);
}

pub fn cbh(rt: Reg, rm: Reg, label: u9, cc: CompareAndBranch.Op) u32 {
    return CompareAndBranch.init(rt, rm, label, 1, cc);
}

// Exception Generation
pub const ExceptionCall = packed struct(u32) {
    const Self = @This();
    ll: u2,
    _: u3 = 0b000,
    imm16: u16,
    opc: u3,
    __: u8 = 0b110_101_00,

    pub const Op = enum {
        SVC, // Supervisor Call
        HVC, // Hypervisor Call
        SMC, // Secure Monitor Call - Trusted execution environment.
        BRK, // Breakpoint exception.
        HLT, // Halt instruction.
        TCANCEL, // Feature: FEAT_TME. Exit transactional state.
        DCPS1, // Debug change PE state to EL1
        DCPS2,
        DCPS3,

        pub fn encode(self: Op) struct { ll: u2, opc: u3 } {
            return switch (self) {
                .SVC => .{ .ll = 0b01, .opc = 0b000 },
                .HVC => .{ .ll = 0b10, .opc = 0b000 },
                .SMC => .{ .ll = 0b11, .opc = 0b000 },
                .BRK => .{ .ll = 0b00, .opc = 0b001 },
                .HLT => .{ .ll = 0b00, .opc = 0b010 },
                .TCANCEL => .{ .ll = 0b00, .opc = 0b11 },
                .DCPS1 => .{ .ll = 0b01, .opc = 0b101 },
                .DCPS2 => .{ .ll = 0b10, .opc = 0b101 },
                .DCPS3 => .{ .ll = 0b11, .opc = 0b101 },
            };
        }
    };

    pub fn encode(op: Op, imm: u16) u32 {
        const opcode = op.encode();
        return @as(u32, @bitCast(ExceptionCall{
            .ll = opcode.ll,
            .imm16 = imm,
            .opc = opcode.opc,
        }));
    }
};

pub fn svc(imm: platform.Syscall) u32 {
    return ExceptionCall.encode(ExceptionCall.Op.SVC, @intFromEnum(imm));
}

pub fn hvc(imm: u16) u32 {
    return ExceptionCall.encode(ExceptionCall.Op.HVC, imm);
}

pub fn brk(imm: u16) u32 {
    return ExceptionCall.encode(ExceptionCall.Op.BRK, imm);
}

pub fn hlt(imm: u16) u32 {
    return ExceptionCall.encode(ExceptionCall.Op.HLT, imm);
}

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

// // Add extended register
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

// pub const ADD_IMM = packed struct(u32) {
//     rd: Reg,
//     rn: Reg,
//     imm12: u12,
//     sh: u1 = 0, // 1 = LSL 12.
//     _: u8 = 0b00100010,
//     sf: u1 = MODE_A64, // 64-bit mode
// };

// pub const AND_IMM = packed struct(u32) {
//     rd: Reg,
//     rn: Reg,
//     // imms: u6,
//     // immr: u6,
//     // n: u1,
//     mask: u13, // 13 bits in 64 bit mode.
//     _: u8 = 0b0010_0100,
//     sf: u1 = 1,
// };

// // Supervisor Call - Syscalls, traps, etc.
pub const SVC = packed struct(u32) {
    pub const SYSCALL = 0x80;

    _base: u5 = 0b00001,
    imm16: u16,
    _svc: u11 = 0b11010100_000,
};

// const expect = std.testing.expect;

// test "Test MOV" {
//     const instr = MOVW_IMM{
//         .opc = MOVW_IMM.OpCode.MOVZ,
//         .imm16 = 42,
//         .rd = Reg.x0,
//     };

//     // Expected bytes in little endian.
//     try expect(std.mem.eql(u8, std.mem.asBytes(&instr), &[_]u8{ 0x40, 0x05, 0x80, 0xD2 }));

//     // Reference for how this instruction is decoded:
//     // 40 05 80 d2
//     // Little endian order:
//     // D2 80 05 40
//     // 11010010 1000 0000 0000 0101 0100 0000
//     // Decode:
//     // 110 [1001] 0 1000 0000 0000 0101 0100 0000
//     // 100x = data processing - immediate
//     // 110 100[101] 000 0000 0000 0101 0100 0000
//     // 101 = Move wide immediate
//     // [1][10] [100101] [00] [0 0000 0000 0101 010 [0 0000]
//     // SF = 1
//     // OPC = 10
//     // 100101
//     // HW = 00
//     // IMM16 = 0000000000101010 = 42!
//     // Rd = x0
// }
