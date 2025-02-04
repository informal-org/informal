const std = @import("std");
const lex = @import("lexer.zig");
const parser = @import("parser.zig");
const queue = @import("queue.zig");
const tok = @import("token.zig");
const codegen = @import("codegen.zig");
const ns = @import("namespace.zig");
const macho = @import("macho.zig");
const Allocator = std.mem.Allocator;
const DEBUG = true;

pub const Reader = struct {
    const Self = @This();
    allocator: Allocator,
    syntaxQ: *lex.TokenQueue,
    auxQ: *lex.TokenQueue,
    parsedQ: *parser.TokenQueue,
    offsetQ: *parser.OffsetQueue,
    internedStrings: *std.StringHashMap(u64),
    internedNumbers: *std.AutoHashMap(u64, u64),
    internedFloats: *std.AutoHashMap(f64, u64),
    internedSymbols: *std.StringHashMap(u64),
};

pub fn process_chunk(chunk: []u8, reader: *Reader, allocator: Allocator) !void {

    // std.debug.print("Processing next chunk\n", .{});
    reader.syntaxQ.reset();
    reader.auxQ.reset();

    var lexer = lex.Lexer.init(chunk, reader.syntaxQ, reader.auxQ, reader.internedStrings, reader.internedNumbers, reader.internedFloats, reader.internedSymbols);
    try lexer.lex();

    var namespace = try ns.Namespace.init(allocator, reader.internedSymbols.count(), reader.parsedQ);
    defer namespace.deinit();

    var p = parser.Parser.init(chunk, reader.syntaxQ, reader.auxQ, reader.parsedQ, reader.offsetQ, allocator, &namespace);
    defer p.deinit();

    try p.parse();
    if (DEBUG) {
        tok.print_token_queue(reader.parsedQ.list.items, chunk);
    }

    var c = codegen.Codegen.init(allocator, chunk);
    defer c.deinit();

    try c.emitAll(reader.parsedQ.list.items);

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
    var internedStrings = std.StringHashMap(u64).init(gpa.allocator());
    var internedNumbers = std.AutoHashMap(u64, u64).init(gpa.allocator());
    var internedFloats = std.AutoHashMap(f64, u64).init(gpa.allocator());
    var internedSymbols = std.StringHashMap(u64).init(gpa.allocator());

    // var reader = Reader.init(gpa.allocator(), &syntaxQ, &auxQ, &parsedQ, &offsetQ);
    var reader = Reader{
        .allocator = gpa.allocator(),
        .syntaxQ = &syntaxQ,
        .auxQ = &auxQ,
        .parsedQ = &parsedQ,
        .offsetQ = &offsetQ,
        .internedStrings = &internedStrings,
        .internedNumbers = &internedNumbers,
        .internedFloats = &internedFloats,
        .internedSymbols = &internedSymbols,
    };

    defer syntaxQ.deinit();
    defer auxQ.deinit();
    defer parsedQ.deinit();
    defer internedStrings.deinit();
    defer internedNumbers.deinit();
    defer internedFloats.deinit();
    defer internedSymbols.deinit();
    const file = try std.fs.cwd().openFile(filename, .{});
    defer file.close();

    const r = file.reader();
    var buffer: [16384]u8 = undefined; // 16kb - sysctl vm.pagesize

    while (true) {
        const readResult = try r.read(&buffer);
        if (readResult == 0) {
            break;
        }
        // std.debug.print("Read: {s}\n", .{buffer[0..readResult]});

        // try process_chunk(buffer[0..readResult], &syntaxQ, &auxQ, &parsedQ, &offsetQ, gpa.allocator());
        try process_chunk(buffer[0..readResult], &reader, gpa.allocator());

        buffer = undefined;
    }
}
