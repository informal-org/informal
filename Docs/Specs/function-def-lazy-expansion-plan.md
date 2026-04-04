# Plan: Function Definition and Lazy Inline Expansion

## Context

The Informal compiler has a working pipeline (Lexer → Pratt Parser → ARM Codegen) that handles arithmetic, identifiers, assignment, and basic conditionals in codegen. The next milestone is user-defined functions: `fn name(params): body` definitions and calls. A subset of functions — those with one eager and one lazy (ALL_CAPS) parameter — can be invoked as infix operators via `op_identifier`, causing compile-time inline expansion of the body at the call site.

The two specs (`inline-expansion-spec.md` and `2026-04-02-functions-and-lazy-params.md`) describe the full design. This plan implements it in 7 steps, each independently testable.

**Key discovery**: The lexer has `token_keyword_or_identifier()` ready (line 522) but it's dead code — the main lex loop at line 930 calls `token_identifier()` directly, so `fn`/`if`/`else` are emitted as regular identifiers. This must be fixed first.

---

## Step 0: Wire Up Keyword Lexing

**File**: `src/lexer.zig` line 930

Change `token_identifier(self.index)` to `token_keyword_or_identifier()`. The existing function already handles fallback to `token_identifier(start)` for non-keywords.

**Test**: Unit test that lexes `"fn"` and verifies `kw_fn` token is produced. Lexing `"if"` produces `kw_if`. Lexing `"foobar"` still produces `identifier`.

---

## Step 1: `kw_if` Prefix Handler (Parser)

**File**: `src/parser.zig`

The parser has no handler for `kw_if` (line 164 TODO). The codegen already handles `kw_if`, `op_colon_assoc`, `grp_indent`/`grp_dedent`, `kw_else` in its switch statement, so we just need the parser to produce the right token sequence.

1. Add `kwIf` to the `ParserType` enum
2. Register in grammar: `grammar.prefix(Kind.kw_if, .kwIf, .None)`
3. Add `kwIf` handler function to `parseFns` array
4. Add `kwElse` to ParserType, register `grammar.prefix(Kind.kw_else, .kwElse, .None)`, add handler

**kwIf handler logic**:
```
fn kwIf(self, token):
    parse(Power.None)        // parse condition expression
    emit(token)              // emit kw_if in postfix position
    colon = syntaxQ.pop()    // consume op_colon_assoc  
    emit(colon)              // emit it
    parse(Power.None)        // parse then-branch (will hit grp_indent → indentBlock)
    // Check for else
    if syntaxQ.peek().kind == kw_else:
        elseToken = syntaxQ.pop()
        emit(elseToken)
        colon2 = syntaxQ.pop()   // consume op_colon_assoc after else
        emit(colon2)
        parse(Power.None)        // parse else-branch
```

**kwElse handler**: This handles `kw_else` when it appears in prefix position (shouldn't normally happen, but needed as a stop token). Just emit it — or make it a no-op that returns without parsing, acting as a terminator.

**Test**: Parser test with `if 1 > 2: 42` producing correct postfix sequence. Enable the `if.ifi` file test (expects exit code 1).

---

## Step 2: `kw_fn` Prefix Handler (Parser)

**File**: `src/parser.zig`

1. Add `kwFn` to ParserType enum
2. Register: `grammar.prefix(Kind.kw_fn, .kwFn, .None)`
3. Add handler to parseFns

**kwFn handler logic** (follows the spec's definition-time procedure):
```
fn kwFn(self, token):
    // 1. Function name
    nameToken = syntaxQ.pop()           // identifier("name")
    declName = resolution.declare(parsedQ.len, nameToken)
    emit(declName)                      // emit with flags.declaration=1
    
    // 2. fn_header placeholder
    headerIdx = parsedQ.len
    emit(Token.lex(kw_fn, 0, 0))       // arg0=0 (placeholder), arg1=0
    
    // 3. Parameters
    assert(syntaxQ.pop().kind == grp_open_paren)
    paramCount = 0
    resolution.startScope(Scope{.start=headerIdx, .scopeType=.function})
    
    while (syntaxQ.peek().kind != grp_close_paren):
        if syntaxQ.peek().kind == sep_comma: _ = syntaxQ.pop()  // skip comma
        paramToken = syntaxQ.pop()      // identifier or const_identifier
        declParam = resolution.declare(parsedQ.len, paramToken)
        emit(declParam)
        paramCount += 1
    
    syntaxQ.pop()  // consume close_paren
    syntaxQ.pop()  // consume op_colon_assoc
    
    // 4. Parse body
    parse(Power.None)
    
    // 5. Pop scope
    resolution.endScope(parsedQ.len)
    
    // 6. Patch fn_header
    bodyLength = parsedQ.len - headerIdx - 1
    parsedQ[headerIdx] = Token.lex(kw_fn, bodyLength, paramCount)
```

**Test**: Parser test with `fn add(a, b): a + b` verifying the parsedQ layout matches the spec — declaration of "add", fn_header with body_length, param declarations, body tokens with correct resolution offsets.

---

## Step 3: Codegen Skip-Over for Function Bodies

**File**: `src/codegen.zig`

When codegen encounters `kw_fn` in `parsedQ`, it must skip the function body (it's dead code that gets inlined at call sites or jumped to via calls).

1. Add `skip_count: u32 = 0` field to Codegen struct
2. At the top of the `for` loop body, check: if `skip_count > 0`, decrement and continue
3. In the `kw_fn` case of the switch: read `body_length` from `token.data.value.arg0`, set `skip_count = body_length`

Also handle the identifier declaration that precedes kw_fn — it's the function name. Codegen should still process it as a declaration (allocate register, etc.) so the name is available for call resolution later. The skip only starts after the kw_fn token.

**Test**: File test — define a function and ensure the program doesn't crash (the body is skipped). E.g., `fn add(a, b): a + b\n5` should produce exit code 5.

---

## Step 4: Splice Flag in Token Flags

**File**: `src/token.zig`

Modify the `Flags` packed struct to add the splice bit:
```zig
pub const Flags = packed struct(u8) {
    alt: bool = false,
    declaration: bool = false,
    splice: bool = false,       // bit 2: lazy parameter splice point
    _reserved: u5 = 0,
};
```

**Test**: Compile succeeds. Existing tests pass (splice defaults to false).

---

## Step 5: Lazy Detection and Splice Flag Injection

**File**: `src/parser.zig` (modify kwFn handler)

During body parsing in the kwFn handler:

1. After parsing parameters, identify if this is a lazy function:
   - Exactly 2 params, one `identifier` (eager), one `const_identifier` (lazy)
   - Track `lazy_symbol_id` and `eager_symbol_id`

2. After `parse(Power.None)` returns (body parsed), scan the body region in parsedQ for tokens whose `arg0 == lazy_symbol_id`. For each match, set `aux.splice = true` and increment a splice counter.

3. Validate splice_counter == 1 (error if 0 or 2+).

4. Pack metadata into fn_header's arg1: `(lazy_flag << 15) | param_count`. The lazy_flag is bit 15 of the u16.

**Post-processing approach** (scan body after parsing) is simpler than injecting checks during parsing, and the body is small (typically < 20 tokens).

**Test**: Parser test defining `fn OR(first, SECOND): first` — verify fn_header has lazy flag set, the SECOND reference in the body has `aux.splice = true`.

---

## Step 6: Scope Restoration in Resolution

**File**: `src/resolution.zig`

Currently `endScope` only patches the `grp_indent` token's `arg0`. For inline expansion, we need `endScope` to restore `declarations[]` entries that were shadowed by declarations within the scope.

Modify `endScope(index)`:
1. Walk `parsedQ[scope.start..index]`
2. For each token with `aux.declaration == true`: read its symbol ID from `arg0` and its previous-declaration offset from `arg1`. If the offset is non-zero, compute `declarations[symbolId] = applyOffset(i16, tokenIndex, offset)` (restoring the previous declaration). If zero (first declaration), set `declarations[symbolId] = UNDECLARED_SENTINEL`.
3. Make the `grp_indent` patching conditional — only patch if `parsedQ[scope.start].kind == grp_indent`. Inline expansion scopes don't start with `grp_indent`.

**Test**: Unit test — declare `x` in outer scope, push scope, declare `x` in inner scope, pop scope, verify `declarations[x_symbol]` points back to the outer declaration.

---

## Step 7: `op_identifier` Inline Expansion Handler

**File**: `src/parser.zig`

1. Add `opIdentifierInfix` to ParserType enum
2. Change grammar entry: `grammar.infix(Kind.op_identifier, .opIdentifierInfix, .Comparison)`
3. Add handler to parseFns

**opIdentifierInfix handler logic** (follows the inline expansion spec):
```
fn opIdentifierInfix(self, token):
    // Step 1: Resolve function
    resolved = resolution.resolve(parsedQ.len, token)
    declIndex = applyOffset(i16, parsedQ.len, resolved.data.value.arg1)
    fnHeader = parsedQ[declIndex + 1]
    bodyLength = fnHeader.data.value.arg0
    metadata = fnHeader.data.value.arg1
    assert(metadata & 0x8000 != 0)  // lazy flag set
    paramCount = metadata & 0xFF
    
    // Step 2: Read parameters
    param1 = parsedQ[declIndex + 2]  // eager (identifier kind)
    param2 = parsedQ[declIndex + 3]  // lazy (const_identifier kind)
    eagerSymbolId = param1.data.value.arg0
    lazySymbolId = param2.data.value.arg0
    
    // Step 3: Push scope, declare eager param
    scopeStart = parsedQ.len
    resolution.startScope(Scope{.start=scopeStart, .scopeType=.block})
    eagerDecl = resolution.declare(parsedQ.len, Token.lex(identifier, eagerSymbolId, 0))
    emit(eagerDecl)  // binds stack-top (left operand) to eager param name
    
    // Step 4: Walk body template
    var fixupStack: [4]u32 = undefined
    var fixupDepth: u8 = 0
    bodyStart = declIndex + 2 + paramCount  // skip params
    bodyEnd = declIndex + 1 + bodyLength    // inclusive
    
    var i = bodyStart
    while (i <= bodyEnd):
        // IMPORTANT: read from parsedQ each iteration (not a cached slice)
        templateToken = self.parsedQ.list.items[i]
        
        if templateToken.aux.splice:
            // Splice: parse right operand from syntaxQ
            parse(Power.Comparison.val())
        else if templateToken.kind == identifier or templateToken.kind == const_identifier:
            // Re-resolve against current scope
            freshToken = Token.lex(templateToken.kind, templateToken.data.value.arg0, 0)
            resolved = resolution.resolve(parsedQ.len, freshToken)
            emit(resolved)
        else if templateToken.kind == grp_indent:
            emitIdx = parsedQ.len
            emit(Token.lex(grp_indent, 0, resolution.scopeId))  // placeholder
            fixupStack[fixupDepth] = emitIdx
            fixupDepth += 1
        else if templateToken.kind == grp_dedent:
            fixupDepth -= 1
            indentIdx = fixupStack[fixupDepth]
            emitIdx = parsedQ.len
            emit(Token.lex(grp_dedent, indentIdx, resolution.scopeId))
            parsedQ[indentIdx] = Token.lex(grp_indent, emitIdx, resolution.scopeId)
        else:
            // Copy as-is (kw_if, kw_else, op_colon_assoc, call_identifier, literals, operators)
            emit(templateToken)
        
        i += 1
    
    // Step 5: Pop scope
    resolution.endScope(parsedQ.len)
```

**Critical detail**: The body template indices (`declIndex + 2 + paramCount` through `declIndex + 1 + bodyLength`) reference the original function definition in parsedQ. Because `emit()` appends to parsedQ (which may reallocate), we must NOT cache a pointer/slice to parsedQ items — re-index `self.parsedQ.list.items[i]` on each iteration.

**Test**: 
- Parser test: `fn OR(first, SECOND): first` then `x OR y` — verify expansion produces: `identifier(x), decl(first), identifier(first) resolved to decl, identifier(y)`
- File test: `fn OR(first, SECOND): first\ntrue OR 42\n7` — exit code 7 (body just returns first/left operand, true=1, but program ends with 7)
- Full OR with if/else once Step 1 is working

---

## File Summary

| File | Changes |
|------|---------|
| `src/lexer.zig:930` | Call `token_keyword_or_identifier()` instead of `token_identifier()` |
| `src/token.zig:129-137` | Add `splice: bool` to Flags, reduce _reserved to u5 |
| `src/parser.zig:50` | Add `kwFn`, `kwIf`, `kwElse`, `opIdentifierInfix` to ParserType enum |
| `src/parser.zig:89-166` | Add grammar entries for kw_if, kw_else, kw_fn, change op_identifier |
| `src/parser.zig` (new fns) | `kwIf`, `kwElse`, `kwFn`, `opIdentifierInfix` handler functions |
| `src/resolution.zig:110-116` | Enhance endScope to restore declarations[] and conditionally patch grp_indent |
| `src/codegen.zig:183+` | Add skip_count for kw_fn body skip-over |
| `src/test/test_parser.zig` | Unit tests for each step |
| `src/filetest.zig` | Enable if.ifi test, add fn and inline expansion file tests |
| `Tests/FileTests/` | New .ifi test files for functions and inline expansion |

## Verification

1. `zig test Code/Compiler/src/lexer.zig` — keyword lexing works
2. `zig test Code/Compiler/src/parser.zig` — all parser tests pass including new ones
3. `zig test Code/Compiler/src/resolution.zig` — scope restoration works
4. `just test` — all unit + file tests pass
5. `just run if` — if.ifi compiles and returns exit code 1
6. Create `fn_skip.ifi` with `fn add(a, b): a + b\n5` — returns 5
7. Create `inline_or.ifi` with OR function and test lazy evaluation
