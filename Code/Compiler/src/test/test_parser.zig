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
    defer p.deinit();
    try p.startParse();

    try testutils.testQueueEquals(buffer, &parsedQ, expected);
}

fn tok64(comptime bits: u64) Token {
    return @bitCast(bits);
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

    // parsedQ layout (Phase A: param list is a group chain):
    //   [0] stream_start  [1] decl(add)  [2] kw_fn  [3] group_open
    //   [4] decl(a)       [5] sep_comma  [6] decl(b) [7] group_close
    //   [8] ref(a)        [9] ref(b)     [10] op_add
    var a_decl = Token.ident(TK.identifier, 1, 0, 4); // next_offset=4 → ref at index 8
    a_decl.flags.declaration = true;
    var b_decl = Token.ident(TK.identifier, 2, 0, 3); // next_offset=3 → ref at index 9
    b_decl.flags.declaration = true;

    const expected = &[_]Token{
        tok.AUX_STREAM_START,
        Token.lex(TK.identifier, 0, 0).newDeclaration(0), // add declaration (no refs)
        Token.fnHeader(TK.kw_fn, 8, 6), // body_length=8, body_offset=6 (close@7 + 1 - header@2)
        Token.groupOpen(TK.grp_open_paren),
        a_decl,
        Token.groupSep(1),
        b_decl,
        Token.groupClose(TK.grp_close_paren),
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
        Token.groupOpen(TK.grp_open_paren),
        first_decl,
        Token.groupSep(1),
        second_decl,
        Token.groupClose(TK.grp_close_paren),
        Token.ident(TK.identifier, 1, back(4), 0), // first resolved (prev -4)
        expectedSplice, // SECOND rewritten to ident_splice
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
    defer p.deinit();
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
        Token.groupOpen(TK.grp_open_paren),
        Token.groupClose(TK.grp_close_paren),
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
        Token.groupOpen(TK.grp_open_paren),
        Token.lex(TK.lit_number, 1, 1),
        Token.groupClose(TK.grp_close_paren),
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

    // Layout: [0] stream_start [1] open [2] lit [3] sep [4] lit [5] sep [6] lit [7] close
    // sep@3: arg_idx=1 (precedes arg index 1)
    // sep@5: arg_idx=2 (precedes arg index 2)
    const expected = &[_]Token{
        tok.AUX_STREAM_START,
        Token.groupOpen(TK.grp_open_paren),
        Token.lex(TK.lit_number, 1, 1),
        Token.groupSep(1),
        Token.lex(TK.lit_number, 4, 1),
        Token.groupSep(2),
        Token.lex(TK.lit_number, 7, 1),
        Token.groupClose(TK.grp_close_paren),
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

    // Layout: [0] stream_start [1] outer_open [2] inner_open [3] lit(2) [4] inner_close
    //         [5] sep(arg_idx=1) [6] lit(6) [7] outer_close
    const expected = &[_]Token{
        tok.AUX_STREAM_START,
        Token.groupOpen(TK.grp_open_paren),
        Token.groupOpen(TK.grp_open_paren),
        Token.lex(TK.lit_number, 2, 1),
        Token.groupClose(TK.grp_close_paren),
        Token.groupSep(1),
        Token.lex(TK.lit_number, 6, 1),
        Token.groupClose(TK.grp_close_paren),
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
        Token.groupOpen(TK.grp_open_bracket),
        Token.lex(TK.lit_number, 1, 1),
        Token.groupSep(1),
        Token.lex(TK.lit_number, 4, 1),
        Token.groupClose(TK.grp_close_bracket),
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
        Token.groupOpen(TK.grp_open_brace),
        Token.lex(TK.lit_number, 1, 1),
        Token.groupClose(TK.grp_close_brace),
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
        Token.groupOpen(TK.grp_open_paren),
        Token.lex(TK.identifier, 1, 0).newDeclaration(0), // first param decl (no refs)
        Token.groupSep(1),
        second_decl,
        Token.groupClose(TK.grp_close_paren),
        bodySplice,
        // call site
        Token.lex(TK.lit_number, 0, 0), // left operand
        declFirst, // decl(first) ident_splice — binds to left operand
        Token.lex(TK.lit_number, 42, 0), // right operand parsed at splice point
    };

    try testParse(buffer, tokens, aux, expected);
}

test "Parse nested calls: arg_counter is locally scoped" {
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
    //   [0] start     [1] f_open    [2] g_open   [3] lit(1)   [4] sep(1)
    //   [5] lit(2)    [6] g_close   [7] g        [8] sep(1)   [9] h_open
    //   [10] lit(3)   [11] sep(1)   [12] lit(4)  [13] h_close [14] h
    //   [15] f_close  [16] f
    // The first sep_comma in each inner call has arg_idx=1 (not 2 or 3),
    // proving the arg_counter resets per call.
    const expected = &[_]Token{
        tok.AUX_STREAM_START,
        Token.groupOpen(TK.grp_open_paren), // f's open
        Token.groupOpen(TK.grp_open_paren), // g's open
        Token.lex(TK.lit_number, 1, 1),
        Token.groupSep(1), // g's first comma — arg_idx=1
        Token.lex(TK.lit_number, 2, 1),
        Token.groupClose(TK.grp_close_paren), // g's close
        Token.lex(TK.call_identifier, 1, 0), // g emitted post-group
        Token.groupSep(1), // f's first comma — arg_idx=1 (not 2, despite g's comma above)
        Token.groupOpen(TK.grp_open_paren), // h's open
        Token.lex(TK.lit_number, 3, 1),
        Token.groupSep(1), // h's first comma — arg_idx=1
        Token.lex(TK.lit_number, 4, 1),
        Token.groupClose(TK.grp_close_paren), // h's close
        Token.lex(TK.call_identifier, 2, 0), // h emitted post-group
        Token.groupClose(TK.grp_close_paren), // f's close
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
        Token.groupOpen(TK.grp_open_paren),
        a_decl,
        Token.groupSep(1),
        b_decl,
        Token.groupSep(2),
        c_decl,
        Token.groupClose(TK.grp_close_paren),
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
        Token.lex(TK.call_identifier, 0, 0), // add2 (lexer emits call_identifier when followed by '(')
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
    //   body postfix order: a, B, +
    //   [8] body ref(a)  [9] body splice(B) — kind rewritten from const_identifier by kwFn
    //   [10] body op_add
    //   -- callExprInline emits below; no group_open/close/sep/call_identifier for the call --
    //   [11] lit(3)  [12] synth decl(a)  [13] skip shim(kw_fn, body_length=1)  [14] lit(4) [skipped]
    //   [15] resolved ref(a)  [16] splice copy lit(4)  [17] op_add
    var add2_decl = Token.ident(TK.call_identifier, 0, 0, 0);
    add2_decl.flags.declaration = true;

    var a_decl_param = Token.ident(TK.identifier, 1, 0, 4); // body ref(a) @8 sets next=4
    a_decl_param.flags.declaration = true;
    var b_decl_param = Token.ident(TK.const_identifier, 2, 0, 3); // body splice(B) @9 sets next=3
    b_decl_param.flags.declaration = true;

    // synth_a @12: declare(@12, ident_splice sym=1). kwFn's body resolve left declarations[1]
    // pointing at body ref(a) @8 (resolve doesn't set shadow bits, so kwFn endScope doesn't
    // revert it). So this declare shadows @8: prev_offset = back(4). Re-resolve at @15 patches
    // synth_a's next_offset to 3.
    var synth_a = Token.lex(TK.ident_splice, 1, 0).newDeclaration(back(4));
    synth_a.data.ident.next_offset = 3;

    const expected = &[_]Token{
        tok.AUX_STREAM_START,
        add2_decl,
        Token.fnHeader(TK.kw_lazy_fn, 8, 6),
        Token.groupOpen(TK.grp_open_paren),
        a_decl_param,
        Token.groupSep(1),
        b_decl_param,
        Token.groupClose(TK.grp_close_paren),
        Token.ident(TK.identifier, 1, back(4), 0), // body ref(a) @8
        Token.ident(TK.ident_splice, 2, back(3), 0), // body splice(B) @9
        tok.createToken(TK.op_add), // body op_add @10
        // call expansion (no paren chain or call_identifier emitted for the call itself):
        Token.lex(TK.lit_number, 3, 0), // eager arg 0 @11
        synth_a, // synthesised decl binds sym=a to TOS reg @12
        Token.fnHeader(TK.kw_fn, 1, 0), // skip shim for lazy arg 1 @13
        Token.lex(TK.lit_number, 4, 0), // lazy arg 1, codegen-skipped @14
        Token.ident(TK.identifier, 1, back(3), 0), // body re-resolved ref(a) → synth_a @15
        Token.lex(TK.lit_number, 4, 0), // splice copy of lazy arg 1 @16
        tok.createToken(TK.op_add), // @17
    };
    try testParse(buffer, tokens, aux, expected);
}
