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
const back = testutils.back;

fn testParse(buffer: []const u8, tokens: []const Token, aux: []const Token, expected: []const Token) !void {
    var syntaxQ = TokenQueue.init(test_allocator);
    var auxQ = TokenQueue.init(test_allocator);
    var parsedQ = TokenQueue.init(test_allocator);
    var offsetQ = OffsetQueue.init(test_allocator);
    var resolution = try rs.Resolution.init(test_allocator, 64, &parsedQ);
    defer syntaxQ.deinit();
    defer auxQ.deinit();
    defer parsedQ.deinit();
    defer offsetQ.deinit();
    defer resolution.deinit();

    try testutils.pushAll(&syntaxQ, tokens);
    try testutils.pushAll(&auxQ, aux);
    var p = parser_mod.Parser.init(buffer, &syntaxQ, &auxQ, &parsedQ, &offsetQ, test_allocator, &resolution);
    try p.startParse();

    try testutils.testQueueEquals(buffer, &parsedQ, expected);
}

fn tok64(comptime bits: u64) Token {
    return @bitCast(bits);
}

/// Helpers for constructing chained group tokens with explicit offsets.
fn gopen(kind: Kind, next: i16, iter: i16) Token {
    var t = Token.groupOpen(kind);
    t.data.group_link.next_offset = next;
    t.data.group_link.iter_offset = iter;
    return t;
}

/// Fn-param open paren: prev_offset is overloaded to point at the matching close.
fn gopenFn(kind: Kind, prev: i16, next: i16, iter: i16) Token {
    var t = Token.groupOpen(kind);
    t.data.group_link = .{ .prev_offset = prev, .next_offset = next, .iter_offset = iter };
    return t;
}

fn gsep(prev: i16, next: i16, iter: i16) Token {
    var t = Token.groupSep();
    t.data.group_link = .{ .prev_offset = prev, .next_offset = next, .iter_offset = iter };
    return t;
}

fn gclose(kind: Kind, prev: i16, iter: i16) Token {
    var t = Token.groupClose(kind);
    t.data.group_link.prev_offset = prev;
    t.data.group_link.iter_offset = iter;
    return t;
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

    try testParse(buffer, tokens, aux, expected);
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

    try testParse(buffer, tokens, aux, expected);
}

test "Parse if with else" {
    const buffer = "if 1 > 2:\n    42\nelse:\n    7";
    const tokens = &[_]Token{
        tok.createToken(TK.kw_if),
        Token.lex(TK.lit_number, 3, 1),
        tok.createToken(TK.op_gt),
        Token.lex(TK.lit_number, 7, 1),
        tok.createToken(TK.op_colon_assoc),
        tok.createToken(TK.grp_indent),
        Token.lex(TK.lit_number, 14, 2),
        tok.createToken(TK.grp_dedent),
        tok.createToken(TK.kw_else),
        tok.createToken(TK.op_colon_assoc),
        tok.createToken(TK.grp_indent),
        Token.lex(TK.lit_number, 27, 1),
        tok.createToken(TK.grp_dedent),
    };

    const aux = &[_]Token{};

    const expected = &[_]Token{
        tok.AUX_STREAM_START,
        Token.lex(TK.lit_number, 3, 1), // condition: 1
        Token.lex(TK.lit_number, 7, 1), // condition: 2
        tok.createToken(TK.op_gt), // condition: >
        tok.createToken(TK.kw_if),
        tok.createToken(TK.op_colon_assoc),
        Token.lex(TK.grp_indent, 9, 0), // patched to end=9, scopeId=0
        Token.lex(TK.lit_number, 14, 2), // then: 42
        Token.lex(TK.grp_dedent, 6, 0), // points to indent at 6
        tok.createToken(TK.kw_else),
        tok.createToken(TK.op_colon_assoc),
        Token.lex(TK.grp_indent, 14, 1), // patched to end=14, scopeId=1
        Token.lex(TK.lit_number, 27, 1), // else: 7
        Token.lex(TK.grp_dedent, 11, 1), // points to indent at 11
    };

    try testParse(buffer, tokens, aux, expected);
}

test "Parse fn definition" {
    // fn add(a, b): a + b
    // Symbol IDs: add=0, a=1, b=2
    const buffer = "fn add(a, b): a + b";
    const tokens = &[_]Token{
        tok.createToken(TK.kw_fn),
        Token.lex(TK.identifier, 0, 0), // add
        tok.createToken(TK.grp_open_paren),
        Token.lex(TK.identifier, 1, 0), // a
        tok.createToken(TK.sep_comma),
        Token.lex(TK.identifier, 2, 0), // b
        tok.createToken(TK.grp_close_paren),
        tok.createToken(TK.op_colon_assoc),
        Token.lex(TK.identifier, 1, 0), // a (body)
        tok.createToken(TK.op_add),
        Token.lex(TK.identifier, 2, 0), // b (body)
    };

    const aux = &[_]Token{};

    // parsedQ layout (param list is a positional group chain):
    //   [0] stream_start  [1] decl(add)  [2] kw_fn  [3] open
    //   [4] decl(a)       [5] sep        [6] decl(b) [7] close
    //   [8] ref(a)        [9] ref(b)     [10] op_add
    var a_decl = Token.ident(TK.identifier, 1, 0, 4); // next_offset=4 → ref at index 8
    a_decl.flags.declaration = true;
    var b_decl = Token.ident(TK.identifier, 2, 0, 3); // next_offset=3 → ref at index 9
    b_decl.flags.declaration = true;

    const expected = &[_]Token{
        tok.AUX_STREAM_START,
        Token.lex(TK.identifier, 0, 0).newDeclaration(0), // add declaration (no refs)
        Token.fnHeader(TK.kw_fn, 8, 6), // body_length=8, body_offset=6 (close@7 + 1 - header@2)
        gopenFn(TK.grp_open_paren, 4, 2, 0), // prev→close@7, next→sep@5
        a_decl,
        gsep(-2, 2, 0), // prev→open, next→close
        b_decl,
        gclose(TK.grp_close_paren, -2, 0), // prev→sep
        Token.ident(TK.identifier, 1, back(4), 0), // a resolved (prev -4)
        Token.ident(TK.identifier, 2, back(3), 0), // b resolved (prev -3)
        tok.createToken(TK.op_add),
    };

    try testParse(buffer, tokens, aux, expected);
}

test "Parse fn with const_identifier param" {
    // fn APPLY(first, SECOND): first SECOND
    // Symbol IDs: APPLY=0, first=1, SECOND=2
    // In the body, SECOND appears as op_identifier (infix); opIdentifierInfix resolves it
    // to its const_identifier declaration and emits it as a regular infix operator reference.
    const buffer = "fn APPLY(first, SECOND): first SECOND";
    const tokens = &[_]Token{
        tok.createToken(TK.kw_fn),
        Token.lex(TK.identifier, 0, 0), // APPLY
        tok.createToken(TK.grp_open_paren),
        Token.lex(TK.identifier, 1, 0), // first
        tok.createToken(TK.sep_comma),
        Token.lex(TK.const_identifier, 2, 0), // SECOND
        tok.createToken(TK.grp_close_paren),
        tok.createToken(TK.op_colon_assoc),
        Token.lex(TK.identifier, 1, 0), // first (body ref)
        Token.lex(TK.op_identifier, 2, 0), // SECOND (body ref, infix)
    };

    const aux = &[_]Token{};

    // parsedQ layout:
    //   [0] stream_start  [1] decl(APPLY)   [2] kw_fn  [3] group_open
    //   [4] decl(first)   [5] sep_comma     [6] decl(SECOND) [7] group_close
    //   [8] ref(first)    [9] ref(SECOND) [op_identifier]
    var first_decl = Token.ident(TK.identifier, 1, 0, 4); // next=4 → ref@8
    first_decl.flags.declaration = true;
    var second_decl = Token.ident(TK.const_identifier, 2, 0, 3); // next=3 → ref@9
    second_decl.flags.declaration = true;

    const expected = &[_]Token{
        tok.AUX_STREAM_START,
        Token.lex(TK.identifier, 0, 0).newDeclaration(0), // APPLY declaration (no refs)
        Token.fnHeader(TK.kw_fn, 7, 6), // body_length=7, body_offset=6
        gopenFn(TK.grp_open_paren, 4, 2, 0), // prev→close@7
        first_decl,
        gsep(-2, 2, 0),
        second_decl,
        gclose(TK.grp_close_paren, -2, 0),
        Token.ident(TK.identifier, 1, back(4), 0),
        Token.ident(TK.op_identifier, 2, back(3), 0),
    };

    try testParse(buffer, tokens, aux, expected);
}

test "Parse nullary paren group" {
    // ()
    const buffer = "()";
    const tokens = &[_]Token{
        tok.createToken(TK.grp_open_paren),
        tok.createToken(TK.grp_close_paren),
    };
    const aux = &[_]Token{};

    // [0] stream_start [1] group_open [2] group_close
    const expected = &[_]Token{
        tok.AUX_STREAM_START,
        gopen(TK.grp_open_paren, 1, 0),
        gclose(TK.grp_close_paren, -1, 0),
    };
    try testParse(buffer, tokens, aux, expected);
}

test "Parse unary paren group" {
    // (1)
    const buffer = "(1)";
    const tokens = &[_]Token{
        tok.createToken(TK.grp_open_paren),
        Token.lex(TK.lit_number, 1, 1),
        tok.createToken(TK.grp_close_paren),
    };
    const aux = &[_]Token{};

    // [0] stream_start [1] group_open [2] lit(1) [3] group_close
    const expected = &[_]Token{
        tok.AUX_STREAM_START,
        gopen(TK.grp_open_paren, 2, 0),
        Token.lex(TK.lit_number, 1, 1),
        gclose(TK.grp_close_paren, -2, 0),
    };
    try testParse(buffer, tokens, aux, expected);
}

test "Parse ternary paren group" {
    // (1, 2, 3)
    const buffer = "(1, 2, 3)";
    const tokens = &[_]Token{
        tok.createToken(TK.grp_open_paren),
        Token.lex(TK.lit_number, 1, 1),
        tok.createToken(TK.sep_comma),
        Token.lex(TK.lit_number, 4, 1),
        tok.createToken(TK.sep_comma),
        Token.lex(TK.lit_number, 7, 1),
        tok.createToken(TK.grp_close_paren),
    };
    const aux = &[_]Token{};

    // Layout: [0] start [1] open [2] lit [3] sep [4] lit [5] sep [6] lit [7] close
    // Positional chain links each separator to its neighbours; iter_offset is 0 (non-fn).
    const expected = &[_]Token{
        tok.AUX_STREAM_START,
        gopen(TK.grp_open_paren, 2, 0),
        Token.lex(TK.lit_number, 1, 1),
        gsep(-2, 2, 0),
        Token.lex(TK.lit_number, 4, 1),
        gsep(-2, 2, 0),
        Token.lex(TK.lit_number, 7, 1),
        gclose(TK.grp_close_paren, -2, 0),
    };
    try testParse(buffer, tokens, aux, expected);
}

test "Parse nested paren group" {
    // ((1), 2)
    const buffer = "((1), 2)";
    const tokens = &[_]Token{
        tok.createToken(TK.grp_open_paren),
        tok.createToken(TK.grp_open_paren),
        Token.lex(TK.lit_number, 2, 1),
        tok.createToken(TK.grp_close_paren),
        tok.createToken(TK.sep_comma),
        Token.lex(TK.lit_number, 6, 1),
        tok.createToken(TK.grp_close_paren),
    };
    const aux = &[_]Token{};

    // Layout: [0] start [1] outer_open [2] inner_open [3] lit(2) [4] inner_close
    //         [5] sep [6] lit(6) [7] outer_close
    const expected = &[_]Token{
        tok.AUX_STREAM_START,
        gopen(TK.grp_open_paren, 4, 0), // outer_open → outer_sep@5
        gopen(TK.grp_open_paren, 2, 0), // inner_open → inner_close@4
        Token.lex(TK.lit_number, 2, 1),
        gclose(TK.grp_close_paren, -2, 0), // inner_close
        gsep(-4, 2, 0), // outer_sep: prev→outer_open, next→outer_close
        Token.lex(TK.lit_number, 6, 1),
        gclose(TK.grp_close_paren, -2, 0), // outer_close
    };
    try testParse(buffer, tokens, aux, expected);
}

test "Parse bracket group" {
    // [1, 2]
    const buffer = "[1, 2]";
    const tokens = &[_]Token{
        tok.createToken(TK.grp_open_bracket),
        Token.lex(TK.lit_number, 1, 1),
        tok.createToken(TK.sep_comma),
        Token.lex(TK.lit_number, 4, 1),
        tok.createToken(TK.grp_close_bracket),
    };
    const aux = &[_]Token{};

    const expected = &[_]Token{
        tok.AUX_STREAM_START,
        gopen(TK.grp_open_bracket, 2, 0),
        Token.lex(TK.lit_number, 1, 1),
        gsep(-2, 2, 0),
        Token.lex(TK.lit_number, 4, 1),
        gclose(TK.grp_close_bracket, -2, 0),
    };
    try testParse(buffer, tokens, aux, expected);
}

test "Parse brace group" {
    // {1}
    const buffer = "{1}";
    const tokens = &[_]Token{
        tok.createToken(TK.grp_open_brace),
        Token.lex(TK.lit_number, 1, 1),
        tok.createToken(TK.grp_close_brace),
    };
    const aux = &[_]Token{};

    const expected = &[_]Token{
        tok.AUX_STREAM_START,
        gopen(TK.grp_open_brace, 2, 0),
        Token.lex(TK.lit_number, 1, 1),
        gclose(TK.grp_close_brace, -2, 0),
    };
    try testParse(buffer, tokens, aux, expected);
}

test "Parse nested calls: chains are locally scoped" {
    // f(g(1, 2), h(3, 4))
    // Verifies each call's local arg_counter doesn't cross-contaminate.
    // Symbol IDs: f=0, g=1, h=2.
    const buffer = "f(g(1, 2), h(3, 4))";
    const tokens = &[_]Token{
        Token.lex(TK.call_identifier, 0, 0), // f
        tok.createToken(TK.grp_open_paren),
        Token.lex(TK.call_identifier, 1, 0), // g
        tok.createToken(TK.grp_open_paren),
        Token.lex(TK.lit_number, 1, 1),
        tok.createToken(TK.sep_comma),
        Token.lex(TK.lit_number, 2, 1),
        tok.createToken(TK.grp_close_paren),
        tok.createToken(TK.sep_comma),
        Token.lex(TK.call_identifier, 2, 0), // h
        tok.createToken(TK.grp_open_paren),
        Token.lex(TK.lit_number, 3, 1),
        tok.createToken(TK.sep_comma),
        Token.lex(TK.lit_number, 4, 1),
        tok.createToken(TK.grp_close_paren),
        tok.createToken(TK.grp_close_paren),
    };
    const aux = &[_]Token{};

    // Layout:
    //   [0] start     [1] f_open    [2] g_open   [3] lit(1)   [4] g_sep
    //   [5] lit(2)    [6] g_close   [7] g        [8] f_sep    [9] h_open
    //   [10] lit(3)   [11] h_sep    [12] lit(4)  [13] h_close [14] h
    //   [15] f_close  [16] f
    // Each call's chain is self-contained — f_sep links f_open↔f_close only,
    // proving nested groups don't cross-contaminate.
    const expected = &[_]Token{
        tok.AUX_STREAM_START,
        gopen(TK.grp_open_paren, 7, 0), // f_open → f_sep@8
        gopen(TK.grp_open_paren, 2, 0), // g_open → g_sep@4
        Token.lex(TK.lit_number, 1, 1),
        gsep(-2, 2, 0), // g_sep: prev→g_open, next→g_close
        Token.lex(TK.lit_number, 2, 1),
        gclose(TK.grp_close_paren, -2, 0), // g_close
        Token.lex(TK.call_identifier, 1, 0), // g emitted post-group
        gsep(-7, 7, 0), // f_sep: prev→f_open, next→f_close
        gopen(TK.grp_open_paren, 2, 0), // h_open → h_sep@11
        Token.lex(TK.lit_number, 3, 1),
        gsep(-2, 2, 0), // h_sep
        Token.lex(TK.lit_number, 4, 1),
        gclose(TK.grp_close_paren, -2, 0), // h_close
        Token.lex(TK.call_identifier, 2, 0), // h emitted post-group
        gclose(TK.grp_close_paren, -7, 0), // f_close
        Token.lex(TK.call_identifier, 0, 0), // f emitted post-group
    };
    try testParse(buffer, tokens, aux, expected);
}

test "Parse fn body_offset points to first body token" {
    // fn f(a, b, c): a
    // Verifies body_offset = close_paren_idx + 1 - header_idx.
    // Symbol IDs: f=0, a=1, b=2, c=3.
    const buffer = "fn f(a, b, c): a";
    const tokens = &[_]Token{
        tok.createToken(TK.kw_fn),
        Token.lex(TK.identifier, 0, 0), // f
        tok.createToken(TK.grp_open_paren),
        Token.lex(TK.identifier, 1, 0), // a
        tok.createToken(TK.sep_comma),
        Token.lex(TK.identifier, 2, 0), // b
        tok.createToken(TK.sep_comma),
        Token.lex(TK.identifier, 3, 0), // c
        tok.createToken(TK.grp_close_paren),
        tok.createToken(TK.op_colon_assoc),
        Token.lex(TK.identifier, 1, 0), // a (body)
    };
    const aux = &[_]Token{};

    // parsedQ layout:
    //   [0] start  [1] decl(f)  [2] kw_fn  [3] open
    //   [4] decl(a)  [5] sep(1)  [6] decl(b)  [7] sep(2)  [8] decl(c)  [9] close
    //   [10] ref(a)
    // header_idx=2, close_paren_idx=9, body_offset=9+1-2=8.
    // body_length = parsedQ.len - header_idx - 1 = 11 - 2 - 1 = 8.
    // header_idx + body_offset = 2 + 8 = 10 → ref(a), the first body token.
    var a_decl = Token.ident(TK.identifier, 1, 0, 6); // next→ref@10 (10-4=6)
    a_decl.flags.declaration = true;
    var b_decl = Token.ident(TK.identifier, 2, 0, 0); // unused in body
    b_decl.flags.declaration = true;
    var c_decl = Token.ident(TK.identifier, 3, 0, 0); // unused in body
    c_decl.flags.declaration = true;

    const expected = &[_]Token{
        tok.AUX_STREAM_START,
        Token.lex(TK.identifier, 0, 0).newDeclaration(0), // decl(f)
        Token.fnHeader(TK.kw_fn, 8, 8), // body_length=8, body_offset=8
        gopenFn(TK.grp_open_paren, 6, 2, 0), // prev→close@9
        a_decl,
        gsep(-2, 2, 0),
        b_decl,
        gsep(-2, 2, 0),
        c_decl,
        gclose(TK.grp_close_paren, -2, 0),
        Token.ident(TK.identifier, 1, back(6), 0), // ref(a), prev→decl@4
    };
    try testParse(buffer, tokens, aux, expected);
}
