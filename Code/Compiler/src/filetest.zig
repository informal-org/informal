// Utility to run doctests.
// That's a great end-to-end way to test the compiler against a suite of programs.

const std = @import("std");
const reader = @import("reader.zig");

const test_allocator = std.testing.allocator;
const expect = std.testing.expect;
const expectEqual = std.testing.expectEqual;
const print = std.debug.print;

fn exitCodeTest(io: std.Io, filename: []const u8) !u32 {
    // Create an executable with the given assembly code.
    // Execute it and check the exit code.

    // Clean up any existing test.bin file to ensure proper permissions are set
    std.Io.Dir.cwd().deleteFile(io, "test.bin") catch {};

    const re = try reader.Reader.init(test_allocator);
    defer re.deinit();

    const file = try std.Io.Dir.cwd().openFile(io, filename, .{});
    defer file.close(io);

    var buffer: [16384]u8 = undefined; // 16kb - sysctl vm.pagesize
    const buffer_slice: []u8 = &buffer;
    var out_name = "test.bin".*;

    while (true) {
        const buffer_array = [_][]u8{buffer_slice};
        const readResult = try file.readStreaming(io, &buffer_array);
        if (readResult == 0) {
            break;
        }
        try reader.process_chunk(buffer[0..readResult], re, test_allocator, io, &out_name);

        buffer = undefined;
    }

    // Execute the binary file (use relative path in cwd)
    const run_result = try std.process.run(test_allocator, io, .{
        .argv = &[_][]const u8{"./test.bin"},
    });

    // Cleanup file
    // try std.fs.cwd().deleteFile("test.bin");

    switch (run_result.term) {
        .exited => |exitcode| return exitcode,
        .signal => |sig| return @intFromEnum(sig),
        .stopped => |_| return 999,
        .unknown => |_| return 999,
    }
}

test "add.ifi" {
    print("Running add.ifi\n", .{});
    const exitCode = try exitCodeTest(std.testing.io, "../../Tests/FileTests/add.ifi");
    try expectEqual(42, exitCode);
}

test "identifiers.ifi" {
    print("Running identifiers.ifi\n", .{});
    const exitCode = try exitCodeTest(std.testing.io, "../../Tests/FileTests/identifiers.ifi");
    try expectEqual(12, exitCode);
}

test "assign.ifi" {
    print("Running assign.ifi\n", .{});
    const exitCode = try exitCodeTest(std.testing.io, "../../Tests/FileTests/assign.ifi");
    try expectEqual(2, exitCode);
}

// test "if.ifi" {
//     print("Running if.ifi\n", .{});
//     const exitCode = try exitCodeTest("../../Tests/FileTests/if.ifi");
//     try expectEqual(exitCode, 1);
// }
