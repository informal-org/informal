// Utility to run doctests.
// That's a great end-to-end way to test the compiler against a suite of programs.

const std = @import("std");
const test_allocator = std.testing.allocator;
const expect = std.testing.expect;
const expectEqual = std.testing.expectEqual;
const macho = @import("macho.zig");
const print = std.debug.print;

fn exitCodeTest(filename: []const u8) !u32 {
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
