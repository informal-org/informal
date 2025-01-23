const std = @import("std");
const reader = @import("reader.zig");

pub fn main() !void {
    const args = try std.process.argsAlloc(std.heap.page_allocator);
    defer std.process.argsFree(std.heap.page_allocator, args);

    if (args.len != 2) {
        std.debug.print("Usage: Former <filename>\n", .{});
        return error.Unreachable;
    }
    // std.debug.print("Reading file: {s}\n", .{args});
    const filename = args[1];
    try reader.compile_file(filename);
}
