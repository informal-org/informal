const std = @import("std");

pub fn process_chunk(chunk: []u8) !void {
    std.debug.print("Processing chunk: {s}\n", .{chunk});
}

pub fn compile_file(filename: []u8) !void {
    const file = try std.fs.cwd().openFile(filename, .{});
    defer file.close();

    const reader = file.reader();
    var buffer: [4096]u8 = undefined;

    while (true) {
        const readResult = try reader.read(&buffer);
        if (readResult == 0) {
            break;
        }
        // std.debug.print("Read: {s}\n", .{buffer[0..readResult]});

        try process_chunk(buffer[0..readResult]);

        buffer = undefined;
    }
}
