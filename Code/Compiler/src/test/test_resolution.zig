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
    // Declaration arg0 is now (fn_depth << 24) | symbolId. At depth 0, sym 0 → 0.
    try expectEqual(0, decResult.data.value.arg0);
    try expectEqual(UNDECLARED_SENTINEL, decResult.data.value.arg1); // Nothing was defined before this.

    const refResult = resolution.resolve(4, parsedQ.list.items[4]);
    const refOffset: i16 = @bitCast(refResult.data.value.arg1);
    try expectEqual(1 - 4, refOffset); // offset = declaration index - ref index.
    try expectEqual(0, refResult.data.value.arg0); // arg0 = 0 (no next use)
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
    try expectEqual(0, Resolution.getDeclIndex(resolution.declarations[0]));
    const shadowDefResult = resolution.declare(3, parsedQ.list.items[3]);
    parsedQ.list.items[3] = shadowDefResult;
    try expectEqual(UNDECLARED_SENTINEL, shadowDefResult.data.value.arg1);
    try expectEqual(3, Resolution.getDeclIndex(resolution.declarations[0]));
    // Expect not to resolve the unresolbed ref since this is a shadowing post-def without forward semantics.
    try expectEqual(2, resolution.unresolved[0]);

    // End function scope and declare the ref at the base module scope. Expect it to resolve.
    try parsedQ.push(Token.lex(TK.grp_dedent, 0, 0));
    try resolution.endScope(0);
    try parsedQ.push(Token.lex(TK.identifier, 0, 5));

    try expectEqual(UNDECLARED_SENTINEL, parsedQ.list.items[2].data.value.arg1);
    const baseDefResult = resolution.declare(5, parsedQ.list.items[5]);
    parsedQ.list.items[5] = baseDefResult;
    try expectEqual(5, Resolution.getDeclIndex(resolution.declarations[0]));
    const baseDefOffset: i16 = @bitCast(baseDefResult.data.value.arg1);
    try expectEqual(3 - 5, baseDefOffset); // Reference the shadow declaration.
    // Expect it to be resolved now.
    try expectEqual(UNDECLARED_SENTINEL, resolution.unresolved[0]);
    const afterOffset: i16 = @bitCast(parsedQ.list.items[2].data.value.arg1);
    try expectEqual(5 - 2, afterOffset); // Declared at 5 - ref at 2
    // Expect the parsed queue to have been updated as well.
}

test "Function scope lazy staleness on endScope" {
    var parsedQ = parser.TokenQueue.init(test_allocator);
    defer parsedQ.deinit();
    var resolution = try Resolution.init(test_allocator, 3, &parsedQ);
    defer resolution.deinit();

    // Index 0: dummy (parsedQ[0] is absorb target / stream_start in real compiler)
    try parsedQ.push(Token.lex(TK.aux_stream_start, 0, 0));

    // Outer declaration of symbol 1 ('a') at index 1
    try parsedQ.push(Token.lex(TK.identifier, 1, 0));
    const outerDecl = resolution.declare(1, parsedQ.list.items[1]);
    parsedQ.list.items[1] = outerDecl;
    try expectEqual(1, Resolution.getDeclIndex(resolution.declarations[1]));
    try expectEqual(0, Resolution.getFnDepth(resolution.declarations[1]));

    // Start function scope at parsedQ index 2 (kw_fn header)
    try parsedQ.push(Token.lex(TK.kw_fn, 0, 0));
    try resolution.startScope(Scope{ .start = 2, .scopeType = .function });
    try expectEqual(1, resolution.current_fn_depth);

    // Inner declaration of same symbol 1 at parsedQ index 3 (param 'a')
    try parsedQ.push(Token.lex(TK.identifier, 1, 0));
    const innerDecl = resolution.declare(3, parsedQ.list.items[3]);
    parsedQ.list.items[3] = innerDecl;
    try expectEqual(3, Resolution.getDeclIndex(resolution.declarations[1]));
    try expectEqual(1, Resolution.getFnDepth(resolution.declarations[1]));

    // End function scope at index 4 — lazy staleness, no cleanup
    try resolution.endScope(4);
    try expectEqual(0, resolution.current_fn_depth);

    // declarations[1] is NOT immediately restored — it's still stale (points to inner decl)
    try expectEqual(3, Resolution.getDeclIndex(resolution.declarations[1]));
    try expectEqual(1, Resolution.getFnDepth(resolution.declarations[1]));

    // Now resolve symbol 1 at index 4 — triggers lazy staleness detection
    try parsedQ.push(Token.lex(TK.identifier, 1, 0));
    const refResult = resolution.resolve(4, parsedQ.list.items[4]);

    // Should have walked chain from inner decl@3 → outer decl@1 (fn_depth 0 ≤ 0)
    const refOffset: i16 = @bitCast(refResult.data.value.arg1);
    try expectEqual(1 - 4, refOffset); // Resolves to outer declaration at index 1
    try expectEqual(0, refResult.data.value.arg0); // arg0 = 0 (no next use)

    // After lazy cleanup, declarations[1] now points to the outer declaration
    try expectEqual(1, Resolution.getDeclIndex(resolution.declarations[1]));
    try expectEqual(0, Resolution.getFnDepth(resolution.declarations[1]));
}

test "Sequential functions shadowing same name" {
    var parsedQ = parser.TokenQueue.init(test_allocator);
    defer parsedQ.deinit();
    var resolution = try Resolution.init(test_allocator, 3, &parsedQ);
    defer resolution.deinit();

    // Index 0: dummy absorb target
    try parsedQ.push(Token.lex(TK.aux_stream_start, 0, 0));

    // x = 10 at index 1
    try parsedQ.push(Token.lex(TK.identifier, 1, 0));
    const outerDecl = resolution.declare(1, parsedQ.list.items[1]);
    parsedQ.list.items[1] = outerDecl;

    // ref(x) at index 2 — normal resolve
    try parsedQ.push(Token.lex(TK.identifier, 1, 0));
    const ref1 = resolution.resolve(2, parsedQ.list.items[2]);
    parsedQ.list.items[2] = ref1;
    const ref1Offset: i16 = @bitCast(ref1.data.value.arg1);
    try expectEqual(1 - 2, ref1Offset);

    // fn foo(x): ... — function scope with x shadow
    try parsedQ.push(Token.lex(TK.kw_fn, 0, 0)); // index 3
    try resolution.startScope(Scope{ .start = 3, .scopeType = .function });

    try parsedQ.push(Token.lex(TK.identifier, 1, 0)); // index 4: param x
    const fooParam = resolution.declare(4, parsedQ.list.items[4]);
    parsedQ.list.items[4] = fooParam;

    // ref(x) at index 5 inside foo
    try parsedQ.push(Token.lex(TK.identifier, 1, 0));
    const ref2 = resolution.resolve(5, parsedQ.list.items[5]);
    parsedQ.list.items[5] = ref2;
    const ref2Offset: i16 = @bitCast(ref2.data.value.arg1);
    try expectEqual(4 - 5, ref2Offset); // Resolves to foo's param

    try resolution.endScope(6); // fn_depth: 1 → 0

    // fn bar(x): ... — second function scope with x shadow
    try parsedQ.push(Token.lex(TK.kw_fn, 0, 0)); // index 6
    try resolution.startScope(Scope{ .start = 6, .scopeType = .function });

    try parsedQ.push(Token.lex(TK.identifier, 1, 0)); // index 7: param x
    const barParam = resolution.declare(7, parsedQ.list.items[7]);
    parsedQ.list.items[7] = barParam;

    try resolution.endScope(8); // fn_depth: 1 → 0

    // ref(x) at index 8 — should walk chain: bar's x@7 (depth 1) → foo's x@4 (depth 1) → outer x@1 (depth 0)
    try parsedQ.push(Token.lex(TK.identifier, 1, 0));
    const ref3 = resolution.resolve(8, parsedQ.list.items[8]);
    const ref3Offset: i16 = @bitCast(ref3.data.value.arg1);
    try expectEqual(1 - 8, ref3Offset); // Resolves to outer x@1

    // Subsequent resolve should be clean (no stale walk)
    try parsedQ.push(Token.lex(TK.identifier, 1, 0)); // index 9
    const ref4 = resolution.resolve(9, parsedQ.list.items[9]);
    const ref4Offset: i16 = @bitCast(ref4.data.value.arg1);
    try expectEqual(1 - 9, ref4Offset); // Also resolves to outer x@1
    try expectEqual(0, Resolution.getFnDepth(resolution.declarations[1])); // Clean entry
}

test "Forward use-chain links references" {
    var parsedQ = parser.TokenQueue.init(test_allocator);
    defer parsedQ.deinit();
    var resolution = try Resolution.init(test_allocator, 3, &parsedQ);
    defer resolution.deinit();

    // dummy at index 0 (absorb target)
    try parsedQ.push(Token.lex(TK.aux_stream_start, 0, 0));

    // decl(x) at index 1
    try parsedQ.push(Token.lex(TK.identifier, 1, 0));
    const decl = resolution.declare(1, parsedQ.list.items[1]);
    parsedQ.list.items[1] = decl;

    // ref(x) at index 2
    try parsedQ.push(Token.lex(TK.identifier, 1, 0));
    const ref1 = resolution.resolve(2, parsedQ.list.items[2]);
    parsedQ.list.items[2] = ref1;
    try expectEqual(0, ref1.data.value.arg0); // No next use yet

    // ref(x) at index 3
    try parsedQ.push(Token.lex(TK.identifier, 1, 0));
    const ref2 = resolution.resolve(3, parsedQ.list.items[3]);
    parsedQ.list.items[3] = ref2;
    try expectEqual(0, ref2.data.value.arg0); // No next use yet

    // Forward chain: ref@2 should now point to ref@3
    try expectEqual(3, parsedQ.list.items[2].data.value.arg0);

    // ref(x) at index 4
    try parsedQ.push(Token.lex(TK.identifier, 1, 0));
    const ref3 = resolution.resolve(4, parsedQ.list.items[4]);
    parsedQ.list.items[4] = ref3;

    // Forward chain: ref@3 should now point to ref@4
    try expectEqual(3, parsedQ.list.items[2].data.value.arg0); // Still points to 3
    try expectEqual(4, parsedQ.list.items[3].data.value.arg0); // Now points to 4
    try expectEqual(0, parsedQ.list.items[4].data.value.arg0); // Last use, no next
}

test "No shadowing — fn_depth goes up and down cleanly" {
    var parsedQ = parser.TokenQueue.init(test_allocator);
    defer parsedQ.deinit();
    var resolution = try Resolution.init(test_allocator, 3, &parsedQ);
    defer resolution.deinit();

    // Index 0: dummy absorb target
    try parsedQ.push(Token.lex(TK.aux_stream_start, 0, 0));

    // decl(x) at index 1
    try parsedQ.push(Token.lex(TK.identifier, 1, 0));
    const decl = resolution.declare(1, parsedQ.list.items[1]);
    parsedQ.list.items[1] = decl;

    // Function scope — no declarations of x inside
    try parsedQ.push(Token.lex(TK.kw_fn, 0, 0)); // index 2
    try resolution.startScope(Scope{ .start = 2, .scopeType = .function });

    // Different symbol (2) declared inside
    try parsedQ.push(Token.lex(TK.identifier, 2, 0)); // index 3
    const innerDecl = resolution.declare(3, parsedQ.list.items[3]);
    parsedQ.list.items[3] = innerDecl;

    try resolution.endScope(4);

    // ref(x) at index 4 — x was never shadowed, declarations[1] still valid at depth 0
    try parsedQ.push(Token.lex(TK.identifier, 1, 0));
    const ref1 = resolution.resolve(4, parsedQ.list.items[4]);
    const ref1Offset: i16 = @bitCast(ref1.data.value.arg1);
    try expectEqual(1 - 4, ref1Offset); // Resolves to outer x@1 with no stale walk
}

test "Stale entry with no valid outer declaration" {
    var parsedQ = parser.TokenQueue.init(test_allocator);
    defer parsedQ.deinit();
    var resolution = try Resolution.init(test_allocator, 3, &parsedQ);
    defer resolution.deinit();

    // Function scope with declaration of symbol 1 — no outer declaration exists
    try parsedQ.push(Token.lex(TK.kw_fn, 0, 0)); // index 0
    try resolution.startScope(Scope{ .start = 0, .scopeType = .function });

    try parsedQ.push(Token.lex(TK.identifier, 1, 0)); // index 1
    const innerDecl = resolution.declare(1, parsedQ.list.items[1]);
    parsedQ.list.items[1] = innerDecl;

    try resolution.endScope(2);

    // ref(symbol 1) at index 2 — stale, chain walk hits end with no valid decl
    try parsedQ.push(Token.lex(TK.identifier, 1, 0));
    const ref1 = resolution.resolve(2, parsedQ.list.items[2]);
    try expectEqual(UNDECLARED_SENTINEL, ref1.data.value.arg1); // Unresolved
    try expectEqual(0, Resolution.getDeclIndex(resolution.declarations[1])); // Marked undeclared
}
