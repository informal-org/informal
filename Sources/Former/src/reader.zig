const std = @import("std");
const lex = @import("lexer.zig");
const queue = @import("queue.zig");



pub fn process_chunk(chunk: []u8, syntaxQ: *lex.TokenQueue, auxQ: *lex.TokenQueue) !void {

    // std.debug.print("Processing next chunk\n", .{});
    syntaxQ.reset();
    auxQ.reset();

    var lexer = lex.Lexer.init(chunk, syntaxQ, auxQ);
    try lexer.lex();

}

pub fn compile_file(filename: []u8) !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};

    var syntaxQ = lex.TokenQueue.init(gpa.allocator());
    var auxQ = lex.TokenQueue.init(gpa.allocator());

    defer syntaxQ.deinit();
    defer auxQ.deinit();

    const file = try std.fs.cwd().openFile(filename, .{});
    defer file.close();

    const reader = file.reader();
    var buffer: [16384]u8 = undefined;   // 16kb - sysctl vm.pagesize

    while (true) {
        const readResult = try reader.read(&buffer);
        if (readResult == 0) {
            break;
        }
        // std.debug.print("Read: {s}\n", .{buffer[0..readResult]});

        try process_chunk(buffer[0..readResult], &syntaxQ, &auxQ);

        buffer = undefined;
    }
}
