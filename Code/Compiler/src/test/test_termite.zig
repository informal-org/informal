const std = @import("std");
const termite = @import("../table/termite.zig");
const Table = termite.Table;

const States = enum(u8) { start, num, emit_num, plus, star, end, err };

fn Transition(comptime width: u2) type {
    return extern struct {
        bitmap: [Table.bitmapSize(width)]u8,
        next_states: [@as(usize, termite.ENTRY_WIDTH_MASKS[width]) + 1]u8,

        pub fn set(self: *@This(), char: u7, value: u8) void {
            const s = Table.slot(width, char);
            std.debug.assert(value <= s.mask);
            self.bitmap[s.byte] = (self.bitmap[s.byte] & ~(s.mask << s.shift)) | (value << s.shift);
        }

        pub fn setAll(self: *@This(), chars: []const u8, value: u8) void {
            for (chars) |ch| {
                self.set(@intCast(ch), value);
            }
        }

        pub fn route(self: *@This(), value: u8, chars: []const u8, target: States) void {
            self.setAll(chars, value);
            self.next_states[value] = @backingInt(target);
        }
    };
}

const Start = Transition(3);
const Num = Transition(0);
const DIGITS = "0123456789";

const Fixture = extern struct { start: Start, num: Num };
const fixture = blk: {
    var f = std.mem.zeroes(Fixture);
    f.start.route(0, "", .err);
    f.start.route(1, DIGITS, .num);
    f.start.route(2, "+", .plus);
    f.start.route(3, "*", .star);
    f.start.route(4, "\x00", .end);
    f.num.route(0, "", .emit_num);
    f.num.route(1, DIGITS, .num);
    break :blk f;
};

fn state(comptime field: []const u8, width: u2, op: Table.Op, consume: bool, arg: u8) Table.State {
    return .{
        .transition_id = @offsetOf(Fixture, field),
        .width = width,
        .consume = consume,
        .op = op,
        .arg = arg,
    };
}

// const start = ;
// const num = ;
const START_WIDTH = 3;
const NUM_WIDTH = 0;

const dispatch = std.EnumArray(States, Table.State).init(.{
    .start = state("start", START_WIDTH, Table.Op.none, false, 0),
    .num = state("num", NUM_WIDTH, Table.Op.none, true, 0),
    .emit_num = state("start", START_WIDTH, Table.Op.emit_int, false, @backingInt(tok.Kind.lit_number)),
    .plus = state("start", START_WIDTH, Table.Op.emit, true, @backingInt(tok.Kind.op_add)),
    .star = state("start", START_WIDTH, Table.Op.emit, true, @backingInt(tok.Kind.op_mul)),
    .end = state("start", START_WIDTH, Table.Op.emit_end, true, 0),
    .err = state("start", START_WIDTH, Table.Op.err, false, 0),
});

const table = Table{ .states = &dispatch.values, .transitions = std.mem.asBytes(&fixture) };

const Step = struct { sym: u7, to: States };
const steps = [_]Step{
    .{ .sym = '1', .to = .num },
    .{ .sym = '+', .to = .emit_num },
    .{ .sym = '+', .to = .plus },
    .{ .sym = '2', .to = .num },
    .{ .sym = '3', .to = .num },
    .{ .sym = '4', .to = .num },
    .{ .sym = '*', .to = .emit_num },
    .{ .sym = '*', .to = .star },
    .{ .sym = '5', .to = .num },
    .{ .sym = '6', .to = .num },
    .{ .sym = 0, .to = .emit_num },
    .{ .sym = 0, .to = .end },
};

test "1+234*56" {
    var cur: States = .start;
    for (steps) |s| {
        errdefer std.debug.print("from {s} on {d}\n", .{ @tagName(cur), s.sym });
        const got: States = @fromBackingInt(table.next(dispatch.get(cur), s.sym));
        try std.testing.expectEqual(s.to, got);
        cur = got;
    }
}

const tok = @import("../token.zig");
const Token = tok.Token;
const TokenQueue = termite.TokenQueue;

const test_allocator = std.testing.allocator;
const expect = std.testing.expect;
const expectEqual = std.testing.expectEqual;
const testutils = @import("./testutils.zig");
const testQueueEquals = testutils.testQueueEquals;

fn testLex(buffer: []const u8, expected: []const Token, aux: ?[]const Token) !void {
    var syntaxQ = try TokenQueue.init(test_allocator);
    var auxQ = try TokenQueue.init(test_allocator);
    try syntaxQ.reserve(buffer.len);
    try auxQ.reserve(buffer.len);
    // var internedStrings = std.StringHashMap(u64).init(test_allocator);
    // var internedNumbers = std.AutoHashMap(u64, u64).init(test_allocator);
    // var internedFloats = std.AutoHashMap(f64, u64).init(test_allocator);
    // var symbolTable = std.StringHashMap(u64).init(test_allocator);

    var lexer = termite.Lexer.init(
        table,
        buffer,
        &syntaxQ,
        &auxQ,
    );

    defer syntaxQ.deinit();
    defer auxQ.deinit();
    // defer internedStrings.deinit();
    // defer internedNumbers.deinit();
    // defer internedFloats.deinit();
    // defer symbolTable.deinit();
    // try lexer.lex();
    try lexer.genLex(table);

    try testQueueEquals(buffer, &syntaxQ, expected);
    if (aux) |auxExpected| {
        try testQueueEquals(buffer, &auxQ, auxExpected);
    }
}

test "lex 1+234*56" {
    try testLex("1+234*56\x00", &[_]Token{
        Token.lex(.lit_number, 1, 1),
        tok.createToken(.op_add),
        Token.lex(.lit_number, 234, 3),
        tok.createToken(.op_mul),
        Token.lex(.lit_number, 56, 2).nextAlt(),
    }, &[_]Token{ tok.AUX_STREAM_START.nextAlt(), tok.AUX_STREAM_END });
}
