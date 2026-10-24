const std = @import("std");
const reader = @import("reader.zig");
const build_options = @import("build_options");

pub const std_options = std.Options{
    .log_level = @fromBackingInt(@intCast(@backingInt(build_options.log_level))),
};

pub fn main(init: std.process.Init) !void {
    var args_iter = try std.process.Args.Iterator.initAllocator(init.minimal.args, init.gpa);
    defer args_iter.deinit();

    var arg_count: usize = 0;
    var filename: []const u8 = undefined;

    while (args_iter.next()) |arg| {
        if (arg_count == 1) {
            filename = arg;
        }
        arg_count += 1;
    }

    if (arg_count != 2) {
        std.debug.print("Usage: Former <filename>\n", .{});
        return error.Unreachable;
    }

    const start = std.Io.Clock.cpu_thread.now(init.io);
    try reader.compile_file(init.io, filename);
    const endTime = std.Io.Clock.cpu_thread.now(init.io);
    const since = start.durationTo(endTime).nanoseconds;
    std.debug.print("Time taken: {d}μs / {d}ms\n", .{ @divTrunc(since, std.time.ns_per_us), @divTrunc(since, std.time.ns_per_ms) });
}
