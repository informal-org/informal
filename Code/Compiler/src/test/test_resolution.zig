const std = @import("std");
const parser = @import("../parser.zig");
const tok = @import("../token.zig");
const Token = tok.Token;
const TK = tok.Kind;
const rs = @import("../resolution.zig");
const Resolution = rs.Resolution;
const Scope = rs.Scope;
const UNDECLARED_SENTINEL = rs.UNDECLARED_SENTINEL;

const test_allocator = std.testing.allocator;
const expectEqual = std.testing.expectEqual;

test "Normal declaration and reference" {
    var parsedQ = parser.TokenQueue.init(test_allocator);
    defer parsedQ.deinit();
    var resolution = try Resolution.init(test_allocator, 3, &parsedQ);
    defer resolution.deinit();

    // hello = 42
    try parsedQ.push(Token.lex(TK.lit_number, 0, 1));
    try parsedQ.push(Token.lex(TK.identifier, 0, 5)); // Symbol ID 0 with len of 5
    try parsedQ.push(Token.lex(TK.lit_number, 42, 2));
    try parsedQ.push(Token.lex(TK.op_assign_eq, 0, 1));
    // Reference hello
    try parsedQ.push(Token.lex(TK.identifier, 0, 5));

    const decResult = resolution.declare(1, parsedQ.list.items[1]);
    try expectEqual(0, decResult.data.value.arg0);
    try expectEqual(UNDECLARED_SENTINEL, decResult.data.value.arg1); // Nothing was defined before this.

    const refResult = resolution.resolve(4, parsedQ.list.items[4]);
    const refOffset: i16 = @bitCast(refResult.data.value.arg1);
    try expectEqual(1 - 4, refOffset); // offset = declaration index - ref index.
    try expectEqual(0, refResult.data.value.arg0);
}

test "Forward reference from child scope" {
    var parsedQ = parser.TokenQueue.init(test_allocator);
    defer parsedQ.deinit();
    var resolution = try Resolution.init(test_allocator, 3, &parsedQ);
    defer resolution.deinit();

    // hello = 42
    try resolution.startScope(Scope{ .start = 1, .scopeType = .module });
    try parsedQ.push(Token.lex(TK.lit_number, 0, 1));
    try parsedQ.push(Token.lex(TK.grp_indent, 0, 0)); // Start of some new scope
    try resolution.startScope(Scope{ .start = 1, .scopeType = .function });

    try parsedQ.push(Token.lex(TK.identifier, 0, 5)); // Reference to some unknown identifier.
    const refResult = resolution.resolve(2, parsedQ.list.items[2]);
    parsedQ.list.items[2] = refResult;
    // Expect it to be unresolved.
    try expectEqual(UNDECLARED_SENTINEL, refResult.data.value.arg1);
    try expectEqual(2, resolution.unresolved[0]);

    // Say some reference is defined after it (shadowing).
    // The name shouldn't resolve since func scope doesn't support forward ref.
    try parsedQ.push(Token.lex(TK.identifier, 0, 5));
    try parsedQ.push(Token.lex(TK.lit_number, 99, 2));
    try parsedQ.push(Token.lex(TK.op_assign_eq, 0, 1));

    // Expect it to not be have a definition before.
    try expectEqual(UNDECLARED_SENTINEL, resolution.declarations[0]);
    const shadowDefResult = resolution.declare(3, parsedQ.list.items[3]);
    parsedQ.list.items[3] = shadowDefResult;
    try expectEqual(UNDECLARED_SENTINEL, shadowDefResult.data.value.arg1);
    try expectEqual(3, resolution.declarations[0]);
    // Expect not to resolve the unresolbed ref since this is a shadowing post-def without forward semantics.
    try expectEqual(2, resolution.unresolved[0]);

    // End function scope and declare the ref at the base module scope. Expect it to resolve.
    try parsedQ.push(Token.lex(TK.grp_dedent, 0, 0));
    try resolution.endScope(0);
    try parsedQ.push(Token.lex(TK.identifier, 0, 5));

    try expectEqual(UNDECLARED_SENTINEL, parsedQ.list.items[2].data.value.arg1);
    const baseDefResult = resolution.declare(5, parsedQ.list.items[5]);
    parsedQ.list.items[5] = baseDefResult;
    try expectEqual(5, resolution.declarations[0]);
    const baseDefOffset: i16 = @bitCast(baseDefResult.data.value.arg1);
    try expectEqual(3 - 5, baseDefOffset); // Reference the shadow declaration.
    // Expect it to be resolved now.
    try expectEqual(UNDECLARED_SENTINEL, resolution.unresolved[0]);
    const afterOffset: i16 = @bitCast(parsedQ.list.items[2].data.value.arg1);
    try expectEqual(5 - 2, afterOffset); // Declared at 5 - ref at 2
    // Expect the parsed queue to have been updated as well.
}

test "Function scope restoration on endScope" {
    var parsedQ = parser.TokenQueue.init(test_allocator);
    defer parsedQ.deinit();
    var resolution = try Resolution.init(test_allocator, 3, &parsedQ);
    defer resolution.deinit();

    // Outer declaration of symbol 1 ('a') at index 0
    try parsedQ.push(Token.lex(TK.identifier, 1, 0));
    const outerDecl = resolution.declare(0, parsedQ.list.items[0]);
    parsedQ.list.items[0] = outerDecl;
    try expectEqual(0, resolution.declarations[1]);

    // Start function scope at parsedQ index 1 (kw_fn header)
    try parsedQ.push(Token.lex(TK.kw_fn, 0, 0));
    try resolution.startScope(Scope{ .start = 1, .scopeType = .function });

    // Inner declaration of same symbol 1 at parsedQ index 2 (param 'a')
    try parsedQ.push(Token.lex(TK.identifier, 1, 0));
    const innerDecl = resolution.declare(2, parsedQ.list.items[2]);
    parsedQ.list.items[2] = innerDecl;
    try expectEqual(2, resolution.declarations[1]);

    // End function scope at index 3
    try resolution.endScope(3);

    // After endScope, declarations[1] should be restored to 0 (the outer declaration)
    try expectEqual(0, resolution.declarations[1]);
}
