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

    // parsedQ layout (param list is a group chain; all-eager iter chain close → open → sep → 0):
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
        gopen(TK.grp_open_paren, 2, 2), // next→sep@5, iter→sep@5
        a_decl,
        gsep(-2, 2, 0), // prev→open, next→close, iter terminator
        b_decl,
        gclose(TK.grp_close_paren, -2, -4), // prev→sep, iter head→open@3
        Token.ident(TK.identifier, 1, back(4), 0), // a resolved (prev -4)
        Token.ident(TK.identifier, 2, back(3), 0), // b resolved (prev -3)
        tok.createToken(TK.op_add),
    };

    try testParse(buffer, tokens, aux, expected);
}

test "Parse lazy fn with splice detection" {
    // fn APPLY(first, SECOND): first SECOND
    // Symbol IDs: APPLY=0, first=1, SECOND=2
    // 'first' is identifier (eager), 'SECOND' is const_identifier (lazy)
    // In the body, SECOND appears as op_identifier (infix use); kwFn rewrites its kind to ident_splice.
    const buffer = "fn APPLY(first, SECOND): first SECOND";
    const tokens = &[_]Token{
        tok.createToken(TK.kw_fn),
        Token.lex(TK.identifier, 0, 0), // APPLY
        tok.createToken(TK.grp_open_paren),
        Token.lex(TK.identifier, 1, 0), // first (eager)
        tok.createToken(TK.sep_comma),
        Token.lex(TK.const_identifier, 2, 0), // SECOND (lazy)
        tok.createToken(TK.grp_close_paren),
        tok.createToken(TK.op_colon_assoc),
        Token.lex(TK.identifier, 1, 0), // first (body ref)
        Token.lex(TK.op_identifier, 2, 0), // SECOND (body ref, infix)
    };

    const aux = &[_]Token{};

    // parsedQ layout:
    //   [0] stream_start  [1] decl(APPLY)   [2] kw_fn  [3] group_open
    //   [4] decl(first)   [5] sep_comma     [6] decl(SECOND) [7] group_close
    //   [8] ref(first)    [9] ident_splice(SECOND)
    var first_decl = Token.ident(TK.identifier, 1, 0, 4); // next=4 → ref@8
    first_decl.flags.declaration = true;
    var second_decl = Token.ident(TK.const_identifier, 2, 0, 3); // next=3 → ref@9
    second_decl.flags.declaration = true;
    const expectedSplice = Token.ident(TK.ident_splice, 2, back(3), 0); // prev=-3, kind rewritten by kwFn

    const expected = &[_]Token{
        tok.AUX_STREAM_START,
        Token.lex(TK.identifier, 0, 0).newDeclaration(0), // APPLY declaration (no refs)
        Token.fnHeader(TK.kw_lazy_fn, 7, 6), // body_length=7, body_offset=6
        gopen(TK.grp_open_paren, 2, 2),
        first_decl,
        gsep(-2, 2, 0),
        second_decl,
        gclose(TK.grp_close_paren, -2, -4),
        Token.ident(TK.identifier, 1, back(4), 0),
        expectedSplice,
    };

    try testParse(buffer, tokens, aux, expected);
}

// Removed: "Parse eager fn inline expansion" — per design D6, pure-eager infix no longer
// inlines (fn ADD(a,b): a+b ; 3 ADD 4 falls through to the binary-op path). Lazy inline
// expansion is covered by "Parse lazy fn inline expansion" below.

fn testParseError(buffer: []const u8, tokens: []const Token, aux: []const Token, expected_err: anyerror) !void {
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
    try std.testing.expectError(expected_err, p.startParse());
}

test "Lazy param unused raises diagnostic" {
    // fn F(X): 0 — X is lazy but never referenced in the body.
    const buffer = "fn F(X): 0";
    const tokens = &[_]Token{
        tok.createToken(TK.kw_fn),
        Token.lex(TK.identifier, 0, 0), // F
        tok.createToken(TK.grp_open_paren),
        Token.lex(TK.const_identifier, 1, 0), // X (lazy)
        tok.createToken(TK.grp_close_paren),
        tok.createToken(TK.op_colon_assoc),
        Token.lex(TK.lit_number, 0, 0),
    };
    try testParseError(buffer, tokens, &[_]Token{}, error.LazyParamUnused);
}

test "Lazy param used more than once raises diagnostic" {
    // fn F(X): X + X — X is lazy but referenced twice.
    const buffer = "fn F(X): X + X";
    const tokens = &[_]Token{
        tok.createToken(TK.kw_fn),
        Token.lex(TK.identifier, 0, 0), // F
        tok.createToken(TK.grp_open_paren),
        Token.lex(TK.const_identifier, 1, 0), // X (lazy)
        tok.createToken(TK.grp_close_paren),
        tok.createToken(TK.op_colon_assoc),
        Token.lex(TK.const_identifier, 1, 0), // X (first use)
        tok.createToken(TK.op_add),
        Token.lex(TK.const_identifier, 1, 0), // X (second use)
    };
    try testParseError(buffer, tokens, &[_]Token{}, error.LazyParamUsedMoreThanOnce);
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

test "Parse lazy fn inline expansion" {
    // fn PICK(first, SECOND): SECOND
    // 0 PICK 42
    // Symbol IDs: PICK=0, first=1, SECOND=2
    const buffer = "fn PICK(first, SECOND): SECOND\n0 PICK 42";
    const tokens = &[_]Token{
        // fn definition
        tok.createToken(TK.kw_fn),
        Token.lex(TK.identifier, 0, 0), // PICK
        tok.createToken(TK.grp_open_paren),
        Token.lex(TK.identifier, 1, 0), // first (eager)
        tok.createToken(TK.sep_comma),
        Token.lex(TK.const_identifier, 2, 0), // SECOND (lazy)
        tok.createToken(TK.grp_close_paren),
        tok.createToken(TK.op_colon_assoc),
        Token.lex(TK.const_identifier, 2, 0), // body: SECOND
        tok.createToken(TK.sep_newline),
        // call: 0 PICK 42
        Token.lex(TK.lit_number, 0, 0),
        Token.lex(TK.op_identifier, 0, 0), // PICK operator
        Token.lex(TK.lit_number, 42, 0),
    };

    const aux = &[_]Token{};

    // parsedQ layout (Phase A):
    //   [0] stream_start  [1] decl(PICK)    [2] kw_lazy_fn       [3] group_open
    //   [4] decl(first)   [5] sep_comma     [6] decl(SECOND)     [7] group_close
    //   [8] ident_splice(SECOND)
    //   [9] lit(0)        [10] declFirst    [11] lit(42)
    //
    // Phantom resolve of "PICK" at items.len=10, patches decl(PICK)@1 next_offset = 9.
    var pick_decl = Token.ident(TK.identifier, 0, 0, 9);
    pick_decl.flags.declaration = true;

    var second_decl = Token.ident(TK.const_identifier, 2, 0, 2); // next=2 → ref@8
    second_decl.flags.declaration = true;

    // Body SECOND ref at index 8: kind rewritten from const_identifier to ident_splice by kwFn.
    // prev=-2 to decl@6.
    const bodySplice = Token.ident(TK.ident_splice, 2, back(2), 0);

    // declFirst@10 shadow-chains to decl(first)@4 (tail of the chain since first unused in body).
    // calcOffset(4, 10) = -6 = back(6). Synthesised with kind=ident_splice so codegen pops the
    // operand already on the stack.
    const declFirst = Token.lex(TK.ident_splice, 1, 0).newDeclaration(back(6));

    const expected = &[_]Token{
        tok.AUX_STREAM_START,
        // fn definition
        pick_decl,
        Token.fnHeader(TK.kw_lazy_fn, 6, 6), // body_length=6, body_offset=6
        gopen(TK.grp_open_paren, 2, 2), // body parse extends iter to sep@5 (SECOND's sep)
        Token.lex(TK.identifier, 1, 0).newDeclaration(0), // first param decl (no refs)
        gsep(-2, 2, 0),
        second_decl,
        gclose(TK.grp_close_paren, -2, -4),
        bodySplice,
        // call site
        Token.lex(TK.lit_number, 0, 0), // left operand
        declFirst, // decl(first) ident_splice — binds to left operand
        Token.lex(TK.lit_number, 42, 0), // right operand parsed at splice point
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
        gopen(TK.grp_open_paren, 2, 2), // iter → sep@5 (b's sep)
        a_decl,
        gsep(-2, 2, 2), // iter → sep@7 (c's sep)
        b_decl,
        gsep(-2, 2, 0), // iter terminator
        c_decl,
        gclose(TK.grp_close_paren, -2, -6), // head anchor → open@3
        Token.ident(TK.identifier, 1, back(6), 0), // ref(a), prev→decl@4
    };
    try testParse(buffer, tokens, aux, expected);
}

test "Parse N-ary prefix inline expansion" {
    // fn add2(a, B): a + B
    // add2(3, 4)
    // Symbol IDs: add2=0, a=1, B=2.
    // Eager slot 0 (a), lazy slot 1 (B). Prefix call routes through callExprInline.
    const buffer = "fn add2(a, B): a + B\nadd2(3, 4)";
    const tokens = &[_]Token{
        // fn definition
        tok.createToken(TK.kw_fn),
        Token.lex(TK.call_identifier, 0, 0), // add2
        tok.createToken(TK.grp_open_paren),
        Token.lex(TK.identifier, 1, 0), // a (eager)
        tok.createToken(TK.sep_comma),
        Token.lex(TK.const_identifier, 2, 0), // B (lazy)
        tok.createToken(TK.grp_close_paren),
        tok.createToken(TK.op_colon_assoc),
        Token.lex(TK.identifier, 1, 0), // a (body)
        tok.createToken(TK.op_add),
        Token.lex(TK.const_identifier, 2, 0), // B (body)
        tok.createToken(TK.sep_newline),
        // call: add2(3, 4)
        Token.lex(TK.call_identifier, 0, 0), // add2
        tok.createToken(TK.grp_open_paren),
        Token.lex(TK.lit_number, 3, 0),
        tok.createToken(TK.sep_comma),
        Token.lex(TK.lit_number, 4, 0),
        tok.createToken(TK.grp_close_paren),
    };
    const aux = &[_]Token{};

    // parsedQ layout:
    //   [0] start  [1] decl(add2)  [2] kw_lazy_fn  [3] open
    //   [4] decl(a)  [5] sep(1)  [6] decl(B)  [7] close
    //   [8] ref(a)  [9] splice(B)  [10] op_add
    //   -- call expansion: eager args parsed, lazy args replayed from syntaxQ at splice --
    //   [11] lit(3)  [12] synth decl(a)
    //   [13] re-resolved ref(a)  [14] lit(4) from syntaxQ  [15] op_add
    var add2_decl = Token.ident(TK.call_identifier, 0, 0, 0);
    add2_decl.flags.declaration = true;

    var a_decl_param = Token.ident(TK.identifier, 1, 0, 4); // next→ref@8
    a_decl_param.flags.declaration = true;
    var b_decl_param = Token.ident(TK.const_identifier, 2, 0, 3); // next→splice@9
    b_decl_param.flags.declaration = true;

    // synth_a @12: shadows body ref(a)@8. Re-resolve at @13 patches next_offset=1.
    var synth_a = Token.lex(TK.ident_splice, 1, 0).newDeclaration(back(4));
    synth_a.data.ident.next_offset = 1;

    const expected = &[_]Token{
        tok.AUX_STREAM_START,
        add2_decl,
        Token.fnHeader(TK.kw_lazy_fn, 8, 6),
        gopen(TK.grp_open_paren, 2, 2), // iter extended to sep@5 when B referenced in body
        a_decl_param,
        gsep(-2, 2, 0),
        b_decl_param,
        gclose(TK.grp_close_paren, -2, -4),
        Token.ident(TK.identifier, 1, back(4), 0), // body ref(a) @8
        Token.ident(TK.ident_splice, 2, back(3), 0), // body splice(B) @9
        tok.createToken(TK.op_add), // body op_add @10
        // call expansion — no shims, lazy args parsed directly from syntaxQ at splice:
        Token.lex(TK.lit_number, 3, 0), // eager arg @11
        synth_a, // synth decl(a) @12
        Token.ident(TK.identifier, 1, back(1), 0), // re-resolved ref(a) @13
        Token.lex(TK.lit_number, 4, 0), // lazy arg from syntaxQ @14
        tok.createToken(TK.op_add), // @15
    };
    try testParse(buffer, tokens, aux, expected);
}

test "Parse reordered lazy iter chain" {
    // fn F(A, b, C): A + C
    // Positional params: A (lazy), b (eager, unused in body), C (lazy).
    // Body references A then C (both lazy, in body-ref order).
    // Expected iter order: [b (eager), A (lazy 1st ref), C (lazy 2nd ref)].
    // Chain: close@9.iter → sep@5 (b), sep@5.iter → open@3 (A), open@3.iter → sep@7 (C), sep@7.iter = 0.
    // Symbol ids: F=0, A=1, b=2, C=3.
    const buffer = "fn F(A, b, C): A + C";
    const tokens = &[_]Token{
        tok.createToken(TK.kw_fn),
        Token.lex(TK.identifier, 0, 0), // F
        tok.createToken(TK.grp_open_paren),
        Token.lex(TK.const_identifier, 1, 0), // A (lazy)
        tok.createToken(TK.sep_comma),
        Token.lex(TK.identifier, 2, 0), // b (eager, unused)
        tok.createToken(TK.sep_comma),
        Token.lex(TK.const_identifier, 3, 0), // C (lazy)
        tok.createToken(TK.grp_close_paren),
        tok.createToken(TK.op_colon_assoc),
        Token.lex(TK.const_identifier, 1, 0), // body: A
        tok.createToken(TK.op_add),
        Token.lex(TK.const_identifier, 3, 0), // body: C
    };
    const aux = &[_]Token{};

    // parsedQ layout:
    //   [0] start  [1] decl(F)  [2] kw_lazy_fn  [3] open
    //   [4] decl(A)  [5] sep  [6] decl(b)  [7] sep  [8] decl(C)  [9] close
    //   [10] splice(A)  [11] splice(C)  [12] op_add
    var a_decl = Token.ident(TK.const_identifier, 1, 0, 6); // next→splice(A)@10
    a_decl.flags.declaration = true;
    var b_decl = Token.ident(TK.identifier, 2, 0, 0); // unused in body
    b_decl.flags.declaration = true;
    var c_decl = Token.ident(TK.const_identifier, 3, 0, 3); // next→splice(C)@11
    c_decl.flags.declaration = true;

    const expected = &[_]Token{
        tok.AUX_STREAM_START,
        Token.lex(TK.identifier, 0, 0).newDeclaration(0), // decl(F)
        Token.fnHeader(TK.kw_lazy_fn, 10, 8),
        gopen(TK.grp_open_paren, 2, 4), // iter → sep@7 (C's sep, set on 2nd lazy extension)
        a_decl,
        gsep(-2, 2, -2), // iter → open@3 (A's sep, set on 1st lazy extension)
        b_decl,
        gsep(-2, 2, 0), // iter terminator
        c_decl,
        gclose(TK.grp_close_paren, -2, -4), // head anchor → sep@5 (b's sep, eager)
        Token.ident(TK.ident_splice, 1, back(6), 0), // splice(A) @10
        Token.ident(TK.ident_splice, 3, back(3), 0), // splice(C) @11
        tok.createToken(TK.op_add),
    };
    try testParse(buffer, tokens, aux, expected);
}
