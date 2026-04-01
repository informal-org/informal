const std = @import("std");
const arm = @import("../arm.zig");

const Reg = arm.Reg;
const movz = arm.movz;
const adrp = arm.adrp;
const addi = arm.addi;
const svc = arm.svc;
const expectEqual = std.testing.expectEqual;

const macho = @import("../macho.zig");
const StringArrayHashMap = std.array_hash_map.StringArrayHashMap;
const test_allocator = std.testing.allocator;

fn exitCodeTest(io: std.Io, code: []const u32) !u32 {
    var linker = macho.MachOLinker.init(test_allocator);
    var internedStrings = StringArrayHashMap(u64).init(test_allocator);
    defer internedStrings.deinit();

    defer linker.deinit();
    try linker.emitBinary(io, code, &internedStrings, 0, "test.bin");

    const run_result = try std.process.run(test_allocator, io, .{
        .argv = &[_][]const u8{"./test.bin"},
    });
    defer test_allocator.free(run_result.stdout);
    defer test_allocator.free(run_result.stderr);

    switch (run_result.term) {
        .exited => |exitcode| return exitcode,
        .signal => |sig| return @intFromEnum(sig),
        .stopped => |_| return 999,
        .unknown => |_| return 999,
    }
}

test "print" {
    const printAsm = exitCodeTest(std.testing.io, &[_]u32{
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
