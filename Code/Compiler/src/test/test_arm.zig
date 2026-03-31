const std = @import("std");
const arm = @import("../arm.zig");

const Reg = arm.Reg;
const movz = arm.movz;
const adrp = arm.adrp;
const addi = arm.addi;
const svc = arm.svc;
const expectEqual = std.testing.expectEqual;

test "print" {
    const printAsm = arm.exitCodeTest(std.testing.io, &[_]u32{
        movz(Reg.x0, 1), // File descriptor - stdout
        adrp(Reg.x1, 0), // TODO: What should be this address? 0x1000_03000
        // TODO: LDR x1, [x1, hello_world]
        addi(Reg.x1, Reg.x1, 0xfd4), // 0xf84 -> my version
        movz(Reg.x2, 15), // String length
        movz(Reg.x16, 4),
        svc(0x80),
        movz(Reg.x0, 0x2a),
        movz(Reg.x16, 1),
        svc(0x80),
    });

    try expectEqual(42, printAsm);
}
