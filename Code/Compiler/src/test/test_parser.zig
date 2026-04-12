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

    // Declarations get next_offset patched when their references resolve.
    var a_decl = Token.ident(TK.identifier, 1, 0, 2); // next_offset=2 → ref at index 5
    a_decl.flags.declaration = true;
    var b_decl = Token.ident(TK.identifier, 2, 0, 2); // next_offset=2 → ref at index 6
    b_decl.flags.declaration = true;

    const expected = &[_]Token{
        tok.AUX_STREAM_START,
        Token.lex(TK.identifier, 0, 0).newDeclaration(0), // add declaration (no refs)
        Token.lex(TK.kw_fn, 5, 2), // fn header: bodyLength=5, paramCount=2
        a_decl,
        b_decl,
        Token.ident(TK.identifier, 1, 0xFFFE, 0), // a resolved (prev_offset -2, no next)
        Token.ident(TK.identifier, 2, 0xFFFE, 0), // b resolved (prev_offset -2, no next)
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

    // Expected: fn_header arg1 = (1 << 15) | 2 = 0x8002 (lazy flag set, 2 params)
    // bodyLength = paramCount + bodyTokens = 2 + 2 = 4
    // The SECOND ref in body should have splice=true
    var first_decl = Token.ident(TK.identifier, 1, 0, 2); // next_offset=2 → ref at index 5
    first_decl.flags.declaration = true;
    var second_decl = Token.ident(TK.const_identifier, 2, 0, 2); // next_offset=2 → ref at index 6
    second_decl.flags.declaration = true;
    var expectedSplice = Token.ident(TK.op_identifier, 2, 0xFFFE, 0);
    expectedSplice.flags.splice = true;

    const expected = &[_]Token{
        tok.AUX_STREAM_START,
        Token.lex(TK.identifier, 0, 0).newDeclaration(0), // APPLY declaration (no refs)
        Token.lex(TK.kw_fn, 4, 0x8002), // bodyLength=4, arg1=(1<<15)|2
        first_decl,
        second_decl,
        Token.ident(TK.identifier, 1, 0xFFFE, 0), // first resolved (prev_offset -2, no next)
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

    // After expansion: decl(a) splice, lit(4), decl(b) splice, id(a) re-resolved, id(b) re-resolved, op_add
    // Inline expansion declarations chain to previous decl (shadows restored by endScope).

    // add decl@1: next_offset patched by phantom resolve in opIdentifierInfix (resolve at index 9).
    var add_decl = Token.ident(TK.identifier, 0, 0, 8);
    add_decl.flags.declaration = true;

    // fn body decls: a@3 next→5 (+2), b@4 next→6 (+2)
    var a_param = Token.ident(TK.identifier, 1, 0, 2);
    a_param.flags.declaration = true;
    var b_param = Token.ident(TK.identifier, 2, 0, 2);
    b_param.flags.declaration = true;

    // Inline expansion shadow decls: a@9 next→12 (+3), b@11 next→13 (+2).
    // prev_offset chains to the previous tail of the symbol chain, not the original decl:
    //   a's chain tail after the body is the body ref a@5; declA@9 chains there (offset -4).
    //   b's chain tail is the body ref b@6; declB@11 chains there (offset -5).
    var declA = Token.ident(TK.identifier, 1, 0xFFFC, 3); // prev chains to a@5 (offset -4)
    declA.flags.declaration = true;
    declA.flags.splice = true;
    var declB = Token.ident(TK.identifier, 2, 0xFFFB, 2); // prev chains to b@6 (offset -5)
    declB.flags.declaration = true;
    declB.flags.splice = true;

    const expected = &[_]Token{
        tok.AUX_STREAM_START,
        // fn definition
        add_decl,
        Token.lex(TK.kw_fn, 5, 2), // fn header: bodyLength=5, paramCount=2
        a_param,
        b_param,
        Token.ident(TK.identifier, 1, 0xFFFE, 0), // a resolved (prev -2, no next)
        Token.ident(TK.identifier, 2, 0xFFFE, 0), // b resolved (prev -2, no next)
        tok.createToken(TK.op_add),
        // call site
        Token.lex(TK.lit_number, 3, 0), // left operand
        declA, // decl(a) splice — binds to left operand
        Token.lex(TK.lit_number, 4, 0), // right operand parsed
        declB, // decl(b) splice — binds to right operand
        Token.ident(TK.identifier, 1, 0xFFFD, 0), // a re-resolved (prev -3 → index 9)
        Token.ident(TK.identifier, 2, 0xFFFE, 0), // b re-resolved (prev -2 → index 11)
        tok.createToken(TK.op_add), // copied from body
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

    // PICK decl@1: next_offset patched by phantom resolve in opIdentifierInfix.
    var pick_decl = Token.ident(TK.identifier, 0, 0, 6);
    pick_decl.flags.declaration = true;

    // SECOND param decl@4: next_offset=1 → ref@5.
    var second_decl = Token.ident(TK.const_identifier, 2, 0, 1);
    second_decl.flags.declaration = true;

    // Body SECOND ref at index 5: splice=true from kwFn detection.
    var bodySplice = Token.ident(TK.const_identifier, 2, 0xFFFF, 0);
    bodySplice.flags.splice = true;

    // Expanded: decl(first) splice, then splice parses lit(42).
    var declFirst = Token.lex(TK.identifier, 1, 0).newDeclaration(0xFFFC); // chains to first@3 (offset -4)
    declFirst.flags.splice = true;

    const expected = &[_]Token{
        tok.AUX_STREAM_START,
        // fn definition
        pick_decl,
        Token.lex(TK.kw_fn, 3, 0x8002), // bodyLength=3, lazy flag + 2 params
        Token.lex(TK.identifier, 1, 0).newDeclaration(0), // first param decl (no refs)
        second_decl,
        bodySplice,
        // call site
        Token.lex(TK.lit_number, 0, 0), // left operand
        declFirst, // decl(first) splice — binds to left operand
        Token.lex(TK.lit_number, 42, 0), // right operand parsed at splice point
    };

    try testParse(buffer, tokens, aux, expected);
}
