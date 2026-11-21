const std = @import("std");
const termite = @import("../table/termite.zig");
const Table = termite.Table;
const tok = @import("../token.zig");
const Token = tok.Token;
const TK = tok.Kind;
const ParsedQueue = @import("../parser.zig").ParsedQueue;

const States = enum(u8) { start, num, emit_num, sym, end, err, expect_arg, value, prec_mul, prec_add, prec_end, parse_end };

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

const Transition0 = Transition(0); // Num
const Transition1 = Transition(1); // Val
const Transition3 = Transition(3); // Start
const DIGITS = "0123456789";
const SYMBOLS = "%*+,-./";

const TK_NUM = [_]u8{@backingInt(TK.lit_number)};
const TK_MUL = [_]u8{@backingInt(TK.op_mul)};
const TK_ADD = [_]u8{@backingInt(TK.op_add)};
const TK_END = [_]u8{@backingInt(TK.aux_stream_end)};
const POP_MUL_ADD = [_]u8{ @backingInt(TK.op_mul), @backingInt(TK.op_add) };

const Fixture = extern struct {
    start: Transition3,
    num: Transition0,
    sym: Transition0, // Lexer sStates
    operand: Transition0,
    value: Transition1, // parser states
    prec_mul: Transition0,
    prec_add: Transition0,
    prec_end: Transition0, // Precedence
};
const fixture = blk: {
    var f = std.mem.zeroes(Fixture);
    f.start.route(0, "", .err);
    f.start.route(1, DIGITS, .num);
    f.start.route(2, SYMBOLS, .sym);
    f.start.route(4, "\x00", .end);
    f.num.route(0, "", .emit_num);
    f.num.route(1, DIGITS, .num);
    f.sym.route(0, "", .start);
    f.sym.route(1, SYMBOLS, .start);
    // Parser states
    f.operand.route(0, "", .err);
    f.operand.route(1, &TK_NUM, .value);
    f.value.route(0, "", .err);
    f.value.route(1, &TK_MUL, .prec_mul);
    f.value.route(2, &TK_ADD, .prec_add);
    f.value.route(3, &TK_END, .prec_end);
    f.prec_mul.route(0, "", .expect_arg);
    f.prec_mul.route(1, &TK_MUL, .prec_mul);
    f.prec_add.route(0, "", .expect_arg);
    f.prec_add.route(1, &POP_MUL_ADD, .prec_add);
    f.prec_end.route(0, "", .parse_end);
    f.prec_end.route(1, &POP_MUL_ADD, .prec_end);

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
    .sym = state("sym", NUM_WIDTH, Table.Op.emit_sym, true, @backingInt(tok.Kind.op_div)), // arg = base.
    .end = state("start", START_WIDTH, Table.Op.emit_end, true, 0),
    .err = state("start", START_WIDTH, Table.Op.err, false, 0),

    // Parser
    .expect_arg = state("operand", 0, Table.Op.none, false, 0),
    .value = state("value", 1, Table.Op.emit_val, false, 0),
    .prec_mul = state("prec_mul", 0, Table.Op.push_op, false, 0),
    .prec_add = state("prec_add", 0, Table.Op.push_op, false, 0),
    .prec_end = state("prec_end", 0, Table.Op.flush_all, false, 0),
    .parse_end = state("operand", 0, Table.Op.none, false, 0),
});

const table = Table{ .states = &dispatch.values, .transitions = std.mem.asBytes(&fixture), .parserStartId = @backingInt(States.expect_arg) };

const Step = struct { sym: u7, to: States };
const steps = [_]Step{
    .{ .sym = '1', .to = .num },
    .{ .sym = '+', .to = .emit_num },
    .{ .sym = '+', .to = .sym },
    .{ .sym = '2', .to = .start },
    .{ .sym = '2', .to = .num },
    .{ .sym = '3', .to = .num },
    .{ .sym = '4', .to = .num },
    .{ .sym = '*', .to = .emit_num },
    .{ .sym = '*', .to = .sym },
    .{ .sym = '5', .to = .start },
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

const TokenQueue = termite.TokenQueue;

const test_allocator = std.testing.allocator;
const expect = std.testing.expect;
const expectEqual = std.testing.expectEqual;
const testutils = @import("./testutils.zig");
const testQueueEquals = testutils.testQueueEquals;

fn testLex(buffer: []const u8, expected: []const Token, aux: ?[]const Token, parsed: ?[]const Token) !void {
    var syntaxQ = try TokenQueue.init(test_allocator);
    var auxQ = try TokenQueue.init(test_allocator);
    var parsedTokens = try TokenQueue.init(test_allocator);
    defer parsedTokens.deinit();
    try parsedTokens.reserve(buffer.len);
    var parsedQ = try ParsedQueue.init(test_allocator, &parsedTokens);
    defer parsedQ.deinit(test_allocator);
    try syntaxQ.reserve(buffer.len);
    try auxQ.reserve(buffer.len);
    // var internedStrings = std.StringHashMap(u64).init(test_allocator);
    // var internedNumbers = std.AutoHashMap(u64, u64).init(test_allocator);
    // var internedFloats = std.AutoHashMap(f64, u64).init(test_allocator);
    // var symbolTable = std.StringHashMap(u64).init(test_allocator);

    var lexer = termite.Termite(table).init(
        buffer,
        &syntaxQ,
        &auxQ,
        &parsedQ,
    );

    defer syntaxQ.deinit();
    defer auxQ.deinit();
    // defer internedStrings.deinit();
    // defer internedNumbers.deinit();
    // defer internedFloats.deinit();
    // defer symbolTable.deinit();
    // try lexer.lex();
    try lexer.genLex();

    try testQueueEquals(buffer, &syntaxQ, expected);
    if (aux) |auxExpected| {
        try testQueueEquals(buffer, &auxQ, auxExpected);
    }

    if (parsed) |parsedExpected| {
        try testQueueEquals(buffer, &parsedTokens, parsedExpected);
    }
}

test "lex 1+234*56" {
    try testLex("1+234*56\x00", &[_]Token{
        Token.lex(.lit_number, 1, 1),
        tok.createToken(.op_add),
        Token.lex(.lit_number, 234, 3),
        tok.createToken(.op_mul),
        Token.lex(.lit_number, 56, 2).nextAlt(),
    }, &[_]Token{ tok.AUX_STREAM_START.nextAlt(), tok.AUX_STREAM_END }, null);
}

test "parse 1+234*56" {
    try testLex("1+234*56\x00", &[_]Token{
        Token.lex(.lit_number, 1, 1),
        tok.createToken(.op_add),
        Token.lex(.lit_number, 234, 3),
        tok.createToken(.op_mul),
        Token.lex(.lit_number, 56, 2).nextAlt(),
    }, &[_]Token{ tok.AUX_STREAM_START.nextAlt(), tok.AUX_STREAM_END }, &[_]Token{
        Token.lex(.lit_number, 1, 1),
        Token.lex(.lit_number, 234, 3),
        Token.lex(.lit_number, 56, 2).nextAlt(),
        Token.lex(.op_mul, 4, 0),
        Token.lex(.op_add, 2, 0),
    });
}

test "parse 1*234+56" {
    try testLex("1*234+56\x00", &[_]Token{
        Token.lex(.lit_number, 1, 1),
        tok.createToken(.op_mul),
        Token.lex(.lit_number, 234, 3),
        tok.createToken(.op_add),
        Token.lex(.lit_number, 56, 2).nextAlt(),
    }, &[_]Token{ tok.AUX_STREAM_START.nextAlt(), tok.AUX_STREAM_END }, &[_]Token{
        Token.lex(.lit_number, 1, 1),
        Token.lex(.lit_number, 234, 3),
        Token.lex(.op_mul, 2, 0),
        Token.lex(.lit_number, 56, 2).nextAlt(),
        Token.lex(.op_add, 4, 0),
    });
}
