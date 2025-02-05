// Utility to run doctests.
// That's a great end-to-end way to test the compiler against a suite of programs.

const std = @import("std");
const test_allocator = std.testing.allocator;
const expect = std.testing.expect;
const expectEqual = std.testing.expectEqual;
const macho = @import("macho.zig");
const print = std.debug.print;
const reader = @import("reader.zig");

fn exitCodeTest(filename: []const u8) !u32 {
    // Create an executable with the given assembly code.
    // Execute it and check the exit code.

    const re = try reader.Reader.init(test_allocator);
    defer re.deinit();

    const file = try std.fs.cwd().openFile(filename, .{});
    defer file.close();

    const fileReader = file.reader();
    var buffer: [16384]u8 = undefined; // 16kb - sysctl vm.pagesize
    var out_name = "out.bin".*;

    while (true) {
        const readResult = try fileReader.read(&buffer);
        if (readResult == 0) {
            break;
        }
        try reader.process_chunk(buffer[0..readResult], re, test_allocator, &out_name);

        buffer = undefined;
    }

    // Execute the binary file
    const cwd = std.fs.cwd();
    var out_buffer: [1024]u8 = undefined;

    const path = try cwd.realpath(&out_name, &out_buffer);

    var process = std.process.Child.init(&[_][]const u8{path}, test_allocator);

    const termination = try process.spawnAndWait();

    switch (termination) {
        .Exited => |exitcode| return exitcode,
        .Signal => |sig| return sig,
        .Stopped => |_| return 999,
        .Unknown => |_| return 999,
    }
}

test "add.ifi" {
    print("Running add.ifi\n", .{});
    const exitCode = try exitCodeTest("test/data/add.ifi");
    try expectEqual(exitCode, 42);
}

test "identifiers.ifi" {
    print("Running identifiers.ifi\n", .{});
    const exitCode = try exitCodeTest("test/data/add.ifi");
    try expectEqual(exitCode, 13);
}
