const std = @import("std");
const Parser = @import("parser.zig").Parser;
const wasm = @import("wasm.zig");

pub fn main() !void {
    // const arena_allocator = std.heap.ArenaAllocator;
    var buffer: [10000]u8 = undefined;
    var fba = std.heap.FixedBufferAllocator.init(&buffer);
    const allocator = fba.allocator();

    const stdin = std.io.getStdIn().reader();
    const value = try stdin.readUntilDelimiterOrEofAlloc(allocator, '\n', 100);
    defer allocator.free(value.?);

    var parser = Parser.init(value.?, allocator);
    // var parser = Parser.init("1 + 1", allocator);
    defer parser.deinit();

    try parser.lex();
    try wasm.emit(&parser);
}
