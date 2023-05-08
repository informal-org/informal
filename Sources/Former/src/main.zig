const std = @import("std");
const Parser = @import("parser.zig").Parser;
const wasm = @import("wasm.zig");

pub fn main() !void {
    // const arena_allocator = std.heap.ArenaAllocator;
    var buffer: [10000]u8 = undefined;
    var fba = std.heap.FixedBufferAllocator.init(&buffer);
    const allocator = fba.allocator();
    var parser = Parser.init("1 + 2 * 3", allocator);
    defer parser.deinit();

    try parser.lex();
    try wasm.emit(&parser);
}
