const std = @import("std");
const lex = @import("lexer.zig");
const parser = @import("parser.zig");
const queue = @import("queue.zig");
const tok = @import("token.zig");
const codegen = @import("codegen.zig");
const rs = @import("resolution.zig");
// const macho = @import("macho.zig");
const constants = @import("constants.zig");
const Allocator = std.mem.Allocator;
const StringArrayHashMap = std.array_hash_map.StringArrayHashMap;
const DEBUG = constants.DEBUG;

pub const Reader = struct {
    const Self = @This();
    allocator: Allocator,
    syntaxQ: *lex.TokenQueue,
    auxQ: *lex.TokenQueue,
    parsedQ: *parser.TokenQueue,
    offsetQ: *parser.OffsetQueue,
    internedStrings: *StringArrayHashMap(u64),
    internedNumbers: *std.AutoHashMap(u64, u64),
    internedFloats: *std.AutoHashMap(f64, u64),
    internedSymbols: *std.StringHashMap(u64),

    pub fn init(allocator: Allocator) !*Self {
        // Allocate all queue/hashmap pointers on heap
        const syntaxQ = try allocator.create(lex.TokenQueue);
        syntaxQ.* = lex.TokenQueue.init(allocator);

        const auxQ = try allocator.create(lex.TokenQueue);
        auxQ.* = lex.TokenQueue.init(allocator);

        const parsedQ = try allocator.create(parser.TokenQueue);
        parsedQ.* = parser.TokenQueue.init(allocator);

        const offsetQ = try allocator.create(parser.OffsetQueue);
        offsetQ.* = parser.OffsetQueue.init(allocator);

        const internedStrings = try allocator.create(StringArrayHashMap(u64));
        internedStrings.* = StringArrayHashMap(u64).init(allocator);

        const internedNumbers = try allocator.create(std.AutoHashMap(u64, u64));
        internedNumbers.* = std.AutoHashMap(u64, u64).init(allocator);

        const internedFloats = try allocator.create(std.AutoHashMap(f64, u64));
        internedFloats.* = std.AutoHashMap(f64, u64).init(allocator);

        const internedSymbols = try allocator.create(std.StringHashMap(u64));
        internedSymbols.* = std.StringHashMap(u64).init(allocator);

        const reader = try allocator.create(Self);
        reader.* = .{
            .allocator = allocator,
            .syntaxQ = syntaxQ,
            .auxQ = auxQ,
            .parsedQ = parsedQ,
            .offsetQ = offsetQ,
            .internedStrings = internedStrings,
            .internedNumbers = internedNumbers,
            .internedFloats = internedFloats,
            .internedSymbols = internedSymbols,
        };
        return reader;
    }

    pub fn deinit(self: *Self) void {
        self.syntaxQ.deinit();
        self.auxQ.deinit();
        self.parsedQ.deinit();
        self.offsetQ.deinit();
        self.internedStrings.deinit();
        self.internedNumbers.deinit();
        self.internedFloats.deinit();
        self.internedSymbols.deinit();

        // Free the allocated structs themselves
        self.allocator.destroy(self.syntaxQ);
        self.allocator.destroy(self.auxQ);
        self.allocator.destroy(self.parsedQ);
        self.allocator.destroy(self.offsetQ);
        self.allocator.destroy(self.internedStrings);
        self.allocator.destroy(self.internedNumbers);
        self.allocator.destroy(self.internedFloats);
        self.allocator.destroy(self.internedSymbols);

        self.allocator.destroy(self);
    }
};

pub fn process_chunk(chunk: []u8, reader: *Reader, allocator: Allocator, out_filename: []u8) !void {

    // std.debug.print("Processing next chunk\n", .{});
    reader.syntaxQ.reset();
    reader.auxQ.reset();

    var lexer = lex.Lexer.init(chunk, reader.syntaxQ, reader.auxQ, reader.internedStrings, reader.internedNumbers, reader.internedFloats, reader.internedSymbols);
    try lexer.lex();

    if (DEBUG) {
        std.debug.print("\n------------- Lexer Queue --------------- \n", .{});
        tok.print_token_queue(reader.syntaxQ.list.items, chunk);
    }

    var resolution = try rs.Resolution.init(allocator, reader.internedSymbols.count(), reader.parsedQ);
    defer resolution.deinit();

    var p = parser.Parser.init(chunk, reader.syntaxQ, reader.auxQ, reader.parsedQ, reader.offsetQ, allocator, &resolution);
    defer p.deinit();

    try p.parse();
    if (DEBUG) {
        std.debug.print("\n------------- Parsed Queue --------------- \n", .{});
        tok.print_token_queue(reader.parsedQ.list.items, chunk);
    }

    var c = codegen.Codegen.init(allocator, chunk);
    defer c.deinit();

    try c.emitAll(reader.parsedQ.list.items, reader.internedStrings);

    std.debug.print("Out file name: {s}\n", .{out_filename});

    // var linker = macho.MachOLinker.init(allocator);
    // defer linker.deinit();
    // try linker.emitBinary(c.objCode.items, reader.internedStrings, c.totalConstSize, out_filename);
}

pub fn compile_file(filename: []u8) !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};

    var reader = try Reader.init(gpa.allocator());
    defer reader.deinit();

    const file = try std.fs.cwd().openFile(filename, .{});
    defer file.close();

    const r = file.reader();
    var buffer: [16384]u8 = undefined; // 16kb - sysctl vm.pagesize

    // Create a mutable slice for the output filename
    var out_name = "out.bin".*;

    while (true) {
        const readResult = try r.read(&buffer);
        if (readResult == 0) {
            break;
        }
        try process_chunk(buffer[0..readResult], reader, gpa.allocator(), &out_name);
        // TODO: Safety check - there's an implicit assumption that the contents of the buffer are not referenced after chunk processing is done.
        // Else it's a use after free or it might be referencing something else than intended.
        // TODO: Handle larger files beyond the 16kb size.
        buffer = undefined;
    }
}

test {
    if (constants.DISABLE_ZIG_LAZY) {
        @import("std").testing.refAllDecls(@This());
    }
}
