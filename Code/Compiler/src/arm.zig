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
    x31 = 31, // WZR
};
const WZR = Reg.x31;

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

///////////////////////////////////////////////////////////////////////////////
///
///
///                     Data Processing - Immediate
///
///
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

pub const AddSubOp = enum(u1) {
    ADD = 0,
    SUB = 1,
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
    op: AddSubOp,
    mode: u1 = MODE_A64, //

    pub fn encode(self: Self) u32 {
        return @as(u32, @bitCast(self));
    }

    pub fn init(rd: Reg, rn: Reg, imm12: u12, op: AddSubOp) u32 {
        return (Self{ .rd = rd, .rn = rn, .imm12 = imm12, .op = op }).encode();
    }
};

pub fn addi(rd: Reg, rn: Reg, imm12: u12) u32 {
    return ImmAddSub.init(rd, rn, imm12, AddSubOp.ADD);
}

pub fn subi(rd: Reg, rn: Reg, imm12: u12) u32 {
    return ImmAddSub.init(rd, rn, imm12, AddSubOp.SUB);
}

pub const ImmAddSubTags = packed struct(u32) {
    // Used for adding to memory with memory tagging for protection checks.
    // Depends on FEAT_MTE Feature. Optional 8.4+. 64 bit only.
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
    // Depends on FEAT_CSSC Feature. Optional in 8.7. Mandatory from 8.9
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
    hw: ShiftAmt = ShiftAmt.LSL_0,
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

    pub const ShiftAmt = enum(u2) {
        LSL_0 = 0b00,
        LSL_16 = 0b01,
        LSL_32 = 0b10, // 64 bit mode only.
        LSL_48 = 0b11, // 64 bit mode only
    };

    pub fn encode(self: Self) u32 {
        return @as(u32, @bitCast(self));
    }

    pub fn init(rd: Reg, imm16: u16, hw: ShiftAmt, op: Op) u32 {
        return (Self{ .rd = rd, .imm16 = imm16, .hw = hw, .opc = op }).encode();
    }
};

pub fn movn(rd: Reg, imm16: u16) u32 {
    return ImmMovWide.init(rd, imm16, ImmMovWide.ShiftAmt.LSL_0, ImmMovWide.Op.MOVN);
}

pub fn movz(rd: Reg, imm16: u16) u32 {
    return ImmMovWide.init(rd, imm16, ImmMovWide.ShiftAmt.LSL_0, ImmMovWide.Op.MOVZ);
}

pub fn movk(rd: Reg, imm16: u16) u32 {
    return ImmMovWide.init(rd, imm16, ImmMovWide.ShiftAmt.LSL_0, ImmMovWide.Op.MOVK);
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
///
///
///           Branch, Exception Generating and System Instructions
///
///
////////////////////////////////////////////////////////////////////////////////

pub const BranchEncoding = union(enum) {
    BrConditional: BrConditional,
    MiscBranchImm: MiscBranchImm,
    CompareRegAndBranch: CompareRegAndBranch,
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

pub const Comparison = enum(u3) {
    GT = 0b000, // Greater than. ([N]eg and o[V]erflow flags)
    GE = 0b001, // Greater than or equal.
    HI = 0b010, // Unsigned higher. (CZ flags)
    HS = 0b011, // Unsigned Higher or same
    EQ = 0b110,
    NE = 0b111,
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

// ie beq, bne, etc.
pub fn b_cond(cond: Cond, offset: u19) u32 {
    return BrConditional.init(cond, offset, BrConditional.Op.B);
}

pub fn bc_cond(cond: Cond, offset: u19) u32 {
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
pub const CompareBytesAndBranch = packed struct(u32) {
    const Self = @This();
    // Hints that not a subroutine call or ret.
    // Doesn't affect the condition flags.

    rt: Reg, // Test register.
    label: u9, // Label to branch to. Offset from PC, -1024 to 1020, as imm9 * 4.
    halfword: u1 = 0, // 0 = byte, 1 = halfword,
    _: u1 = 1,
    rm: Reg,
    cc: Comparison,
    __: u8 = 0b011_101_00,

    pub fn encode(self: Self) u32 {
        return @as(u32, @bitCast(self));
    }

    pub fn init(rt: Reg, rm: Reg, label: u9, halfword: u1, cc: Comparison) u32 {
        return (Self{ .rt = rt, .label = label, .halfword = halfword, .rm = rm, .cc = cc }).encode();
    }
};

pub fn cbb(rt: Reg, rm: Reg, label: u9, cc: Comparison) u32 {
    return CompareBytesAndBranch.init(rt, rm, label, 0, cc);
}

pub fn cbh(rt: Reg, rm: Reg, label: u9, cc: Comparison) u32 {
    return CompareBytesAndBranch.init(rt, rm, label, 1, cc);
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

pub fn svc(imm: u16) u32 {
    // Verify what should be in IMM. Some places reference 0x80? Other tables mention 0.
    // https://github.com/darlinghq/darling/discussions/1376
    return ExceptionCall.encode(ExceptionCall.Op.SVC, imm);
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

// System instructions with register argument.
pub const SysRegCalls = packed struct(u32) {
    const Self = @This();
    rt: Reg,
    op: Op,
    crm: u4 = 0b0000, // Fixed constant for current instructions.
    _: 0b110_101_01_0000_0011_0001,

    // Feature - FEAT_WFxT
    pub const Op = enum(u3) {
        WFET = 0b000, // Wait for event with timeout.
        WFIT = 0b001, // Wait for interrupt with timeout.
    };

    pub fn encode(self: Self) u32 {
        return @as(u32, @bitCast(self));
    }

    pub fn init(rt: Reg, op: Op) u32 {
        return (Self{ .rt = rt, .op = op }).encode();
    }
};

pub fn wfet(rt: Reg) u32 {
    return SysRegCalls.init(rt, SysRegCalls.Op.WFET);
}

pub fn wfit(rt: Reg) u32 {
    return SysRegCalls.init(rt, SysRegCalls.Op.WFIT);
}

// Hints
pub const SystemHint = packed struct(u32) {
    const Self = @This();
    _: 0b11111,
    op2: u3,
    CRm: u4,
    __: u20 = 0b110_101_01_0000_0011_0010,

    pub const Op = enum {
        NOP, // No-Op.
        YIELD, // Yield processor.
        WFE, // Wait for event.
        WFI, // Wait for interrupt.
        SEV, // Send Event.
        SEVL, // Send Event Local.
        DGH, // Data Gathering Hint. FEAT_DGH
        // XPAC,
        // PACIA, // Skipped.
        // PACIB,
        // AUTIA,
        // AUTIB,
        ESB, // Error Synchronization Barrier. FEAT_RAS
        PSB, // Profile Synchronization Barrier. FEAT_SPE
        TSB, // Trace Synchronization Barrier. FEAT_TRF
        GCSB, // Guarded Control Stack barrier. FEAT_GCS
        CSDB, // Consumption of speculative data barrier.
        CLRBHB, // Clear Branch History. Feature - FEAT_CLRBHB
        // BTI, // Handled separately.
        PACM, // Pointer Auth Modifier - Feature - FEAT_PAuth_LR
        CHKFEAT, // Check Feature Status. Feature - FEAT_CHK
        // STSHH, // Handled separately.
        // PACIA,

        pub fn encode(self: Op) struct { crm: u4, op2: u3 } {
            switch (self) {
                .NOP => .{
                    .crm = 0b0000,
                    .op2 = 0b000,
                },
                .YIELD => .{
                    .crm = 0b0000,
                    .op2 = 0b001,
                },
                .WFE => .{
                    .crm = 0b0000,
                    .op2 = 0b010,
                },
                .WFI => .{
                    .crm = 0b0000,
                    .op2 = 0b011,
                },
                .SEV => .{
                    .crm = 0b0000,
                    .op2 = 0b100,
                },
                .SEVL => .{
                    .crm = 0b0000,
                    .op2 = 0b101,
                },
                .DGH => .{
                    .crm = 0b0000,
                    .op2 = 0b110,
                },
                .XPAC => .{
                    .crm = 0b0000,
                    .op2 = 0b111,
                },
                // Skipping over PACIA, PACIB, AUTIA, AUTIB, ones. Not sure how those hints are meant to work.
                .ESB => .{
                    .crm = 0b0010,
                    .op2 = 0b000,
                },
                .PSB => .{
                    .crm = 0b0010,
                    .op2 = 0b001,
                },
                .TSB => .{
                    .crm = 0b0010,
                    .op2 = 0b010,
                },
                .GCSB => .{
                    .crm = 0b0010,
                    .op2 = 0b011,
                },
                .CSDB => .{
                    .crm = 0b0010,
                    .op2 = 0b100,
                },
                .CLRBHB => .{
                    .crm = 0b0010,
                    .op2 = 0b110,
                },
                .PACM => .{
                    .crm = 0b0100,
                    .op2 = 0b111,
                },
                .CHKFEAT => .{
                    .crm = 0b0101,
                    .op2 = 0b000,
                },
            }
        }
    };

    pub fn encode(op: Op) u32 {
        const opcode = op.encode();
        return @as(u32, @bitCast(SystemHint{
            .crm = opcode.crm,
            .op2 = opcode.op2,
        }));
    }
};

pub fn nop() u32 {
    return SystemHint.encode(SystemHint.Op.NOP);
}

pub fn yield() u32 {
    return SystemHint.encode(SystemHint.Op.YIELD);
}

pub fn wfe() u32 {
    return SystemHint.encode(SystemHint.Op.WFE);
}

pub fn wfi() u32 {
    return SystemHint.encode(SystemHint.Op.WFI);
}

pub fn chkfeat() u32 {
    return SystemHint.encode(SystemHint.Op.CHKFEAT);
}

pub const BTITarget = enum(u3) {
    // Test
    absent = 0b000,
    c = 0b010,
    j = 0b100,
    jc = 0b110,
};

// Feature - FEAT_BTI
// Branch Target Identification for indirect branch targets.
pub fn bti(target: BTITarget) u32 {
    return @as(u32, @bitCast(SystemHint{
        .crm = 0b0100,
        .op2 = @intFromEnum(target),
    }));
}

pub const StoreSharedHint = enum(u3) {
    KEEP = 0b000,
    STRM = 0b001,
};

// Feature - FEAT_PCDPHINT
pub fn stshh(hint: StoreSharedHint) u32 {
    return @as(u32, @bitCast(SystemHint{
        .crm = 0b0110,
        .op2 = @intFromEnum(hint),
    }));
}

// Barrier Instructions
pub const Barrier = packed struct(u32) {
    const Self = @This();
    rt: u5 = 0b11111,
    op2: u3,
    crm: u4,
    _: 0b110_101_01_0000_0011_0011,

    pub const Op = enum {
        CLREX,
        // https://developer.arm.com/documentation/ddi0602/2024-12/Base-Instructions/DSB--Data-synchronization-barrier-?lang=en#DSB_BOn_barriers
        // DSB, // TODO: There's a lot of details to this
        // DMB,
        ISB, // Instruction Synchronization Barrier.
        SB, // Speculation Barrier. FEAT_SB
        // DSB,
        // TCOMMIT,

        pub fn encode(self: Op) struct { crm: u4, op2: u3 } {
            switch (self) {
                .CLREX => .{ .crm = 0b0000, .op2 = 0b010 }, // CRm ignored.
                .ISB => .{ .crm = 0b1111, .op2 = 0b110 }, // CRm = 1111 for SY - full system barrier op.
                .SB => .{ .crm = 0b0000, .op2 = 0b111 },
            }
        }
    };
};

pub const PState = packed struct(u32) {
    const Self = @This();
    rt: u5 = 0b11111,
    op2: u3,
    CRm: u4,
    __: 0b0100,
    op1: u3,
    _: u13 = 0b110_101_01_00000,

    pub const Op = enum {
        CFINV, // FEAT_FlagM. Invert carry flag.
        XAFLAG, // FEAT_FlagM2. Convert float condition flags from external to arm format.
        AXFLAG, // FEAT_FlagM2. Convert float condition flags from arm to external format.

        pub fn encode(self: Op) struct { op1: u3, op2: u3 } {
            switch (self) {
                .CFINV => .{ .op1 = 0b000, .op2 = 0b000 },
                .XAFLAG => .{ .op1 = 0b000, .op2 = 0b001 },
                .AXFLAG => .{ .op1 = 0b000, .op2 = 0b010 },
            }
        }
    };

    pub fn encode(op: Op) u32 {
        const opcode = op.encode();
        return @as(u32, @bitCast(PState{
            .op1 = opcode.op1,
            .op2 = opcode.op2,
        }));
    }
};

// pub fn msr() u32 {
//     // TODO: Implement this.
//     // https://developer.arm.com/documentation/ddi0602/2024-12/Base-Instructions/MSR--immediate---Move-immediate-value-to-special-register-?lang=en
//     return 0;
// }

pub fn cfinv() u32 {
    return PState.encode(PState.Op.CFINV);
}

pub fn xaflag() u32 {
    return PState.encode(PState.Op.XAFLAG);
}

pub fn axflag() u32 {
    return PState.encode(PState.Op.AXFLAG);
}

// Skipping over System instructions.
// TODO: MSR

// Unconditional branch (register).
pub const BranchRegister = packed struct(u32) {
    //
    const Self = @This();
    op4: u4 = 0b0000,
    Rn: u5,
    op3: u6 = 0b000000,
    op2: u5 = 0b11111,
    opc: u4,
    _: u7 = 0b110_101_1,

    pub const Op = enum(u4) {
        BR = 0b0000, // Branch to register.
        BLR = 0b0001, // Branch with link to register. Sets X30 to PC+4
        RET = 0b0010, // Subroutine return. Defaults to X30.
        ERET = 0b0100, // Exception return
        DRPS = 0b0101, // Debug Restore PE state.
    };

    pub fn encode(op: Op, rn: u5) u32 {
        const opcode = op.encode();
        return @as(u32, @bitCast(BranchRegister{
            .op4 = opcode.op4,
            .Rn = rn,
            .op3 = opcode.op3,
            .op2 = 0b11111,
            .opc = opcode.opc,
        }));
    }
};

pub fn br(rn: Reg) u32 {
    return BranchRegister.encode(BranchRegister.Op.BR, @intFromEnum(rn));
}

pub fn blr(rn: Reg) u32 {
    return BranchRegister.encode(BranchRegister.Op.BLR, @intFromEnum(rn));
}

pub fn ret(rn: Reg) u32 {
    return BranchRegister.encode(BranchRegister.Op.RET, @intFromEnum(rn));
}

pub fn eret() u32 {
    return BranchRegister.encode(BranchRegister.Op.ERET, 0b11111);
}

pub fn drps() u32 {
    return BranchRegister.encode(BranchRegister.Op.DRPS, 0b11111);
}

pub const UnconditionalBranchImm = packed struct(u32) {
    const Self = @This();
    imm26: u26,
    _: 0b00101,
    op: Op,

    pub const Op = enum(u1) {
        B = 0, // Branch to PC relative offset, hint not subroutine.
        BL = 1, // Branch with link to PC-relative offset, setting X30 to PC+4. Hint subroutine.
    };
};

pub fn b(imm26: u26) u32 {
    return @as(u32, @bitCast(UnconditionalBranchImm{
        .imm26 = imm26,
        .op = UnconditionalBranchImm.Op.B,
    }));
}

pub fn bl(imm26: u26) u32 {
    return @as(u32, @bitCast(UnconditionalBranchImm{
        .imm26 = imm26,
        .op = UnconditionalBranchImm.Op.BL,
    }));
}

pub const CompareBranchImm = packed struct(u32) {
    const Self = @This();
    rt: Reg,
    imm19: u19,
    op: Op,
    _: u6 = 0b011_010,
    sf: u1 = MODE_A64,

    pub const Op = enum(u1) {
        CBZ = 0, // Branch if reg = 0.
        CBNZ = 1,
    };

    pub fn encode(self: Self) u32 {
        return @as(u32, @bitCast(self));
    }

    pub fn init(rt: Reg, imm19: u19, op: Op) u32 {
        return @as(u32, @bitCast(CompareBranchImm{
            .rt = @intFromEnum(rt),
            .imm19 = imm19,
            .op = op,
        }));
    }
};

pub fn cbz(rt: Reg, imm19: u19) u32 {
    return CompareBranchImm.init(rt, imm19, CompareBranchImm.Op.CBZ);
}

pub fn cbnz(rt: Reg, imm19: u19) u32 {
    return CompareBranchImm.init(rt, imm19, CompareBranchImm.Op.CBNZ);
}

pub const TestAndBranchImm = packed struct(u32) {
    const Self = @This();
    rt: u5,
    imm14: u14, // PC relative offset. +/- 32KB. IMM14*4
    b40: u5,
    op: u1,
    _: u6 = 0b011_011,
    b5: u1 = 0, // 0-W, 1-X, Only permitted when bit-number is less than 32.

    // Doesn't set condition flags. Hints not subroutine.
    pub const Op = enum(u1) {
        TBZ = 0, // Test bit and branch PC-rel offset if zero.
        TBNZ = 1,
    };

    pub fn init(rt: Reg, bitnum: u6, label: u14, op: Op) u32 {
        // bitnum = b5:b40
        const b40 = bitnum & 0b11111;
        const b5 = (bitnum & 0b100000) >> 5;

        return @as(u32, @bitCast(TestAndBranchImm{
            .rt = @intFromEnum(rt),
            .imm14 = label,
            .b40 = b40,
            .op = @intFromEnum(op),
            .b5 = b5,
        }));
    }
};

pub fn tbz(rt: Reg, bitnum: u6, label: u14) u32 {
    return TestAndBranchImm.init(rt, bitnum, label, TestAndBranchImm.Op.TBZ);
}

pub fn tbnz(rt: Reg, bitnum: u6, label: u14) u32 {
    return TestAndBranchImm.init(rt, bitnum, label, TestAndBranchImm.Op.TBNZ);
}

pub const CompareRegAndBranch = packed struct(u32) {
    const Self = @This();
    rt: Reg,
    imm9: u9,
    _: u2 = 0b00,
    rm: Reg,
    cc: Comparison,
    __: u7 = 0b111_0100,
    sf: u1 = MODE_A64,

    pub fn encode(self: Self) u32 {
        return @as(u32, @bitCast(self));
    }

    pub fn init(rt: Reg, cc: Comparison, rm: Reg, offset: u9) u32 {
        return @as(u32, @bitCast(CompareRegAndBranch{
            .rt = rt,
            .imm9 = offset,
            .rm = rm,
            .cc = cc,
        }));
    }
};

pub fn cb(rt: Reg, cc: Comparison, rm: Reg, offset: u9) u32 {
    return CompareRegAndBranch.init(rt, cc, rm, offset);
}

// Feature - FEAT_CMPBR
pub const CompareImmediate = packed struct(u32) {
    const Self = @This();
    rt: Reg, // Test
    offset: u9, // Offset relative to this instruction. -1024 to 1020. imm9 * 4
    _: u1 = 0,
    imm: u6, // Unsigned immediate 0-63.
    cc: Comparison,
    __: u7 = 0b1110_101,
    sf: u1 = MODE_A64,

    pub fn encode(self: Self) u32 {
        return @as(u32, @bitCast(self));
    }

    pub fn init(rt: Reg, imm: u6, cc: Comparison, offset: u9) u32 {
        return @as(u32, @bitCast(CompareImmediate{
            .rt = rt,
            .offset = offset,
            .imm = imm,
            .cc = cc,
        }));
    }
};

pub fn cmi(rt: Reg, imm: u6, cc: Comparison, offset: u9) u32 {
    return CompareImmediate.init(rt, imm, cc, offset);
}

///////////////////////////////////////////////////////////////////////////////
///
///                         Data Processing - Register
///                     [op0 2][op1 2]101[op2 9][op3 16]
///
///////////////////////////////////////////////////////////////////////////////

// Data Processing - 2 Sources
pub const ProcessTwoSource = packed struct(u32) {
    const Self = @This();
    rd: Reg,
    rn: Reg,
    opcode: Op,
    rm: Reg,
    _: u8 = 0b1101_0110,
    s: u1 = 0, // 1 only for SUBPS
    sf: u1 = MODE_A64,

    pub const Op = enum(u6) {
        UDIV = 0b000010,
        SDIV = 0b000011,
        LSLV = 0b001000, // Logical shift left variable by number of bits, shifting in zeroes.
        LSRV = 0b001001,
        ASRV = 0b001010, // Arithmetic shift. Copy sign bit.
        RORV = 0b001011, // Rotate right variable off right end and insert to left end.
        // CRC32 - Optional instruction in arm v8. Skipped.
        // SMAX, UMAX, SMIN, UMIN          // Signed maximum. FEAT_CSSC. Optional from 8.7.
        // SUBP - Skip - FEAT_MTE
    };

    pub fn encode(self: Self) u32 {
        return @as(u32, @bitCast(self));
    }

    pub fn init(opcode: Op, rd: Reg, rn: Reg, rm: Reg) Self {
        return ProcessTwoSource{
            .rd = rd,
            .rn = rn,
            .opcode = opcode,
            .rm = rm,
        };
    }
};

pub fn udiv(rd: Reg, rn: Reg, rm: Reg) u32 {
    return ProcessTwoSource.init(ProcessTwoSource.Op.UDIV, rd, rn, rm).encode();
}

pub fn sdiv(rd: Reg, rn: Reg, rm: Reg) u32 {
    return ProcessTwoSource.init(ProcessTwoSource.Op.SDIV, rd, rn, rm).encode();
}

pub fn lslv(rd: Reg, rn: Reg, rm: Reg) u32 {
    return ProcessTwoSource.init(ProcessTwoSource.Op.LSLV, rd, rn, rm).encode();
}

pub fn lsrv(rd: Reg, rn: Reg, rm: Reg) u32 {
    return ProcessTwoSource.init(ProcessTwoSource.Op.LSRV, rd, rn, rm).encode();
}

pub fn asrv(rd: Reg, rn: Reg, rm: Reg) u32 {
    return ProcessTwoSource.init(ProcessTwoSource.Op.ASRV, rd, rn, rm).encode();
}

pub fn rorv(rd: Reg, rn: Reg, rm: Reg) u32 {
    return ProcessTwoSource.init(ProcessTwoSource.Op.RORV, rd, rn, rm).encode();
}

pub const ProcessOneSource = packed struct(u32) {
    rd: Reg,
    rn: Reg,
    opcode: Op,
    // op2, S fields are Baked into the constant below. Doesn't vary for the instructions we use.
    _: u15 = 0b10_1101_0110_00000,
    sf: u1 = MODE_A64,

    pub const Op = enum(u6) {
        RBIT = 0, // Reverse bit order in a register.
        REV16 = 0b000001, // Reverse bytes in each 16-bit halfwords of a reg.
        REV = 0b00010, // Reverse bytes.
        CLZ = 0b000100, // Count leading zeroes, starting from MSB.
        CLS = 0b000101, // Count leading sign bits (same value as MSB). Count doesn't include the MSB.
        // CTZ, CNT, ABS - FEAT_CSSC
    };
};

pub const ShiftType = enum(u2) {
    LSL = 0,
    LSR = 1,
    ASR = 2,
    ROR = 3,
};

pub const LogicalShiftedRegister = packed struct(u32) {
    rd: Reg,
    rn: Reg,
    imm6: u6,
    rm: Reg,
    N: u1, // Negate.
    shift: ShiftType,
    _: u5 = 0b01010,
    opc: u2,
    sf: u1 = MODE_A64,

    pub const Op = enum {
        AND,
        BIC, // Bitwise clear. AND with complement of optionally shifted rM
        ORR, // Bitwise or. OR with optionally shifted rM. MOV alias.
        ORN, // OR with complement of optionally shifted rM. MVN alias.
        EOR, // Exclusive OR.
        EON,
        ANDS, // And shifted, setting flags. alias TST.
        BICS, // Bitwise clear (AND w/ NOT of shifted rM ), setting condition flags.

        pub fn encode(self: Op) struct { opc: u2, N: u1 } {
            switch (self) {
                .AND => .{ .opc = 0b00, .N = 0 },
                .BIC => .{ .opc = 0b00, .N = 1 },
                .ORR => .{ .opc = 0b01, .N = 0 },
                .ORN => .{ .opc = 0b01, .N = 1 },
                .EOR => .{ .opc = 0b10, .N = 0 },
                .EON => .{ .opc = 0b10, .N = 1 },
                .ANDS => .{ .opc = 0b11, .N = 0 },
                .BICS => .{ .opc = 0b11, .N = 1 },
            }
        }
    };

    pub fn init(op: Op, rd: Reg, rn: Reg, rm: Reg, shift: ShiftType, amt: u6) u32 {
        const opcode = op.encode();
        return @as(u32, @bitCast(LogicalShiftedRegister{
            .rd = rd,
            .rn = rn,
            .imm6 = amt,
            .rm = rm,
            .N = opcode.N,
            .shift = shift,
            .opc = opcode.opc,
        }));
    }
};

// 'andd' since and is a reserved keyword.
pub fn andd(rd: Reg, rn: Reg, rm: Reg) u32 {
    return LogicalShiftedRegister.init(LogicalShiftedRegister.Op.AND, rd, rn, rm, ShiftType.LSL, 0);
}

pub fn bic(rd: Reg, rn: Reg, rm: Reg) u32 {
    return LogicalShiftedRegister.init(LogicalShiftedRegister.Op.BIC, rd, rn, rm, ShiftType.LSL, 0);
}

pub fn orr(rd: Reg, rn: Reg, rm: Reg) u32 {
    return LogicalShiftedRegister.init(LogicalShiftedRegister.Op.ORR, rd, rn, rm, ShiftType.LSL, 0);
}

pub fn orn(rd: Reg, rn: Reg, rm: Reg) u32 {
    return LogicalShiftedRegister.init(LogicalShiftedRegister.Op.ORN, rd, rn, rm, ShiftType.LSL, 0);
}

pub fn eor(rd: Reg, rn: Reg, rm: Reg) u32 {
    return LogicalShiftedRegister.init(LogicalShiftedRegister.Op.EOR, rd, rn, rm, ShiftType.LSL, 0);
}

pub fn eon(rd: Reg, rn: Reg, rm: Reg) u32 {
    return LogicalShiftedRegister.init(LogicalShiftedRegister.Op.EON, rd, rn, rm, ShiftType.LSL, 0);
}

pub fn ands(rd: Reg, rn: Reg, rm: Reg) u32 {
    return LogicalShiftedRegister.init(LogicalShiftedRegister.Op.ANDS, rd, rn, rm, ShiftType.LSL, 0);
}

pub fn bics(rd: Reg, rn: Reg, rm: Reg) u32 {
    return LogicalShiftedRegister.init(LogicalShiftedRegister.Op.BICS, rd, rn, rm, ShiftType.LSL, 0);
}

pub const AddSubShiftedReg = packed struct(u32) {
    rd: Reg,
    rn: Reg,
    imm6: u6,
    rm: Reg,
    __: u1 = 0,
    shift: ShiftType = ShiftType.LSL, // ROR is not available.
    _: u5 = 0b01011,
    S: u1, // Set flats
    op: AddSubOp,
    sf: u1 = MODE_A64,

    pub fn init(op: AddSubOp, rd: Reg, rn: Reg, rm: Reg, shift: ShiftType, amt: u6, setFlags: u1) u32 {
        return @as(u32, @bitCast(AddSubShiftedReg{
            .rd = rd,
            .rn = rn,
            .imm6 = amt,
            .rm = rm,
            .S = setFlags,
            .shift = shift,
            .op = op,
        }));
    }
};

pub fn add(rd: Reg, rn: Reg, rm: Reg) u32 {
    return AddSubShiftedReg.init(AddSubOp.ADD, rd, rn, rm, ShiftType.LSL, 0, 0);
}

pub fn adds(rd: Reg, rn: Reg, rm: Reg) u32 {
    return AddSubShiftedReg.init(AddSubOp.ADD, rd, rn, rm, ShiftType.LSL, 0, 1);
}

pub fn sub(rd: Reg, rn: Reg, rm: Reg) u32 {
    return AddSubShiftedReg.init(AddSubOp.SUB, rd, rn, rm, ShiftType.LSL, 0, 0);
}

pub fn subs(rd: Reg, rn: Reg, rm: Reg) u32 {
    return AddSubShiftedReg.init(AddSubOp.SUB, rd, rn, rm, ShiftType.LSL, 0, 1);
}

pub const AddSubExtendedReg = packed struct(u32) {
    rd: Reg,
    rn: Reg,
    imm3: u3,
    option: u3,
    rm: Reg,
    __: u1 = 1,
    opt: u2,
    _: u5 = 0b01011,
    S: u1,
    op: AddSubOp,
    sf: u1 = MODE_A64,

    pub const Op = enum(u1) {
        ADD = 0,
        SUB = 1,
    };
};

pub const AddSubWithCarry = packed struct(u32) {
    rd: Reg,
    rn: Reg,
    _: u6 = 0, // Fixed
    rm: Reg,
    __: u8 = 0b11010000,
    S: u1 = 0,
    op: AddSubOp,
    sf: u1 = MODE_A64,
};

// Conditional compare register

pub const CondCompareReg = packed struct(u32) {
    nzcv: u4,
    o3: u1 = 0,
    rn: Reg,
    o2: u1 = 0,
    __: u1 = 0,
    cond: Cond,
    rm: Reg,
    _: u8 = 0b1101_0010,
    S: u1 = 1,
    op: Op,
    sf: u1 = MODE_A64,

    pub const Op = enum(u1) {
        CCMN = 0,
        CCMP = 1,
    };
};

pub const CondCompareImm = packed struct(u32) {
    // Basically the same as above just with immediate value in imm5 rather than reg,
    // and the flag right before set to 1
    nzcv: u4,
    o3: u1 = 0,
    rn: Reg,
    o2: u1 = 0,
    __: u1 = 1, // immediate flag.
    cond: Cond,
    imm5: u5,
    _: u8 = 0b1101_0010,
    S: u1 = 1,
    sf: u1 = MODE_A64,
};

pub const ConditionalSelect = packed struct(u32) {
    //
    rd: Reg,
    rn: Reg,
    op2: u2,
    cond: Cond,
    rm: Reg,
    _: u8 = 0b1101_0100,
    S: u1 = 1,
    op: u1,
    sf: u1 = MODE_A64,

    pub const Op = enum {
        CSEL,
        CSINC,
        CSINV,
        CSNEG,

        pub fn encode(self: Op) struct { op: u1, op2: u2 } {
            return switch (self) {
                .CSEL => .{ .op = 0, .op2 = 0b00 },
                .CSINC => .{ .op = 0, .op2 = 0b01 },
                .CSINV => .{ .op = 1, .op2 = 0b00 },
                .CSNEG => .{ .op = 1, .op2 = 0b01 },
            };
        }
    };
};

pub const ProcessThreeSource = packed struct(u32) {
    const Self = @This();
    rd: Reg,
    rn: Reg,
    ra: Reg,
    o0: u1,
    rm: Reg,
    op31: u3,
    _: u5 = 0b00_11011, // Unused op54 bits combined into this.
    sf: u1 = MODE_A64,

    pub const Op = enum {
        MADD,
        MSUB,
        SMADDL, // Signed multiply add long
        SMSUBL,
        SMULH, // Signed multiply high
        UMADDL,
        UMSUBL,
        UMULH,

        pub fn encode(self: Op) struct { op31: u3, op0: u1 } {
            return switch (self) {
                .MADD => .{ .op31 = 0b000, .op0 = 0 },
                .MSUB => .{ .op31 = 0b000, .op0 = 1 },
                .SMADDL => .{ .op31 = 0b001, .op0 = 0 },
                .SMSUBL => .{ .op31 = 0b001, .op0 = 1 },
                .SMULH => .{ .op31 = 0b010, .op0 = 0 },
                .UMADDL => .{ .op31 = 0b101, .op0 = 0 },
                .UMSUBL => .{ .op31 = 0b101, .op0 = 1 },
                .UMULH => .{ .op31 = 0b110, .op0 = 0 },
            };
        }
    };

    pub fn init(op: Op, rd: Reg, rn: Reg, rm: Reg, ra: Reg) Self {
        const opcode = op.encode();
        return Self{
            .rd = rd,
            .rn = rn,
            .ra = ra,
            .o0 = opcode.op0,
            .rm = rm,
            .op31 = opcode.op31,
        };
    }
};

pub fn mul(rd: Reg, rn: Reg, rm: Reg) u32 {
    return ProcessThreeSource.init(ProcessThreeSource.Op.MADD, rd, rn, rm, WZR);
}

pub const RegisterEncoding = packed struct(u32) { _: u32 };
pub const FloatEncoding = packed struct(u32) { _: u32 };
pub const LoadStoreEncoding = packed struct(u32) { _: u32 };

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
const test_allocator = std.testing.allocator;
const expect = std.testing.expect;
const expectEqual = std.testing.expectEqual;
const macho = @import("macho.zig");
const print = std.debug.print;

const exitSeq = &[_]u32{ movz(Reg.x16, 1), svc(0) };

fn exitCodeTest(code: []const u32) !u32 {
    // Create an executable with the given assembly code.
    // Execute it and check the exit code.

    var linker = macho.MachOLinker.init(test_allocator);
    defer linker.deinit();
    try linker.emitBinary(code, "test.bin");

    // Execute the binary file
    const cwd = std.fs.cwd();
    var out_buffer: [1024]u8 = undefined;
    const path = try cwd.realpath("test.bin", &out_buffer);

    var process = std.process.Child.init(&[_][]const u8{path}, test_allocator);

    const termination = try process.spawnAndWait();
    // print("Terminated with : {any}\n", .{termination});

    defer {
        // std.fs.cwd().deleteFile("test.bin");
        // Free the memory for cwd
        // test_allocator.free(cwd);
        // if (process.stdout) |stdout| {
        //     test_allocator.free(stdout);
        // }
        // if (process.stderr) |stderr| {
        //     test_allocator.free(stderr);
        // }
    }

    switch (termination) {
        .Exited => |exitcode| return exitcode,
        .Signal => |sig| return sig,
        .Stopped => |_| return 999,
        .Unknown => |_| return 999,
    }
}

test "exit code test" {
    const exitCode = exitCodeTest(&[_]u32{
        movz(Reg.x0, 42),
        movz(Reg.x16, 1),
        svc(0),
    });

    try expectEqual(exitCode, 42);
}
