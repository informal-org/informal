const std = @import("std");
const lex = @import("lexer.zig");
const parser = @import("parser.zig");
const queue = @import("queue.zig");
const tok = @import("token.zig");
const codegen = @import("codegen.zig");
const rs = @import("resolution.zig");
const macho = @import("macho.zig");
const build_options = @import("build_options");
const KindRanges = @import("ir/kind_ranges.zig").KindRanges;
const Allocator = std.mem.Allocator;

const ParserImpl = parser.Parser;
const TokenQueue = lex.TokenQueue;

pub const Reader = struct {
    const Self = @This();
    allocator: Allocator,
    syntaxQ: *TokenQueue,
    auxQ: *TokenQueue,
    kindRanges: *KindRanges,
    parsedElements: *TokenQueue,
    parsedQ: *parser.ParsedQueue,
    internedStrings: *std.StringHashMap(u64),
    internedNumbers: *std.AutoHashMap(u64, u64),
    internedFloats: *std.AutoHashMap(f64, u64),
    internedSymbols: *std.StringHashMap(u64),

    pub fn init(allocator: Allocator) !*Self {
        // Allocate all queue/hashmap pointers on heap
        const syntaxQ = try allocator.create(TokenQueue);
        syntaxQ.* = try TokenQueue.init(allocator);

        const auxQ = try allocator.create(TokenQueue);
        auxQ.* = try TokenQueue.init(allocator);

        const kindRanges = try allocator.create(KindRanges);
        kindRanges.* = KindRanges{};

        const parsedElements = try allocator.create(TokenQueue);
        parsedElements.* = try TokenQueue.init(allocator);

        const parsedQ = try allocator.create(parser.ParsedQueue);
        parsedQ.* = try parser.ParsedQueue.init(allocator, parsedElements, kindRanges);

        const internedStrings = try allocator.create(std.StringHashMap(u64));
        internedStrings.* = std.StringHashMap(u64).init(allocator);

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
            .kindRanges = kindRanges,
            .parsedElements = parsedElements,
            .parsedQ = parsedQ,
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
        self.parsedQ.deinit(self.allocator);
        self.parsedElements.deinit();
        self.internedStrings.deinit();
        self.internedNumbers.deinit();
        self.internedFloats.deinit();
        self.internedSymbols.deinit();

        // Free the allocated structs themselves
        self.allocator.destroy(self.syntaxQ);
        self.allocator.destroy(self.auxQ);
        self.allocator.destroy(self.kindRanges);
        self.allocator.destroy(self.parsedQ);
        self.allocator.destroy(self.parsedElements);
        self.allocator.destroy(self.internedStrings);
        self.allocator.destroy(self.internedNumbers);
        self.allocator.destroy(self.internedFloats);
        self.allocator.destroy(self.internedSymbols);
        self.allocator.destroy(self);
    }
};

pub fn process_chunk(chunk: []u8, reader: *Reader, allocator: Allocator, io: std.Io, out_filename: []u8, chunkSize: usize) !void {

    // std.debug.print("Processing next chunk\n", .{});
    reader.syntaxQ.reset();
    reader.auxQ.reset();
    reader.parsedElements.reset();
    reader.parsedQ.reset();
    // Over-allocate space - enough for an element per byte. Could be sized smaller if we want.
    const lexerCapacity = chunkSize / 4 + 4; // Arbitrary math.
    try reader.syntaxQ.reserve(lexerCapacity);
    try reader.auxQ.reserve(lexerCapacity);

    var lexer = lex.Lexer.init(chunk, reader.syntaxQ, reader.auxQ, reader.internedStrings, reader.internedNumbers, reader.internedFloats, reader.internedSymbols);
    try lexer.lex();

    var resolution = try rs.Resolution.init(allocator, reader.internedSymbols.count(), reader.parsedElements);
    defer resolution.deinit();

    const parsedCapacity = reader.syntaxQ.list.items.len + 1;
    try reader.parsedElements.reserve(parsedCapacity);
    try reader.parsedQ.reserve(allocator, lexer.maxOpStreak);
    var p = ParserImpl.init(chunk, reader.syntaxQ, reader.parsedQ);
    p.parse();
    // std.log.debug("\n------------- Parsed Queue --------------- \n", .{});
    // std.log.debug("Parsed queue: {any}", .{reader.parsedElements.list.items});

    var c = codegen.Codegen.init(allocator, chunk);
    try c.emitAll(reader.parsedElements.list.items, reader.internedStrings);
    defer c.deinit();

    var linker = macho.MachOLinker.init(allocator);
    defer linker.deinit();
    try linker.emitBinary(io, c.objCode.items, reader.internedStrings, c.totalConstSize, out_filename);
}

pub fn compile_file(io: std.Io, filename: []const u8) !void {
    const gpa = std.heap.smp_allocator;

    var reader = try Reader.init(gpa);
    defer reader.deinit();

    const file = try std.Io.Dir.cwd().openFile(io, filename, .{});
    defer file.close(io);

    var buffer: [16384]u8 = undefined; // 16kb - sysctl vm.pagesize
    const buffer_slice: []u8 = &buffer;

    // Create a mutable slice for the output filename
    var out_name = "out.bin".*;

    while (true) {
        const buffer_array = [_][]u8{buffer_slice};
        const readResult = file.readStreaming(io, &buffer_array) catch |err| switch (err) {
            error.EndOfStream => break,
            else => return err,
        };
        try process_chunk(buffer[0..readResult], reader, gpa, io, &out_name, readResult);
        // TODO: Safety check - there's an implicit assumption that the contents of the buffer are not referenced after chunk processing is done.
        // Else it's a use after free or it might be referencing something else than intended.
        // TODO: Handle larger files beyond the 16kb size.
        buffer = undefined;
    }
}

test {
    if (build_options.disable_zig_lazy) {
        @import("std").testing.refAllDecls(@This());
    }
}
