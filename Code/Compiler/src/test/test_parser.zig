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

    // Reference arg0 = 0 (forward chain, no next use).
    const expected = &[_]Token{
        tok.AUX_STREAM_START,
        Token.lex(TK.identifier, 0, 0).newDeclaration(0), // add declaration (depth 0)
        Token.lex(TK.kw_fn, 5, 2), // fn header: bodyLength=5, paramCount=2
        Token.lex(TK.identifier, 1, 0).newDeclaration(0), // a param decl
        Token.lex(TK.identifier, 2, 0).newDeclaration(0), // b param decl
        Token.lex(TK.identifier, 0, 0xFFFE), // a resolved (arg0=0, offset -2)
        Token.lex(TK.identifier, 0, 0xFFFE), // b resolved (arg0=0, offset -2)
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
    var expectedSplice = Token.lex(TK.op_identifier, 0, 0xFFFE); // arg0=0 (forward chain), offset -2
    expectedSplice.aux.splice = true;

    const expected = &[_]Token{
        tok.AUX_STREAM_START,
        Token.lex(TK.identifier, 0, 0).newDeclaration(0), // APPLY declaration (depth 0)
        Token.lex(TK.kw_fn, 4, 0x8002), // bodyLength=4, arg1=(1<<15)|2
        Token.lex(TK.identifier, 1, 0).newDeclaration(0), // first param decl
        Token.lex(TK.const_identifier, 2, 0).newDeclaration(0), // SECOND param decl
        Token.lex(TK.identifier, 0, 0xFFFE), // first resolved (arg0=0, offset -2)
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
    var declA = Token.lex(TK.identifier, 1, 0).newDeclaration(0xFFFA); // chains to a@3 (offset -6)
    declA.aux.splice = true;
    var declB = Token.lex(TK.identifier, 2, 0).newDeclaration(0xFFF9); // chains to b@4 (offset -7)
    declB.aux.splice = true;

    const expected = &[_]Token{
        tok.AUX_STREAM_START,
        // fn definition
        Token.lex(TK.identifier, 0, 0).newDeclaration(0), // add declaration (depth 0)
        Token.lex(TK.kw_fn, 5, 2), // fn header: bodyLength=5, paramCount=2
        Token.lex(TK.identifier, 1, 0).newDeclaration(0), // a param decl
        Token.lex(TK.identifier, 2, 0).newDeclaration(0), // b param decl
        Token.lex(TK.identifier, 0, 0xFFFE), // a resolved (arg0=0, offset -2)
        Token.lex(TK.identifier, 0, 0xFFFE), // b resolved (arg0=0, offset -2)
        tok.createToken(TK.op_add),
        // call site
        Token.lex(TK.lit_number, 3, 0), // left operand
        declA, // decl(a) splice — binds to left operand
        Token.lex(TK.lit_number, 4, 0), // right operand parsed
        declB, // decl(b) splice — binds to right operand
        Token.lex(TK.identifier, 0, 0xFFFD), // a re-resolved (arg0=0, offset -3 → index 9)
        Token.lex(TK.identifier, 0, 0xFFFE), // b re-resolved (arg0=0, offset -2 → index 11)
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

    // Expanded: decl(first) splice, then splice parses lit(42)
    var declFirst = Token.lex(TK.identifier, 1, 0).newDeclaration(0xFFFC); // chains to first@3 (offset -4)
    declFirst.aux.splice = true;

    // Body token at index 5 gets splice=true from kwFn detection
    // arg0=0 (forward chain), arg1=0xFFFF (offset -1 to SECOND param decl@4)
    var bodySplice = Token.lex(TK.const_identifier, 0, 0xFFFF);
    bodySplice.aux.splice = true;

    const expected = &[_]Token{
        tok.AUX_STREAM_START,
        // fn definition
        Token.lex(TK.identifier, 0, 0).newDeclaration(0), // PICK declaration (depth 0)
        Token.lex(TK.kw_fn, 3, 0x8002), // bodyLength=3, lazy flag + 2 params
        Token.lex(TK.identifier, 1, 0).newDeclaration(0), // first param decl
        Token.lex(TK.const_identifier, 2, 0).newDeclaration(0), // SECOND param decl
        bodySplice, // body: SECOND resolved (arg0=0) with splice=true
        // call site
        Token.lex(TK.lit_number, 0, 0), // left operand
        declFirst, // decl(first) splice — binds to left operand
        Token.lex(TK.lit_number, 42, 0), // right operand parsed at splice point
    };

    try testParse(buffer, tokens, aux, expected);
}
