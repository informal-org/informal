const tok = @import("../token.zig");
const Kind = tok.Kind;
const std = @import("std");
const q = @import("../queue.zig");
const rs = @import("../resolution.zig");

const Token = tok.Token;
const TokenQueue = q.Queue(Token, tok.AUX_STREAM_END);
const OffsetQueue = q.Queue(u16, 0);
const TK = Kind;

const test_allocator = std.testing.allocator;
const testutils = @import("./testutils.zig");
const parser_mod = @import("../parser.zig");

fn testPrattParse(buffer: []const u8, tokens: []const Token, max_symbols: u32, expected: []const Token) !void {
    var syntaxQ = TokenQueue.init(test_allocator);
    var auxQ = TokenQueue.init(test_allocator);
    var parsedQ = TokenQueue.init(test_allocator);
    var offsetQ = OffsetQueue.init(test_allocator);
    var resolution = try rs.Resolution.init(test_allocator, max_symbols, &parsedQ);
    defer syntaxQ.deinit();
    defer auxQ.deinit();
    defer parsedQ.deinit();
    defer offsetQ.deinit();
    defer resolution.deinit();

    try testutils.pushAll(&syntaxQ, tokens);
    var p = parser_mod.PrattParser.init(buffer, &syntaxQ, &auxQ, &parsedQ, &offsetQ, test_allocator, &resolution);
    defer p.deinit();
    try p.startParse();

    try testutils.testQueueEquals(buffer, &parsedQ, expected);
}

fn tok64(comptime bits: u64) Token {
    return @bitCast(bits);
}

test "basic add" {
    const buffer = "1+3";
    const tokens = &[_]Token{
        Token.lex(TK.lit_number, 0, 1),
        tok.createToken(TK.op_add),
        Token.lex(TK.lit_number, 2, 1).nextAlt(),
    };
    const expected = &[_]Token{
        tok64(0x0000000000003900),
        tok64(0x0001000000003100),
        tok64(0x0001000000023101),
        tok64(0x0000000000001200),
    };
    try testPrattParse(buffer, tokens, 0, expected);
}

test "math op precedence" {
    const buffer = "1+2*3";
    const tokens = &[_]Token{
        Token.lex(TK.lit_number, 0, 1),
        tok.createToken(TK.op_add),
        Token.lex(TK.lit_number, 2, 1),
        tok.createToken(TK.op_mul),
        Token.lex(TK.lit_number, 4, 1),
    };
    const expected = &[_]Token{
        tok64(0x0000000000003900),
        tok64(0x0001000000003100),
        tok64(0x0001000000023100),
        tok64(0x0001000000043100),
        tok64(0x0000000000001300),
        tok64(0x0000000000001200),
    };
    try testPrattParse(buffer, tokens, 0, expected);
}

test "math op precedence reversed" {
    const buffer = "1*2+3";
    const tokens = &[_]Token{
        Token.lex(TK.lit_number, 0, 1),
        tok.createToken(TK.op_mul),
        Token.lex(TK.lit_number, 2, 1),
        tok.createToken(TK.op_add),
        Token.lex(TK.lit_number, 4, 1),
    };
    const expected = &[_]Token{
        tok64(0x0000000000003900),
        tok64(0x0001000000003100),
        tok64(0x0001000000023100),
        tok64(0x0000000000001300),
        tok64(0x0001000000043100),
        tok64(0x0000000000001200),
    };
    try testPrattParse(buffer, tokens, 0, expected);
}

test "subtraction and division" {
    const buffer = "6-2/3";
    const tokens = &[_]Token{
        Token.lex(TK.lit_number, 0, 1),
        tok.createToken(TK.op_sub),
        Token.lex(TK.lit_number, 2, 1),
        tok.createToken(TK.op_div),
        Token.lex(TK.lit_number, 4, 1),
    };
    const expected = &[_]Token{
        tok64(0x0000000000003900),
        tok64(0x0001000000003100),
        tok64(0x0001000000023100),
        tok64(0x0001000000043100),
        tok64(0x0000000000000e00),
        tok64(0x0000000000001000),
    };
    try testPrattParse(buffer, tokens, 0, expected);
}

test "chained adds" {
    const buffer = "1+2+3";
    const tokens = &[_]Token{
        Token.lex(TK.lit_number, 0, 1),
        tok.createToken(TK.op_add),
        Token.lex(TK.lit_number, 2, 1),
        tok.createToken(TK.op_add),
        Token.lex(TK.lit_number, 4, 1),
    };
    const expected = &[_]Token{
        tok64(0x0000000000003900),
        tok64(0x0001000000003100),
        tok64(0x0001000000023100),
        tok64(0x0000000000001200),
        tok64(0x0001000000043100),
        tok64(0x0000000000001200),
    };
    try testPrattParse(buffer, tokens, 0, expected);
}

test "comparison operators" {
    const buffer = "1<2";
    const tokens = &[_]Token{
        Token.lex(TK.lit_number, 0, 1),
        tok.createToken(TK.op_lt),
        Token.lex(TK.lit_number, 2, 1),
    };
    const expected = &[_]Token{
        tok64(0x0000000000003900),
        tok64(0x0001000000003100),
        tok64(0x0001000000023100),
        tok64(0x0000000000000c00),
    };
    try testPrattParse(buffer, tokens, 0, expected);
}

test "equality with arithmetic" {
    const buffer = "1+2==3";
    const tokens = &[_]Token{
        Token.lex(TK.lit_number, 0, 1),
        tok.createToken(TK.op_add),
        Token.lex(TK.lit_number, 2, 1),
        tok.createToken(TK.op_dbl_eq),
        Token.lex(TK.lit_number, 4, 1),
    };
    const expected = &[_]Token{
        tok64(0x0000000000003900),
        tok64(0x0001000000003100),
        tok64(0x0001000000023100),
        tok64(0x0000000000001200),
        tok64(0x0001000000043100),
        tok64(0x0000000000000100),
    };
    try testPrattParse(buffer, tokens, 0, expected);
}

test "logical and/or" {
    const buffer = "a and b or c";
    const tokens = &[_]Token{
        Token.lex(TK.identifier, 0, 1),
        tok.createToken(TK.op_and),
        Token.lex(TK.identifier, 1, 1),
        tok.createToken(TK.op_or),
        Token.lex(TK.identifier, 2, 1),
    };
    const expected = &[_]Token{
        tok64(0x0000000000003900),
        tok64(0x0000000000002b00),
        tok64(0x0000000000012b00),
        tok64(0x0000000000001700),
        tok64(0x0000000000022b00),
        tok64(0x0000000000001800),
    };
    try testPrattParse(buffer, tokens, 3, expected);
}

test "assignment" {
    const buffer = "x=1";
    const tokens = &[_]Token{
        Token.lex(TK.identifier, 0, 1),
        tok.createToken(TK.op_assign_eq),
        Token.lex(TK.lit_number, 2, 1),
    };
    const expected = &[_]Token{
        tok64(0x0000000000003900),
        tok64(0x0000000000002b02),
        tok64(0x0001000000023100),
        tok64(0x0000000000000b00),
    };
    try testPrattParse(buffer, tokens, 1, expected);
}

test "assignment with expression" {
    const buffer = "x=1+2";
    const tokens = &[_]Token{
        Token.lex(TK.identifier, 0, 1),
        tok.createToken(TK.op_assign_eq),
        Token.lex(TK.lit_number, 2, 1),
        tok.createToken(TK.op_add),
        Token.lex(TK.lit_number, 4, 1),
    };
    const expected = &[_]Token{
        tok64(0x0000000000003900),
        tok64(0x0000000000002b02),
        tok64(0x0001000000023100),
        tok64(0x0001000000043100),
        tok64(0x0000000000001200),
        tok64(0x0000000000000b00),
    };
    try testPrattParse(buffer, tokens, 1, expected);
}

test "multiple expressions with newline" {
    const buffer = "1+2\n3+4";
    const tokens = &[_]Token{
        Token.lex(TK.lit_number, 0, 1),
        tok.createToken(TK.op_add),
        Token.lex(TK.lit_number, 2, 1),
        tok.createToken(TK.sep_newline),
        Token.lex(TK.lit_number, 4, 1),
        tok.createToken(TK.op_add),
        Token.lex(TK.lit_number, 6, 1),
    };
    const expected = &[_]Token{
        tok64(0x0000000000003900),
        tok64(0x0001000000003100),
        tok64(0x0001000000023100),
        tok64(0x0000000000001200),
        tok64(0x0001000000043100),
        tok64(0x0001000000063100),
        tok64(0x0000000000001200),
    };
    try testPrattParse(buffer, tokens, 0, expected);
}

test "comma separated" {
    const buffer = "1,2,3";
    const tokens = &[_]Token{
        Token.lex(TK.lit_number, 0, 1),
        tok.createToken(TK.sep_comma),
        Token.lex(TK.lit_number, 2, 1),
        tok.createToken(TK.sep_comma),
        Token.lex(TK.lit_number, 4, 1),
    };
    const expected = &[_]Token{
        tok64(0x0000000000003900),
        tok64(0x0001000000003100),
        tok64(0x0001000000023100),
        tok64(0x0001000000043100),
    };
    try testPrattParse(buffer, tokens, 0, expected);
}

test "single literal" {
    const buffer = "42";
    const tokens = &[_]Token{
        Token.lex(TK.lit_number, 0, 2),
    };
    const expected = &[_]Token{
        tok64(0x0000000000003900),
        tok64(0x0002000000003100),
    };
    try testPrattParse(buffer, tokens, 0, expected);
}

test "modulo" {
    const buffer = "7%3";
    const tokens = &[_]Token{
        Token.lex(TK.lit_number, 0, 1),
        tok.createToken(TK.op_mod),
        Token.lex(TK.lit_number, 2, 1),
    };
    const expected = &[_]Token{
        tok64(0x0000000000003900),
        tok64(0x0001000000003100),
        tok64(0x0001000000023100),
        tok64(0x0000000000001400),
    };
    try testPrattParse(buffer, tokens, 0, expected);
}

test "mixed precedence mul add sub" {
    const buffer = "1+2*3-4";
    const tokens = &[_]Token{
        Token.lex(TK.lit_number, 0, 1),
        tok.createToken(TK.op_add),
        Token.lex(TK.lit_number, 2, 1),
        tok.createToken(TK.op_mul),
        Token.lex(TK.lit_number, 4, 1),
        tok.createToken(TK.op_sub),
        Token.lex(TK.lit_number, 6, 1),
    };
    const expected = &[_]Token{
        tok64(0x0000000000003900),
        tok64(0x0001000000003100),
        tok64(0x0001000000023100),
        tok64(0x0001000000043100),
        tok64(0x0000000000001300),
        tok64(0x0000000000001200),
        tok64(0x0001000000063100),
        tok64(0x0000000000001000),
    };
    try testPrattParse(buffer, tokens, 0, expected);
}
