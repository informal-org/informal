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
        Token.lex(TK.kw_fn, 8, 2), // bodyLength=8, paramCount=2
        Token.groupOpen(TK.grp_open_paren, 2, 2, 4),
        a_decl,
        Token.groupSep(1, back(2), 2),
        b_decl,
        Token.groupClose(TK.grp_close_paren, back(4), back(2)),
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
    // In the body, SECOND appears as op_identifier (infix use)
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
    //   [8] ref(first)    [9] op_identifier(SECOND)+splice
    var first_decl = Token.ident(TK.identifier, 1, 0, 4); // next=4 → ref@8
    first_decl.flags.declaration = true;
    var second_decl = Token.ident(TK.const_identifier, 2, 0, 3); // next=3 → ref@9
    second_decl.flags.declaration = true;
    var expectedSplice = Token.ident(TK.op_identifier, 2, back(3), 0); // prev=-3
    expectedSplice.flags.splice = true;

    const expected = &[_]Token{
        tok.AUX_STREAM_START,
        Token.lex(TK.identifier, 0, 0).newDeclaration(0), // APPLY declaration (no refs)
        Token.lex(TK.kw_fn, 7, 0x8002), // bodyLength=7, arg1=(1<<15)|2
        Token.groupOpen(TK.grp_open_paren, 2, 2, 4),
        first_decl,
        Token.groupSep(1, back(2), 2),
        second_decl,
        Token.groupClose(TK.grp_close_paren, back(4), back(2)),
        Token.ident(TK.identifier, 1, back(4), 0), // first resolved (prev -4)
        expectedSplice, // SECOND resolved with splice=true
    };

    try testParse(buffer, tokens, aux, expected);
}

test "Parse eager fn inline expansion" {
    // fn add(a, b): a + b
    // 3 add 4
    // Symbol IDs: add=0, a=1, b=2
    const buffer = "fn add(a, b): a + b\n3 add 4";
    const tokens = &[_]Token{
        // fn definition
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
        tok.createToken(TK.sep_newline),
        // call: 3 add 4
        Token.lex(TK.lit_number, 3, 0),
        Token.lex(TK.op_identifier, 0, 0), // add operator
        Token.lex(TK.lit_number, 4, 0),
    };

    const aux = &[_]Token{};

    // parsedQ layout (Phase A):
    //   [0] stream_start  [1] decl(add)     [2] kw_fn           [3] group_open
    //   [4] decl(a)       [5] sep_comma     [6] decl(b)         [7] group_close
    //   [8] ref(a)        [9] ref(b)        [10] op_add
    //   [11] lit(3)       [12] declA        [13] lit(4)         [14] declB
    //   [15] re-ref(a)    [16] re-ref(b)    [17] op_add
    //
    // Phantom resolve of "add" in opIdentifierInfix happens at items.len=12,
    // patching decl(add)@1 next_offset = 12 - 1 = 11.
    var add_decl = Token.ident(TK.identifier, 0, 0, 11);
    add_decl.flags.declaration = true;

    var a_param = Token.ident(TK.identifier, 1, 0, 4); // next=ref@8 (8-4)
    a_param.flags.declaration = true;
    var b_param = Token.ident(TK.identifier, 2, 0, 3); // next=ref@9 (9-6)
    b_param.flags.declaration = true;

    // Shadow decls chain to previous chain tails:
    //   a tail was ref(a)@8; declA@12 chains there (calcOffset(8,12) = -4 = back(4)).
    //   b tail was ref(b)@9; declB@14 chains there (calcOffset(9,14) = -5 = back(5)).
    // next_offset on declA = 15-12 = 3 (patched by re-resolve).
    // next_offset on declB = 16-14 = 2 (patched by re-resolve).
    var declA = Token.ident(TK.identifier, 1, back(4), 3);
    declA.flags.declaration = true;
    declA.flags.splice = true;
    var declB = Token.ident(TK.identifier, 2, back(5), 2);
    declB.flags.declaration = true;
    declB.flags.splice = true;

    const expected = &[_]Token{
        tok.AUX_STREAM_START,
        // fn definition
        add_decl,
        Token.lex(TK.kw_fn, 8, 2), // bodyLength=8, paramCount=2
        Token.groupOpen(TK.grp_open_paren, 2, 2, 4),
        a_param,
        Token.groupSep(1, back(2), 2),
        b_param,
        Token.groupClose(TK.grp_close_paren, back(4), back(2)),
        Token.ident(TK.identifier, 1, back(4), 0), // a resolved in body (prev -4)
        Token.ident(TK.identifier, 2, back(3), 0), // b resolved in body (prev -3)
        tok.createToken(TK.op_add),
        // call site
        Token.lex(TK.lit_number, 3, 0), // left operand
        declA, // decl(a) splice — binds to left operand
        Token.lex(TK.lit_number, 4, 0), // right operand parsed
        declB, // decl(b) splice — binds to right operand
        Token.ident(TK.identifier, 1, back(3), 0), // a re-resolved (prev -3 → declA@12)
        Token.ident(TK.identifier, 2, back(2), 0), // b re-resolved (prev -2 → declB@14)
        tok.createToken(TK.op_add), // copied from body
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

    // [0] stream_start [1] group_open(arg_cnt=0, next_sep=+1, close=+1) [2] group_close
    const expected = &[_]Token{
        tok.AUX_STREAM_START,
        Token.groupOpen(TK.grp_open_paren, 0, 1, 1),
        Token.groupClose(TK.grp_close_paren, back(1), back(1)),
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

    // [0] stream_start [1] group_open(arg_cnt=1, next_sep=+2, close=+2)
    // [2] lit(1)       [3] group_close(open=-2, prev_sep=-2)
    const expected = &[_]Token{
        tok.AUX_STREAM_START,
        Token.groupOpen(TK.grp_open_paren, 1, 2, 2),
        Token.lex(TK.lit_number, 1, 1),
        Token.groupClose(TK.grp_close_paren, back(2), back(2)),
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
    // open.arg_cnt=3, next_sep=+2, close_offset=+6
    // sep@3: arg_idx=1, prev=-2, next=+2
    // sep@5: arg_idx=2, prev=-2, next=+2
    // close@7: open_offset=-6, prev_sep=-2
    const expected = &[_]Token{
        tok.AUX_STREAM_START,
        Token.groupOpen(TK.grp_open_paren, 3, 2, 6),
        Token.lex(TK.lit_number, 1, 1),
        Token.groupSep(1, back(2), 2),
        Token.lex(TK.lit_number, 4, 1),
        Token.groupSep(2, back(2), 2),
        Token.lex(TK.lit_number, 7, 1),
        Token.groupClose(TK.grp_close_paren, back(6), back(2)),
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
    //         [5] sep [6] lit(6) [7] outer_close
    // outer_open.arg_cnt=2, next_sep=+4, close=+6
    // inner_open.arg_cnt=1, next_sep=+2, close=+2
    // inner_close.open=-2, prev_sep=-2
    // sep@5: arg_idx=1, prev=-4, next=+2
    // outer_close@7: open=-6, prev=-2
    const expected = &[_]Token{
        tok.AUX_STREAM_START,
        Token.groupOpen(TK.grp_open_paren, 2, 4, 6),
        Token.groupOpen(TK.grp_open_paren, 1, 2, 2),
        Token.lex(TK.lit_number, 2, 1),
        Token.groupClose(TK.grp_close_paren, back(2), back(2)),
        Token.groupSep(1, back(4), 2),
        Token.lex(TK.lit_number, 6, 1),
        Token.groupClose(TK.grp_close_paren, back(6), back(2)),
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
        Token.groupOpen(TK.grp_open_bracket, 2, 2, 4),
        Token.lex(TK.lit_number, 1, 1),
        Token.groupSep(1, back(2), 2),
        Token.lex(TK.lit_number, 4, 1),
        Token.groupClose(TK.grp_close_bracket, back(4), back(2)),
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
        Token.groupOpen(TK.grp_open_brace, 1, 2, 2),
        Token.lex(TK.lit_number, 1, 1),
        Token.groupClose(TK.grp_close_brace, back(2), back(2)),
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
    //   [0] stream_start  [1] decl(PICK)    [2] kw_fn            [3] group_open
    //   [4] decl(first)   [5] sep_comma     [6] decl(SECOND)     [7] group_close
    //   [8] body ref(SECOND)+splice
    //   [9] lit(0)        [10] declFirst    [11] lit(42)
    //
    // Phantom resolve of "PICK" at items.len=10, patches decl(PICK)@1 next_offset = 9.
    var pick_decl = Token.ident(TK.identifier, 0, 0, 9);
    pick_decl.flags.declaration = true;

    var second_decl = Token.ident(TK.const_identifier, 2, 0, 2); // next=2 → ref@8
    second_decl.flags.declaration = true;

    // Body SECOND ref at index 8: splice=true from kwFn detection. prev=-2 to decl@6.
    var bodySplice = Token.ident(TK.const_identifier, 2, back(2), 0);
    bodySplice.flags.splice = true;

    // declFirst@10 shadow-chains to decl(first)@4 (tail of the chain since first unused in body).
    // calcOffset(4, 10) = -6 = back(6).
    var declFirst = Token.lex(TK.identifier, 1, 0).newDeclaration(back(6));
    declFirst.flags.splice = true;

    const expected = &[_]Token{
        tok.AUX_STREAM_START,
        // fn definition
        pick_decl,
        Token.lex(TK.kw_fn, 6, 0x8002), // bodyLength=6, lazy flag + 2 params
        Token.groupOpen(TK.grp_open_paren, 2, 2, 4),
        Token.lex(TK.identifier, 1, 0).newDeclaration(0), // first param decl (no refs)
        Token.groupSep(1, back(2), 2),
        second_decl,
        Token.groupClose(TK.grp_close_paren, back(4), back(2)),
        bodySplice,
        // call site
        Token.lex(TK.lit_number, 0, 0), // left operand
        declFirst, // decl(first) splice — binds to left operand
        Token.lex(TK.lit_number, 42, 0), // right operand parsed at splice point
    };

    try testParse(buffer, tokens, aux, expected);
}
