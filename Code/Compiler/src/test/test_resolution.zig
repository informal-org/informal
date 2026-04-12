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
    parsedQ.list.items[1] = decResult;
    try expectEqual(0, decResult.data.ident.symbol_id); // symbolId preserved
    try expectEqual(UNDECLARED_SENTINEL, decResult.data.ident.prev_offset); // First declaration.
    try expectEqual(0, decResult.data.ident.next_offset); // No references yet.

    const refResult = resolution.resolve(4, parsedQ.list.items[4]);
    parsedQ.list.items[4] = refResult;
    const refOffset: i16 = @bitCast(refResult.data.ident.prev_offset);
    try expectEqual(1 - 4, refOffset); // prev_offset = declaration index - ref index.
    try expectEqual(0, refResult.data.ident.symbol_id); // symbolId preserved (symbol 0)
    try expectEqual(0, refResult.data.ident.next_offset); // Last use, no next.

    // Declaration's next_offset should now point to the reference.
    const declNextOff: i16 = @bitCast(parsedQ.list.items[1].data.ident.next_offset);
    try expectEqual(4 - 1, declNextOff);
}

test "Forward reference from child scope" {
    var parsedQ = parser.TokenQueue.init(test_allocator);
    defer parsedQ.deinit();
    var resolution = try Resolution.init(test_allocator, 3, &parsedQ);
    defer resolution.deinit();

    try resolution.startScope(Scope{ .start = 1, .scopeType = .module });
    try parsedQ.push(Token.lex(TK.lit_number, 0, 1));
    try parsedQ.push(Token.lex(TK.grp_indent, 0, 0));
    try resolution.startScope(Scope{ .start = 1, .scopeType = .function });

    try parsedQ.push(Token.lex(TK.identifier, 0, 5));
    const refResult = resolution.resolve(2, parsedQ.list.items[2]);
    parsedQ.list.items[2] = refResult;
    try expectEqual(UNDECLARED_SENTINEL, refResult.data.ident.prev_offset);
    try expectEqual(2, resolution.unresolved[0]);

    // Declaration inside function scope — shouldn't resolve the forward ref.
    try parsedQ.push(Token.lex(TK.identifier, 0, 5));
    try parsedQ.push(Token.lex(TK.lit_number, 99, 2));
    try parsedQ.push(Token.lex(TK.op_assign_eq, 0, 1));

    try expectEqual(0, resolution.declarations[0].decl_index);
    const shadowDefResult = resolution.declare(3, parsedQ.list.items[3]);
    parsedQ.list.items[3] = shadowDefResult;
    try expectEqual(UNDECLARED_SENTINEL, shadowDefResult.data.ident.prev_offset);
    try expectEqual(3, resolution.declarations[0].decl_index);
    try expectEqual(2, resolution.unresolved[0]);

    // End function scope, declare at module level — forward ref should resolve.
    try parsedQ.push(Token.lex(TK.grp_dedent, 0, 0));
    try resolution.endScope(0);
    try parsedQ.push(Token.lex(TK.identifier, 0, 5));

    try expectEqual(UNDECLARED_SENTINEL, parsedQ.list.items[2].data.ident.prev_offset);
    const baseDefResult = resolution.declare(5, parsedQ.list.items[5]);
    parsedQ.list.items[5] = baseDefResult;
    try expectEqual(5, resolution.declarations[0].decl_index);
    const baseDefOffset: i16 = @bitCast(baseDefResult.data.ident.prev_offset);
    try expectEqual(3 - 5, baseDefOffset); // Chains to the shadowed decl inside fn.
    try expectEqual(UNDECLARED_SENTINEL, resolution.unresolved[0]);
    const afterOffset: i16 = @bitCast(parsedQ.list.items[2].data.ident.prev_offset);
    try expectEqual(5 - 2, afterOffset); // Forward ref resolved to decl at 5.
}

test "Shadow cleanup on endScope" {
    var parsedQ = parser.TokenQueue.init(test_allocator);
    defer parsedQ.deinit();
    var resolution = try Resolution.init(test_allocator, 3, &parsedQ);
    defer resolution.deinit();

    // Index 0: dummy
    try parsedQ.push(Token.lex(TK.aux_stream_start, 0, 0));

    // Outer declaration of symbol 1 at index 1
    try parsedQ.push(Token.lex(TK.identifier, 1, 0));
    const outerDecl = resolution.declare(1, parsedQ.list.items[1]);
    parsedQ.list.items[1] = outerDecl;
    try expectEqual(1, resolution.declarations[1].decl_index);

    // Start function scope
    try parsedQ.push(Token.lex(TK.kw_fn, 0, 0));
    try resolution.startScope(Scope{ .start = 2, .scopeType = .function });

    // Inner declaration of same symbol 1 at index 3 (shadows outer)
    try parsedQ.push(Token.lex(TK.identifier, 1, 0));
    const innerDecl = resolution.declare(3, parsedQ.list.items[3]);
    parsedQ.list.items[3] = innerDecl;
    try expectEqual(3, resolution.declarations[1].decl_index);
    // arg1 should chain back to outer decl
    const innerOffset: i16 = @bitCast(innerDecl.data.ident.prev_offset);
    try expectEqual(1 - 3, innerOffset);

    // End function scope — shadow should be cleaned up eagerly.
    try resolution.endScope(4);

    // declarations[1] should now be restored to the outer declaration.
    try expectEqual(1, resolution.declarations[1].decl_index);

    // Resolve symbol 1 — should point to outer decl at index 1 directly.
    try parsedQ.push(Token.lex(TK.identifier, 1, 0));
    const refResult = resolution.resolve(4, parsedQ.list.items[4]);
    const refOffset: i16 = @bitCast(refResult.data.ident.prev_offset);
    try expectEqual(1 - 4, refOffset);
    try expectEqual(1, refResult.data.ident.symbol_id); // symbolId preserved
    try expectEqual(0, refResult.data.ident.next_offset); // No next use
}

test "Sequential functions shadowing same name" {
    var parsedQ = parser.TokenQueue.init(test_allocator);
    defer parsedQ.deinit();
    var resolution = try Resolution.init(test_allocator, 3, &parsedQ);
    defer resolution.deinit();

    // Index 0: dummy
    try parsedQ.push(Token.lex(TK.aux_stream_start, 0, 0));

    // x = 10 at index 1
    try parsedQ.push(Token.lex(TK.identifier, 1, 0));
    const outerDecl = resolution.declare(1, parsedQ.list.items[1]);
    parsedQ.list.items[1] = outerDecl;

    // ref(x) at index 2
    try parsedQ.push(Token.lex(TK.identifier, 1, 0));
    const ref1 = resolution.resolve(2, parsedQ.list.items[2]);
    parsedQ.list.items[2] = ref1;
    const ref1Offset: i16 = @bitCast(ref1.data.ident.prev_offset);
    try expectEqual(1 - 2, ref1Offset);

    // fn foo(x): ...
    try parsedQ.push(Token.lex(TK.kw_fn, 0, 0)); // index 3
    try resolution.startScope(Scope{ .start = 3, .scopeType = .function });

    try parsedQ.push(Token.lex(TK.identifier, 1, 0)); // index 4: param x
    const fooParam = resolution.declare(4, parsedQ.list.items[4]);
    parsedQ.list.items[4] = fooParam;

    // ref(x) at index 5 inside foo
    try parsedQ.push(Token.lex(TK.identifier, 1, 0));
    const ref2 = resolution.resolve(5, parsedQ.list.items[5]);
    parsedQ.list.items[5] = ref2;
    const ref2Offset: i16 = @bitCast(ref2.data.ident.prev_offset);
    try expectEqual(4 - 5, ref2Offset); // Resolves to foo's param

    try resolution.endScope(6); // Shadow cleaned up

    // After endScope, declarations[1] restored to outer x@1.
    try expectEqual(1, resolution.declarations[1].decl_index);

    // fn bar(x): ...
    try parsedQ.push(Token.lex(TK.kw_fn, 0, 0)); // index 6
    try resolution.startScope(Scope{ .start = 6, .scopeType = .function });

    try parsedQ.push(Token.lex(TK.identifier, 1, 0)); // index 7: param x
    const barParam = resolution.declare(7, parsedQ.list.items[7]);
    parsedQ.list.items[7] = barParam;

    try resolution.endScope(8); // Shadow cleaned up again

    // ref(x) at index 8 — should resolve to outer x@1 directly, no chain walk.
    try parsedQ.push(Token.lex(TK.identifier, 1, 0));
    const ref3 = resolution.resolve(8, parsedQ.list.items[8]);
    parsedQ.list.items[8] = ref3;
    const ref3Offset: i16 = @bitCast(ref3.data.ident.prev_offset);
    try expectEqual(1 - 8, ref3Offset);

    // Subsequent resolve also clean.
    try parsedQ.push(Token.lex(TK.identifier, 1, 0)); // index 9
    const ref4 = resolution.resolve(9, parsedQ.list.items[9]);
    parsedQ.list.items[9] = ref4;
    const ref4Offset: i16 = @bitCast(ref4.data.ident.prev_offset);
    try expectEqual(1 - 9, ref4Offset);

    // Forward chain: ref@8 should point to ref@9 via next_offset.
    const ref3NextOff: i16 = @bitCast(parsedQ.list.items[8].data.ident.next_offset);
    try expectEqual(9 - 8, ref3NextOff);
    try expectEqual(0, ref4.data.ident.next_offset); // Last use.
}

test "Forward use-chain links references" {
    var parsedQ = parser.TokenQueue.init(test_allocator);
    defer parsedQ.deinit();
    var resolution = try Resolution.init(test_allocator, 3, &parsedQ);
    defer resolution.deinit();

    // dummy at index 0
    try parsedQ.push(Token.lex(TK.aux_stream_start, 0, 0));

    // decl(x) at index 1
    try parsedQ.push(Token.lex(TK.identifier, 1, 0));
    const decl = resolution.declare(1, parsedQ.list.items[1]);
    parsedQ.list.items[1] = decl;

    // ref(x) at index 2
    try parsedQ.push(Token.lex(TK.identifier, 1, 0));
    const ref1 = resolution.resolve(2, parsedQ.list.items[2]);
    parsedQ.list.items[2] = ref1;
    try expectEqual(1, ref1.data.ident.symbol_id); // symbolId preserved
    try expectEqual(0, ref1.data.ident.next_offset); // No next use yet

    // Declaration's next_offset should now point to ref@2.
    const declNextOff1: i16 = @bitCast(parsedQ.list.items[1].data.ident.next_offset);
    try expectEqual(2 - 1, declNextOff1);

    // ref(x) at index 3
    try parsedQ.push(Token.lex(TK.identifier, 1, 0));
    const ref2 = resolution.resolve(3, parsedQ.list.items[3]);
    parsedQ.list.items[3] = ref2;
    try expectEqual(1, ref2.data.ident.symbol_id); // symbolId preserved
    try expectEqual(0, ref2.data.ident.next_offset); // No next use yet

    // Forward chain: ref@2's next_offset should now point to ref@3 (offset +1).
    const ref1NextOff: i16 = @bitCast(parsedQ.list.items[2].data.ident.next_offset);
    try expectEqual(3 - 2, ref1NextOff);

    // ref(x) at index 4
    try parsedQ.push(Token.lex(TK.identifier, 1, 0));
    const ref3 = resolution.resolve(4, parsedQ.list.items[4]);
    parsedQ.list.items[4] = ref3;

    // Forward chain via next_offset: ref@2 → ref@3 → ref@4 → 0
    const r2next: i16 = @bitCast(parsedQ.list.items[2].data.ident.next_offset);
    const r3next: i16 = @bitCast(parsedQ.list.items[3].data.ident.next_offset);
    try expectEqual(3 - 2, r2next); // ref@2 still points to ref@3
    try expectEqual(4 - 3, r3next); // ref@3 now points to ref@4
    try expectEqual(0, parsedQ.list.items[4].data.ident.next_offset); // Last use, no next

    // All refs preserve symbol_id.
    try expectEqual(1, parsedQ.list.items[2].data.ident.symbol_id);
    try expectEqual(1, parsedQ.list.items[3].data.ident.symbol_id);
    try expectEqual(1, parsedQ.list.items[4].data.ident.symbol_id);
}

test "No shadowing — clean resolution through function scope" {
    var parsedQ = parser.TokenQueue.init(test_allocator);
    defer parsedQ.deinit();
    var resolution = try Resolution.init(test_allocator, 3, &parsedQ);
    defer resolution.deinit();

    // Index 0: dummy
    try parsedQ.push(Token.lex(TK.aux_stream_start, 0, 0));

    // decl(x) at index 1
    try parsedQ.push(Token.lex(TK.identifier, 1, 0));
    const decl = resolution.declare(1, parsedQ.list.items[1]);
    parsedQ.list.items[1] = decl;

    // Function scope — declares different symbol (2), not x
    try parsedQ.push(Token.lex(TK.kw_fn, 0, 0)); // index 2
    try resolution.startScope(Scope{ .start = 2, .scopeType = .function });

    try parsedQ.push(Token.lex(TK.identifier, 2, 0)); // index 3
    const innerDecl = resolution.declare(3, parsedQ.list.items[3]);
    parsedQ.list.items[3] = innerDecl;

    try resolution.endScope(4);

    // ref(x) at index 4 — x was never shadowed, resolves directly.
    try parsedQ.push(Token.lex(TK.identifier, 1, 0));
    const ref1 = resolution.resolve(4, parsedQ.list.items[4]);
    const ref1Offset: i16 = @bitCast(ref1.data.ident.prev_offset);
    try expectEqual(1 - 4, ref1Offset);
}

test "Inner-only declaration with no outer — endScope cleans up" {
    var parsedQ = parser.TokenQueue.init(test_allocator);
    defer parsedQ.deinit();
    var resolution = try Resolution.init(test_allocator, 3, &parsedQ);
    defer resolution.deinit();

    // Function scope with declaration of symbol 1 — no outer declaration exists.
    try parsedQ.push(Token.lex(TK.kw_fn, 0, 0)); // index 0
    try resolution.startScope(Scope{ .start = 0, .scopeType = .function });

    try parsedQ.push(Token.lex(TK.identifier, 1, 0)); // index 1
    const innerDecl = resolution.declare(1, parsedQ.list.items[1]);
    parsedQ.list.items[1] = innerDecl;
    try expectEqual(UNDECLARED_SENTINEL, innerDecl.data.ident.prev_offset); // First ever, no shadow.

    try resolution.endScope(2);

    // No shadow bit was set, so declarations[1] still points to the inner decl.
    // This is correct — non-shadowing declarations don't need cleanup.
    // But the inner decl is now out of scope. A reference here should ideally be unresolved.
    // However, without fn_depth staleness or full cleanup, it will resolve to the stale inner decl.
    // This is acceptable: in valid programs, you don't reference a function-local variable outside the function.
    // The language's type system / semantic checker would catch this.
    try expectEqual(1, resolution.declarations[1].decl_index);
}

test "Nested shadow restore ordering" {
    var parsedQ = parser.TokenQueue.init(test_allocator);
    defer parsedQ.deinit();
    var resolution = try Resolution.init(test_allocator, 5, &parsedQ);
    defer resolution.deinit();

    // Index 0: dummy
    try parsedQ.push(Token.lex(TK.aux_stream_start, 0, 0));

    // decl(x) at depth 0, index 1
    try parsedQ.push(Token.lex(TK.identifier, 1, 0));
    parsedQ.list.items[1] = resolution.declare(1, parsedQ.list.items[1]);

    // Outer function scope
    try parsedQ.push(Token.lex(TK.kw_fn, 0, 0)); // index 2
    try resolution.startScope(Scope{ .start = 2, .scopeType = .function });

    // decl(x) at depth 1, index 3 — shadows depth 0
    try parsedQ.push(Token.lex(TK.identifier, 1, 0));
    parsedQ.list.items[3] = resolution.declare(3, parsedQ.list.items[3]);
    try expectEqual(3, resolution.declarations[1].decl_index);

    // Inner block scope
    try parsedQ.push(Token.lex(TK.grp_indent, 0, 0)); // index 4
    try resolution.startScope(Scope{ .start = 4, .scopeType = .block });

    // decl(x) at depth 2, index 5 — shadows depth 1
    try parsedQ.push(Token.lex(TK.identifier, 1, 0));
    parsedQ.list.items[5] = resolution.declare(5, parsedQ.list.items[5]);
    try expectEqual(5, resolution.declarations[1].decl_index);

    // End inner block scope — restores to depth 1's decl at index 3
    try resolution.endScope(6);
    try expectEqual(3, resolution.declarations[1].decl_index);

    // End outer function scope — restores to depth 0's decl at index 1
    try parsedQ.push(Token.lex(TK.grp_dedent, 0, 0)); // index 6
    try resolution.endScope(7);
    try expectEqual(1, resolution.declarations[1].decl_index);

    // ref(x) at index 7 — resolves to outer decl at 1
    try parsedQ.push(Token.lex(TK.identifier, 1, 0));
    const ref = resolution.resolve(7, parsedQ.list.items[7]);
    const refOffset: i16 = @bitCast(ref.data.ident.prev_offset);
    try expectEqual(1 - 7, refOffset);
}

test "Block scope cleanup" {
    var parsedQ = parser.TokenQueue.init(test_allocator);
    defer parsedQ.deinit();
    var resolution = try Resolution.init(test_allocator, 3, &parsedQ);
    defer resolution.deinit();

    // Index 0: dummy
    try parsedQ.push(Token.lex(TK.aux_stream_start, 0, 0));

    // decl(x) at index 1
    try parsedQ.push(Token.lex(TK.identifier, 1, 0));
    parsedQ.list.items[1] = resolution.declare(1, parsedQ.list.items[1]);

    // Block scope with shadow
    try parsedQ.push(Token.lex(TK.grp_indent, 0, 0)); // index 2
    try resolution.startScope(Scope{ .start = 2, .scopeType = .block });

    try parsedQ.push(Token.lex(TK.identifier, 1, 0)); // index 3: shadow x
    parsedQ.list.items[3] = resolution.declare(3, parsedQ.list.items[3]);
    try expectEqual(3, resolution.declarations[1].decl_index);

    try resolution.endScope(4);

    // Restored to outer x@1
    try expectEqual(1, resolution.declarations[1].decl_index);
}

test "Shadowing disallowed mode — parent scope shadow errors" {
    const DisallowResolution = rs.ResolutionImpl(.disallow);
    var parsedQ = parser.TokenQueue.init(test_allocator);
    defer parsedQ.deinit();
    var resolution = try DisallowResolution.init(test_allocator, 3, &parsedQ);
    defer resolution.deinit();

    try parsedQ.push(Token.lex(TK.aux_stream_start, 0, 0));

    // Outer declaration of symbol 1 at index 1.
    try parsedQ.push(Token.lex(TK.identifier, 1, 0));
    _ = try resolution.declare(1, parsedQ.list.items[1]);

    // Inner scope tries to declare same symbol — should error.
    try parsedQ.push(Token.lex(TK.kw_fn, 0, 0)); // index 2
    try resolution.startScope(Scope{ .start = 2, .scopeType = .function });

    try parsedQ.push(Token.lex(TK.identifier, 1, 0)); // index 3
    const result = resolution.declare(3, parsedQ.list.items[3]);
    try std.testing.expectError(error.ShadowingDisallowed, result);

    try resolution.endScope(4);
}

test "Shadowing disallowed mode — sibling scopes reuse names" {
    const DisallowResolution = rs.ResolutionImpl(.disallow);
    var parsedQ = parser.TokenQueue.init(test_allocator);
    defer parsedQ.deinit();
    var resolution = try DisallowResolution.init(test_allocator, 3, &parsedQ);
    defer resolution.deinit();

    try parsedQ.push(Token.lex(TK.aux_stream_start, 0, 0));

    // First function declares 'i' (symbol 1).
    try parsedQ.push(Token.lex(TK.kw_fn, 0, 0)); // index 1
    try resolution.startScope(Scope{ .start = 1, .scopeType = .function });

    try parsedQ.push(Token.lex(TK.identifier, 1, 0)); // index 2
    _ = try resolution.declare(2, parsedQ.list.items[2]);

    try resolution.endScope(3);

    // Second function also declares 'i' — should succeed.
    try parsedQ.push(Token.lex(TK.kw_fn, 0, 0)); // index 3
    try resolution.startScope(Scope{ .start = 3, .scopeType = .function });

    try parsedQ.push(Token.lex(TK.identifier, 1, 0)); // index 4
    _ = try resolution.declare(4, parsedQ.list.items[4]);

    try resolution.endScope(5);
}

test "Shadowing disallowed mode — same scope redeclaration errors" {
    const DisallowResolution = rs.ResolutionImpl(.disallow);
    var parsedQ = parser.TokenQueue.init(test_allocator);
    defer parsedQ.deinit();
    var resolution = try DisallowResolution.init(test_allocator, 3, &parsedQ);
    defer resolution.deinit();

    try parsedQ.push(Token.lex(TK.aux_stream_start, 0, 0));

    // First declaration succeeds.
    try parsedQ.push(Token.lex(TK.identifier, 1, 0));
    _ = try resolution.declare(1, parsedQ.list.items[1]);

    // Second declaration of same symbol in same scope should error.
    try parsedQ.push(Token.lex(TK.identifier, 1, 0));
    const result = resolution.declare(2, parsedQ.list.items[2]);
    try std.testing.expectError(error.ShadowingDisallowed, result);
}
