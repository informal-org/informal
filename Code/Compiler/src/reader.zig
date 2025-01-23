const std = @import("std");
const lex = @import("lexer.zig");
const parser = @import("parser.zig");
const queue = @import("queue.zig");
const tok = @import("token.zig");
const codegen = @import("codegen.zig");
const macho = @import("macho.zig");
const Allocator = std.mem.Allocator;

pub fn process_chunk(chunk: []u8, syntaxQ: *lex.TokenQueue, auxQ: *lex.TokenQueue, parsedQ: *parser.TokenQueue, offsetQ: *parser.OffsetQueue, allocator: Allocator) !void {

    // std.debug.print("Processing next chunk\n", .{});
    syntaxQ.reset();
    auxQ.reset();

    var lexer = lex.Lexer.init(chunk, syntaxQ, auxQ);
    try lexer.lex();

    var p = parser.Parser.init(chunk, syntaxQ, auxQ, parsedQ, offsetQ, allocator);
    defer p.deinit();

    try p.parse();
    tok.print_token_queue(parsedQ.list.items, chunk);

    var c = codegen.Codegen.init(allocator, chunk);
    defer c.deinit();

    try c.emitAll(parsedQ.list.items);

    var linker = macho.MachOLinker.init(allocator);
    defer linker.deinit();
    try linker.emitBinary(c.objCode.items, "out.bin");
}

pub fn compile_file(filename: []u8) !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};

    var syntaxQ = lex.TokenQueue.init(gpa.allocator());
    var auxQ = lex.TokenQueue.init(gpa.allocator());
    var parsedQ = parser.TokenQueue.init(gpa.allocator());
    var offsetQ = parser.OffsetQueue.init(gpa.allocator());

    defer syntaxQ.deinit();
    defer auxQ.deinit();
    defer parsedQ.deinit();

    const file = try std.fs.cwd().openFile(filename, .{});
    defer file.close();

    const reader = file.reader();
    var buffer: [16384]u8 = undefined; // 16kb - sysctl vm.pagesize

    while (true) {
        const readResult = try reader.read(&buffer);
        if (readResult == 0) {
            break;
        }
        // std.debug.print("Read: {s}\n", .{buffer[0..readResult]});

        try process_chunk(buffer[0..readResult], &syntaxQ, &auxQ, &parsedQ, &offsetQ, gpa.allocator());

        buffer = undefined;
    }
}
