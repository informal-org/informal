const std = @import("std");
const tok = @import("../token.zig");
const q = @import("../queue.zig");
const lexer_mod = @import("../lexer.zig");

const Token = tok.Token;
const TK = tok.Kind;
const TokenQueue = q.Queue(Token, tok.AUX_STREAM_END);
const StringArrayHashMap = std.array_hash_map.StringArrayHashMap;
const Lexer = lexer_mod.Lexer;

const test_allocator = std.testing.allocator;
const expect = std.testing.expect;
const expectEqual = std.testing.expectEqual;
const testutils = @import("./testutils.zig");
const testQueueEquals = testutils.testQueueEquals;

fn testToken(buffer: []u8, expected: []const Token, aux: ?[]const Token) !void {
    var syntaxQ = TokenQueue.init(test_allocator);
    var auxQ = TokenQueue.init(test_allocator);
    var internedStrings = StringArrayHashMap(u64).init(test_allocator);
    var internedNumbers = std.AutoHashMap(u64, u64).init(test_allocator);
    var internedFloats = std.AutoHashMap(f64, u64).init(test_allocator);
    var symbolTable = std.StringHashMap(u64).init(test_allocator);

    var lexer = Lexer.init(buffer, &syntaxQ, &auxQ, &internedStrings, &internedNumbers, &internedFloats, &symbolTable);

    defer syntaxQ.deinit();
    defer auxQ.deinit();
    defer internedStrings.deinit();
    defer internedNumbers.deinit();
    defer internedFloats.deinit();
    defer symbolTable.deinit();
    try lexer.lex();

    try testQueueEquals(buffer, &syntaxQ, expected);
    if (aux) |auxExpected| {
        try testQueueEquals(buffer, &auxQ, auxExpected);
    }
}

fn testSymbol(buf: []const u8, kind: TK) !void {
    try testToken(@constCast(buf), &[_]Token{tok.createToken(kind).nextAlt()}, &[_]Token{ tok.AUX_STREAM_START.nextAlt(), tok.AUX_STREAM_END });
}

test "Token equality" {
    const auxtok_bits: u64 = @bitCast(Token.lex(TK.aux_stream_end, 3, 5));
    const le_expected_bits: u64 = 0x000005_00000003_ff_00;
    try expect(auxtok_bits == le_expected_bits);

    const other_bits: u64 = @bitCast(Token.lex(TK.aux, 10, 20));
    try expect(other_bits != le_expected_bits);

    const numtok: u64 = @bitCast(Token.lex(TK.lit_number, 0, 1));
    const numother: u64 = @bitCast(Token.lex(TK.lit_number, 5, 10));
    try expect(numtok != numother);
}

test "Lex digits" {
    var buffer = "23 101 3".*;
    try testToken(&buffer, &[_]Token{
        Token.lex(TK.lit_number, 23, 2).nextAlt(),
        Token.lex(TK.lit_number, 101, 3).nextAlt(),
        Token.lex(TK.lit_number, 3, 1).nextAlt(),
    }, &[_]Token{ tok.AUX_STREAM_START.nextAlt(), Token.lex(TK.aux_whitespace, 2, 1).nextAlt(), Token.lex(TK.aux_whitespace, 6, 1).nextAlt(), tok.AUX_STREAM_END });
}

test "Lex symbols" {
    try testSymbol("%", TK.op_mod);
    try testSymbol("(", TK.grp_open_paren);
    try testSymbol(")", TK.grp_close_paren);
    try testSymbol("*", TK.op_mul);
    try testSymbol("+", TK.op_add);
    try testSymbol(",", TK.sep_comma);
    try testSymbol("-", TK.op_sub);
    try testSymbol(".", TK.op_dot_member);
    try testSymbol("/", TK.op_div);
    try testSymbol(":", TK.op_colon_assoc);
    try testSymbol("<", TK.op_lt);
    try testSymbol("=", TK.op_assign_eq);
    try testSymbol(">", TK.op_gt);
    try testSymbol("[", TK.grp_open_bracket);
    try testSymbol("]", TK.grp_close_bracket);
    try testSymbol("^", TK.op_pow);
    try testSymbol("{", TK.grp_open_brace);
    try testSymbol("|", TK.op_choice);
    try testSymbol("}", TK.grp_close_brace);
}

test "Lex delimiters and identifiers" {
    var buffer = "(a, bb):".*;
    try testToken(&buffer, &[_]Token{
        tok.createToken(TK.grp_open_paren),
        Token.lex(TK.identifier, 0, 1),
        tok.createToken(TK.sep_comma).nextAlt(),
        Token.lex(TK.identifier, 1, 2),
        tok.createToken(TK.grp_close_paren),
        tok.createToken(TK.op_colon_assoc).nextAlt(),
    }, null);
}

test "Lex assignment" {
    var buffer = "a = 1".*;
    try testToken(&buffer, &[_]Token{
        Token.lex(TK.identifier, 0, 1).nextAlt(),
        tok.createToken(TK.op_assign_eq).nextAlt(),
        Token.lex(TK.lit_number, 1, 1).nextAlt(),
    }, null);
}

test "Identifier with space" {
    var buffer = "hello world".*;
    try testToken(&buffer, &[_]Token{
        Token.lex(TK.identifier, 0, 11).nextAlt(),
    }, null);
}

test "Identifier with trailing space" {
    var buffer = "hello world ".*;
    try testToken(&buffer, &[_]Token{
        Token.lex(TK.identifier, 0, 11).nextAlt(),
    }, null);
}

test "Multiple multipart identifiers" {
    var buffer = "a b c + cd efg".*;
    try testToken(&buffer, &[_]Token{
        Token.lex(TK.identifier, 0, 5).nextAlt(),
        tok.createToken(TK.op_add).nextAlt(),
        Token.lex(TK.identifier, 1, 6).nextAlt(),
    }, null);
}

test "Multiple consecutive spaces in identifier" {
    var buffer = "hello  world".*;
    try testToken(&buffer, &[_]Token{
        Token.lex(TK.identifier, 0, 5).nextAlt(),
        Token.lex(TK.identifier, 1, 5).nextAlt(),
    }, null);
}

test "Identifiers with operator separators" {
    var buffer = "aa OR bb".*;
    try testToken(&buffer, &[_]Token{
        Token.lex(TK.identifier, 0, 2).nextAlt(),
        tok.createToken(TK.op_or).nextAlt(),
        Token.lex(TK.identifier, 1, 2).nextAlt(),
    }, null);
}

test "Lex def keyword" {
    var buffer = "fn".*;
    try testToken(&buffer, &[_]Token{
        tok.createToken(TK.kw_fn).nextAlt(),
    }, null);
}

test "Lex type" {
    var buffer = "HelloWorld".*;
    try testToken(&buffer, &[_]Token{
        Token.lex(TK.type_identifier, 0, 10).nextAlt(),
    }, null);
}

test "Lex constant" {
    var buffer = "HELLO_WORLD".*;
    try testToken(&buffer, &[_]Token{
        Token.lex(TK.const_identifier, 0, 11).nextAlt(),
    }, null);
}

test "Lex non-builtin operator" {
    var buffer = "aa SOME_OP bbb".*;
    try testToken(&buffer, &[_]Token{
        Token.lex(TK.identifier, 0, 2).nextAlt(),
        Token.lex(TK.op_identifier, 1, 7).nextAlt(),
        Token.lex(TK.identifier, 2, 3).nextAlt(),
    }, null);
}

test "Test indentation" {
    const source =
        \\a
        \\  b
        \\  b2
        \\     c
        \\       d
        \\  b3
    ;
    try testToken(@constCast(source), &[_]Token{
        Token.lex(TK.identifier, 0, 1), // a
        Token.lex(TK.sep_newline, 1, 1).nextAlt(),
        tok.GRP_INDENT,
        Token.lex(TK.identifier, 1, 1), // b
        Token.lex(TK.sep_newline, 2, 2).nextAlt(),
        Token.lex(TK.identifier, 2, 2), // b2
        Token.lex(TK.sep_newline, 3, 1).nextAlt(),
        tok.GRP_INDENT,
        Token.lex(TK.identifier, 3, 1), // c
        Token.lex(TK.sep_newline, 4, 2).nextAlt(),
        tok.GRP_INDENT,
        Token.lex(TK.identifier, 4, 1), // d
        Token.lex(TK.sep_newline, 5, 2).nextAlt(),
        tok.GRP_DEDENT,
        tok.GRP_DEDENT,
        Token.lex(TK.identifier, 5, 2), // b3
        tok.GRP_DEDENT.nextAlt(),
    }, null);
}
