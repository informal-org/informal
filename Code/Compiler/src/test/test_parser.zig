const tok = @import("../token.zig");
const Kind = tok.Kind;
const std = @import("std");
const q = @import("../queue.zig");
const rs = @import("../resolution.zig");

const Token = tok.Token;
const TK = Kind;

const test_allocator = std.testing.allocator;
const testutils = @import("./testutils.zig");
const parser_mod = @import("../parser.zig");
const TokenQueue = parser_mod.TokenQueue;
const OffsetQueue = parser_mod.OffsetQueue;
const back = testutils.back;
const expectEqual = std.testing.expectEqual;

// TODO: There's some better version of this we can setup as a parser helper, where there's an explicit deinit method which the test can call once its done.
// Separate out the definition from the equality checks, so you can still access the full parser internals.
// Also need basic variants which lets us just verify the parsed queue is as expected, without a ton of extra ceremony or caring about all of the metadata each token kind captures.
// There should be explicit tests which do care about certain token kind's metadata. That way adding/changing metadata doesn't require rewriting a ton of tests.
// The surface area tested is more minimal per test. File tests handle the coarser grained tests.

fn testParseEquals(buffer: []const u8, tokens: []const Token, aux: []const Token, expected: []const Token) !void {
    var syntaxQ = try TokenQueue.init(test_allocator);
    var auxQ = try TokenQueue.init(test_allocator);
    try syntaxQ.reserve(buffer.len);
    try auxQ.reserve(buffer.len);
    var parsedQ = try TokenQueue.init(test_allocator);
    try parsedQ.reserve(buffer.len);
    var offsetQ = try OffsetQueue.init(test_allocator);
    var resolution = try rs.Resolution.init(test_allocator, 64, &parsedQ);
    defer syntaxQ.deinit();
    defer auxQ.deinit();
    defer parsedQ.deinit();
    defer offsetQ.deinit();
    defer resolution.deinit();

    try testutils.pushAll(&syntaxQ, tokens);
    try testutils.pushAll(&auxQ, aux);
    try parsedQ.reserve(tokens.len + 1);
    try offsetQ.reserve(tokens.len + 1);
    var p = parser_mod.Parser.init(buffer, &syntaxQ, &auxQ, &parsedQ, &offsetQ, test_allocator, &resolution);
    p.startParse();

    try testutils.testQueueEquals(buffer, &parsedQ, expected);
}

test "Parse basic add" {
    const buffer = "1+3";
    const tokens = &[_]Token{ Token.lex(TK.lit_number, 0, 1), tok.createToken(TK.op_add), Token.lex(TK.lit_number, 2, 1).nextAlt() };

    const aux = &[_]Token{};

    const expected = &[_]Token{
        tok.AUX_STREAM_START,
        Token.lex(TK.lit_number, 0, 1),
        // next-alt bit doesn't have much meaning in the parsed expr...
        Token.lex(TK.lit_number, 2, 1).nextAlt(),
        tok.createToken(TK.op_add),
    };

    try testParseEquals(buffer, tokens, aux, expected);
}

test "Parse math op precedence" {
    const buffer = "1+2*3";
    const tokens = &[_]Token{
        Token.lex(TK.lit_number, 0, 1),
        tok.createToken(TK.op_add),
        Token.lex(TK.lit_number, 2, 1),
        tok.createToken(TK.op_mul),
        Token.lex(TK.lit_number, 4, 1),
    };

    const aux = &[_]Token{};
    // Ensure multiply before add.
    const expected = &[_]Token{ tok.AUX_STREAM_START, Token.lex(TK.lit_number, 0, 1), Token.lex(TK.lit_number, 2, 1), Token.lex(TK.lit_number, 4, 1), tok.createToken(TK.op_mul), tok.createToken(TK.op_add) };

    try testParseEquals(buffer, tokens, aux, expected);
}

test "Parse kind counts" {
    const buffer = "1+2*3";
    const tokens = &[_]Token{
        Token.lex(TK.lit_number, 0, 1),
        tok.createToken(TK.op_add),
        Token.lex(TK.lit_number, 2, 1),
        tok.createToken(TK.op_mul),
        Token.lex(TK.lit_number, 4, 1),
    };
    const aux = &[_]Token{};

    var syntaxQ = try TokenQueue.init(test_allocator);
    var auxQ = try TokenQueue.init(test_allocator);
    var offsetQ = try OffsetQueue.init(test_allocator);
    var parsedQ = try TokenQueue.init(test_allocator);
    defer parsedQ.deinit();
    var resolution = try rs.Resolution.init(test_allocator, 64, &parsedQ);
    defer syntaxQ.deinit();
    defer auxQ.deinit();
    defer offsetQ.deinit();
    defer resolution.deinit();

    try testutils.pushAll(&syntaxQ, tokens);
    try testutils.pushAll(&auxQ, aux);
    try parsedQ.reserve(tokens.len + 1);
    try offsetQ.reserve(tokens.len + 1);
    var p = parser_mod.Parser.init(buffer, &syntaxQ, &auxQ, &parsedQ, &offsetQ, test_allocator, &resolution);
    p.startParse();

    try expectEqual(3, p.kindCounts[@intFromEnum(TK.lit_number)]);
    try expectEqual(1, p.kindCounts[@intFromEnum(TK.op_add)]);
    try expectEqual(1, p.kindCounts[@intFromEnum(TK.op_mul)]);
}
