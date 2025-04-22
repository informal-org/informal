const std = @import("std");
const reader = @import("reader.zig");

pub fn main() !void {
    const gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const args = try std.process.argsAlloc(gpa);
    defer std.process.argsFree(gpa, args);

    if (args.len != 2) {
        std.debug.print("Usage: Former <filename>\n", .{});
        return error.Unreachable;
    }
    // std.debug.print("Reading file: {s}\n", .{args});
    const filename = args[1];

    const start = try std.time.Instant.now();
    try reader.compile_file(filename);
    const endTime = try std.time.Instant.now();
    const since = endTime.since(start);
    std.debug.print("Time taken: {d}μs / {d}ms\n", .{ since / std.time.ns_per_us, since / std.time.ns_per_ms });
}
