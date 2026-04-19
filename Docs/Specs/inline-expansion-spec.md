# Inline Expansion Spec

> **Deferred (2026-04-19).** This design is paused pending the new IR stage.
> The parser no longer performs inline expansion; it emits a purely structural
> postfix queue with resolved identifier chains. Macros will be reintroduced
> on top of the IR. The rest of this document is preserved as a historical
> reference for the original design. See
> `2026-04-19-parser-simplification.md` for the current parser contract.

## Overview

Informal supports user-defined infix operators backed by lazy functions. A function with one eager parameter (lowercase) and one lazy parameter (ALL_CAPS) can be invoked as an infix operator via `op_identifier` syntax. The parser inlines the function body at the call site, binding the left operand to a local variable and deferring right operand parsing until the lazy parameter's splice point is reached in the body.

This is a compile-time template instantiation, not a runtime call. The expanded tokens in `parsedQ` are indistinguishable from hand-written code. Codegen requires no special handling.

**Key properties:**
- No new data structures — all metadata fits in existing 64-bit token fields
- No heap allocations during expansion — 24 bytes of stack-local state
- Body template is stored in `parsedQ` at definition time and read back during expansion
- Identifiers are re-resolved against the expansion-site scope using existing `resolution.resolve()`
- A new token kind `ident_splice` marks each lazy splice point — no flag bit required. Lazy functions are distinguished from eager ones by the header kind (`kw_lazy_fn` vs `kw_fn`).

**Dependencies:**
- `if`/`else` parsing must work before lazy function bodies that use control flow can be defined
- `bool()` or truthiness testing must exist for the canonical OR/AND patterns
- Phase 1 function definition (`kw_fn` handler) must exist — this spec covers Phase 2 additions on top of it

---

## Input

The expansion system consumes two inputs simultaneously:

**Body template** — a read-only region of `parsedQ` produced at function definition time. Contains postfix tokens, each lazy-parameter reference rewritten to kind `ident_splice` so the expansion walker can dispatch on kind alone.

**Right operand** — unconsumed tokens in `syntaxQ` following the `op_identifier`. Parsed from `syntaxQ` during the body walk when an `ident_splice` token is reached.

The left operand is already in `parsedQ` (emitted before the parser encountered the `op_identifier`). Its result sits on top of the evaluation stack.

---

## Limits and Constants

```
MAX_BODY_INDENT_DEPTH    = 4    // indent fixup stack depth (stack-local [4]u32)
```

---

## Token Modifications

### Splice kind

`ident_splice` is an identifier-family kind (alongside `identifier`, `const_identifier`, `call_identifier`, `type_identifier`) used for two things:

1. **Lazy-param body uses (references).** During `kwFn`, each lazy parameter's single body-use token has its `kind` rewritten from `const_identifier` to `ident_splice`. `symbol_id`, `prev_offset`, `next_offset`, and `flags` are preserved verbatim. `flags.declaration` stays `false` — this is a reference token.

2. **Synthesised eager-param bindings at expansion sites.** When `opIdentifierInfix` inlines a `kw_lazy_fn` call, it emits an eager-param binding with `kind = ident_splice` and `flags.declaration = true`. Codegen sees "ident_splice declaration" and pops the already-evaluated operand off the stack instead of allocating a fresh register.

The expansion walker dispatches on `kind == .ident_splice` to decide whether to parse a fresh operand from `syntaxQ` (body-use case) or copy the token through (everything else).

---

## Function Header Token (`kw_fn` / `kw_lazy_fn` in `parsedQ`)

When a function definition is parsed, the `kw_fn` handler emits a header token immediately after the function name declaration. This token serves as the boundary marker for codegen (skip-over) and the metadata source for inline expansion.

```
 63                               16 15        8 7         0
┌──────────────────────────────────┬───────────┬──────────┐
│ body_length (32)  body_offset(16)│  kind     │ flags    │
└──────────────────────────────────┴───────────┴──────────┘
```

**Header kind**: `kw_lazy_fn` if the function has ≥1 lazy parameter, otherwise `kw_fn`. This is the sole lazy/eager distinction — no metadata bit required.

**`body_length`** (u32): number of tokens to skip for codegen, counting from the token after fn_header. Includes the param-list group chain and the body proper.

**`body_offset`** (u16): distance from fn_header to the first body token (i.e. one past the matching `grp_close_paren`).

Parameter count is not stored in the header; it's inferred from the param-list chain (walk from the header's `grp_open_paren` to its matching `grp_close_paren`).

**Adjacency invariant:** fn_header is always at `parsedQ[declaration_index + 1]`, where `declaration_index` is the position of the function name's identifier token (with `flags.declaration = 1`). This +1 convention is enforced structurally by the `kw_fn` handler — nothing may be emitted between the function name declaration and the fn_header.

---

## `parsedQ` Layout After Function Definition

Example: `fn OR(first, SECOND): if bool(first): first else: SECOND`

```
parsedQ[N+0]   identifier("OR")       flags.declaration=1  symId(OR)
parsedQ[N+1]   kw_lazy_fn (fn_header) body_length / body_offset
parsedQ[N+2]   grp_open_paren
parsedQ[N+3]   identifier("first")    flags.declaration=1  symId(first)
parsedQ[N+4]   sep_comma              arg_idx=1
parsedQ[N+5]   const_ident("SECOND")  flags.declaration=1  symId(SECOND)
parsedQ[N+6]   grp_close_paren
               — body tokens begin (N + body_offset) —
parsedQ[N+7]   identifier("first")    prev_offset → decl at N+3
parsedQ[N+8]   call_identifier("bool")
parsedQ[N+9]   kw_if
parsedQ[N+10]  grp_indent             arg0=N+12 (patched)  arg1=scopeId
parsedQ[N+11]  identifier("first")    prev_offset → decl at N+3
parsedQ[N+12]  grp_dedent             arg0=N+10            arg1=scopeId
parsedQ[N+13]  kw_else
parsedQ[N+14]  grp_indent             arg0=N+16 (patched)  arg1=scopeId2
parsedQ[N+15]  ident_splice           symId(SECOND)        prev_offset → decl at N+5
parsedQ[N+16]  grp_dedent             arg0=N+14            arg1=scopeId2
               — body tokens end —
```

**Key observations:**
- Header kind is `kw_lazy_fn` because ≥1 parameter is lazy.
- Parameter list is a Phase-A group chain: `grp_open_paren`, decl, `sep_comma` (with `arg_idx`), decl, `grp_close_paren`.
- Param decls are ordinary identifier-family tokens with `flags.declaration = 1`. Eager vs lazy is distinguished by `kind`: `identifier` = eager, `const_identifier` = lazy.
- The lazy-param body-use at N+15 has kind `ident_splice` (rewritten from `const_identifier` by `kwFn`).
- `grp_indent`/`grp_dedent` pairs store absolute `parsedQ` indices (will need patching during expansion).

---

## Lazy Function Detection

A function becomes `kw_lazy_fn` at definition time if it has ≥1 parameter of `const_identifier` kind. For each lazy parameter, the following invariants must hold:

1. The lazy parameter's symbol ID is referenced exactly once in the body.

If a lazy parameter is referenced 0 times, `kwFn` returns `error.LazyParamUnused`. If referenced more than once, it returns `error.LazyParamUsedMoreThanOnce`.

The infix-inline handler (`opIdentifierInfix`) additionally requires:
- Header kind `kw_lazy_fn` (not `kw_fn`).
- 2 parameters.
- Slot 0 eager, slot 1 lazy. Any other shape falls back to the binary-op path (first-param-lazy in infix is excluded by design — it would require retroactive left-operand patching).

Pure-eager functions (`kw_fn`) do not inline; prefix-N-ary expansion is a future phase.

---

## Rewriting Lazy Body Uses at Definition Time

During body parsing within the `kwFn` handler, expressions are parsed normally and identifiers resolve via the existing `resolution.resolve()` path. After the body parse completes (and after `endScope` so the use-chain offsets are final), `kwFn` iterates over the set bits of a `BitSet64 lazyMask` (bit `i` = 1 iff param slot `i` is lazy). For each lazy slot:

1. Walk the param decl's `next_offset` to the single body-use.
2. Validate that use's `next_offset == 0` (exactly one reference).
3. Rewrite the use token's `kind` from `const_identifier` to `ident_splice`. `symbol_id`, `prev_offset`, `next_offset`, and `flags` are preserved verbatim.

Because param decl `i` sits at `openIdx + 1 + 2*i` (group chain layout), no extra bookkeeping is needed.

---

## Inline Expansion: `op_identifier` Infix Handler

When the parser encounters an `op_identifier` token in infix position, it performs inline expansion. The left operand has already been emitted to `parsedQ`. The right operand is unconsumed in `syntaxQ`.

### Step-by-step procedure

**Step 1: Locate the function.**

Resolve the operator name via `resolution.resolve()`. This yields the declaration index in `parsedQ`. Read the fn_header at `declaration_index + 1`. Assert the lazy flag (bit 15 of `arg1`) is set.

Extract from fn_header:
- `body_length` from `arg0`
- `param_count` from `arg1 & 0xFF` (should be 2)

**Step 2: Read parameter declarations.**

Read `parsedQ[declaration_index + 2]` and `parsedQ[declaration_index + 3]`.

Identify by token kind:
- `identifier` kind → eager parameter. Extract its `arg0` as `eager_symbol_id`.
- `const_identifier` kind → lazy parameter. Extract its `arg0` as `lazy_symbol_id`.

**Step 3: Push inline scope and declare eager parameter.**

Push a `.block` scope via `resolution.startScope(.block)`.

Emit a fresh identifier token to `parsedQ`:
- `kind = .identifier`
- `arg0 = eager_symbol_id`
- `flags.declaration = 1`

Call `resolution.declare()`. This binds the eager parameter name to the current `parsedQ` position. The stack-top value (the already-evaluated left operand) is now bound to this name.

**Step 4: Walk body template.**

Iterate over the body tokens from `declaration_index + 4` through `declaration_index + 1 + body_length` (inclusive). For each template token:

| Condition | Action |
|-----------|--------|
| `kind == .ident_splice` | **Splice**: call `parse(binding_power)` to consume the right operand from `syntaxQ`. The Pratt parser emits the right operand's postfix tokens directly to `parsedQ` at the current write position. Do NOT copy this template token. |
| `kind == .identifier` or `kind == .const_identifier` | **Re-resolve**: emit a copy of the token to `parsedQ`. Call `resolution.resolve()` on the emitted token to compute a fresh `prev_offset` against the current scope. |
| `kind == .grp_indent` | **Indent fixup**: emit with `arg0 = 0` (placeholder). Push the new `parsedQ` index onto the local fixup stack. Set `arg1` to current inline scope ID. |
| `kind == .grp_dedent` | **Dedent fixup**: pop the fixup stack to get the matching indent's `parsedQ` index. Patch `parsedQ[indent_index].arg0 = current_index`. Emit with `arg0 = indent_index`, `arg1` = scope ID. |
| Anything else | **Copy**: emit the 64-bit token value as-is. |

**Step 5: Pop inline scope.**

Call `resolution.endScope()`. This restores `declarations[eager_symbol_id]` to its pre-expansion value, preventing the inline binding from leaking into the enclosing scope.

### Stack-local state during expansion

```
eager_symbol_id  : u32       // extracted from param declaration
lazy_symbol_id   : u32       // extracted from param declaration (used only for debug assertions)
fixup_stack      : [4]u32    // indent parsedQ indices awaiting dedent patching
fixup_depth      : u8        // current fixup stack depth
```

Total: 24 bytes on the Zig stack frame. No heap allocation.

---

## Worked Example: Full Expansion Trace

Source: `x OR y + 1`

Assume `OR` is defined as above (declaration at index N). The parser has emitted the left operand:

```
parsedQ[M-1]  identifier("x")     ← left operand, already resolved
```

Parser encounters `op_identifier("OR")` with binding power Comparison (60).

**Expansion:**

```
Step 1: Resolve "OR" → declaration at N. Read fn_header at N+1.
        body_length=12, lazy=1, param_count=2.

Step 2: Read N+2 (identifier "first") → eager_symbol_id = S_first
        Read N+3 (const_ident "SECOND") → lazy_symbol_id = S_second

Step 3: Push .block scope.
        Emit declaration:
  [M]   identifier("first")  flags.dc=1  arg0=S_first  arg1=from_declare()

Step 4: Walk body tokens N+4..N+13:

  N+4  identifier("first")          → re-resolve
  [M+1] identifier("first")  arg0=S_first  arg1=-1 (→ decl at M)

  N+5  call_identifier("bool")      → copy as-is
  [M+2] call_identifier("bool")

  N+6  kw_if                        → copy as-is
  [M+3] kw_if

  N+7  grp_indent                   → fixup: push M+4
  [M+4] grp_indent  arg0=0 (placeholder)

  N+8  identifier("first")          → re-resolve
  [M+5] identifier("first")  arg0=S_first  arg1=-5 (→ decl at M)

  N+9  grp_dedent                   → fixup: pop → patch M+4.arg0 = M+6
  [M+6] grp_dedent  arg0=M+4
        parsedQ[M+4].arg0 = M+6

  N+10 kw_else                      → copy as-is
  [M+7] kw_else

  N+11 grp_indent                   → fixup: push M+8
  [M+8] grp_indent  arg0=0 (placeholder)

  N+12 const_ident("SECOND") sp=1   → SPLICE: parse(60) from syntaxQ
       Consumes "y", "+", "1" → emits:
  [M+9]  identifier("y")  resolved against enclosing scope
  [M+10] lit_number(1)
  [M+11] op_add

  N+13 grp_dedent                   → fixup: pop → patch M+8.arg0 = M+12
  [M+12] grp_dedent  arg0=M+8
         parsedQ[M+8].arg0 = M+12

Step 5: Pop inline scope. declarations[S_first] restored.
```

**Result in `parsedQ`:**
```
[M-1]  identifier("x")
[M]    decl("first")         ← binds stack-top to "first"
[M+1]  identifier("first")   ← resolved to M
[M+2]  call_bool
[M+3]  kw_if
[M+4]    grp_indent (→ M+6)
[M+5]    identifier("first") ← resolved to M
[M+6]    grp_dedent (→ M+4)
[M+7]  kw_else
[M+8]    grp_indent (→ M+12)
[M+9]    identifier("y")
[M+10]   lit_number(1)
[M+11]   op_add
[M+12]   grp_dedent (→ M+8)
```

Valid postfix. Correct identifier offsets. Correct indent/dedent pairs. Codegen processes this like any other expression.

---

## `kw_fn` Handler: Definition-Time Procedure

The `kw_fn` prefix handler parses the full function definition and emits the template into `parsedQ`.

### Procedure

1. Pop the function name token from `syntaxQ`. Emit to `parsedQ` with `flags.declaration = 1`. Call `resolution.declare()`.

2. Emit fn_header token (kind = `kw_fn`) with `arg0 = 0` (placeholder for body_length). Record its `parsedQ` index as `header_idx`.

3. Pop `grp_open_paren` from `syntaxQ`.

4. For each parameter (until `grp_close_paren`):
   - Pop identifier token from `syntaxQ`. Emit to `parsedQ` with `flags.declaration = 1`.
   - Call `resolution.declare()` to register in the function scope.
   - Track token kind: `identifier` → eager, `const_identifier` → lazy.
   - If lazy, record its symbol ID as `lazy_symbol_id`.
   - Count total params, eager count, lazy count.

5. Pop `grp_close_paren`, pop `op_colon_assoc` from `syntaxQ`.

6. Push a `function` scope via `resolution.startScope(.function)`.

7. Parse the body: call `parse(None)`. Body tokens are emitted to `parsedQ` with identifiers resolved via the function scope.

8. Pop scope via `resolution.endScope()`.

9. **Lazy-use kind rewrite**: iterate the set bits of `lazyMask` (bit `i` = param slot `i` is lazy). For each lazy slot, walk `next_offset` from the param decl to its single body-use. Verify the use's `next_offset == 0` (single reference). Rewrite the use's `kind` from `const_identifier` to `ident_splice`. Errors: `error.LazyParamUnused` if `decl.next_offset == 0`; `error.LazyParamUsedMoreThanOnce` if the use has another `next_offset`.

10. Patch fn_header: kind = `kw_lazy_fn` if `lazyMask.count() > 0` else `kw_fn`; body_length = `parsedQ.len - header_idx - 1`; body_offset = close_paren_idx + 1 - header_idx.

---

## Codegen Interaction

### Skip-over

When codegen encounters a `kw_fn` token in `parsedQ` during its linear walk, it reads `body_length` from `arg0` and advances the read cursor past the body. The function body is not executed inline — it is either jumped to via a call instruction (Phase 1) or its tokens have been spliced at expansion sites (Phase 2, where the original body is dead code).

### No special handling for expanded tokens

The expansion produces standard postfix tokens with standard identifier offsets. Codegen processes them identically to manually-written expressions. The `if`/`else`, indent/dedent, and identifier resolution all use the same codegen paths as non-expanded code.

### Dead code

If a lazy function is only ever called via `op_identifier` (inline expansion), its body tokens in `parsedQ` at the definition site are never executed. They remain as dead code. The skip-over mechanism handles this — codegen jumps past them. Dead code elimination is deferred.

---

## Error Conditions

| Condition | Detected at | Error |
|-----------|-------------|-------|
| `op_identifier` name not found in scope | expansion time | "undefined operator" |
| `op_identifier` resolves to non-lazy function (header kind is `kw_fn`) | expansion time | falls back to binary-op path (not an error) |
| Lazy param referenced 0 times in body | definition time | `error.LazyParamUnused` |
| Lazy param referenced 2+ times in body | definition time | `error.LazyParamUsedMoreThanOnce` |
| More than 4 indent levels in body | expansion time | fixup stack overflow (practical limit, not spec limit) |
| Function not defined before use | expansion time | standard "undefined symbol" from resolution |

---

## Invariants

1. **Adjacency**: fn_header is always at `parsedQ[declaration_index + 1]`. Nothing may be emitted between the function name declaration and fn_header.

2. **Splice uniqueness**: for each lazy parameter, exactly one token in the body has `kind == ident_splice` (rewritten from `const_identifier` by `kwFn`). Enforced at definition time.

3. **Scope restoration**: after expansion, `declarations[]` entries for the eager parameter symbol are restored to pre-expansion values by `resolution.endScope()`. The inline binding does not leak.

4. **Postfix validity**: at every point during the expansion walk, `parsedQ` contains valid postfix tokens with correct identifier offsets. After expansion completes, the result is indistinguishable from hand-written code.

5. **syntaxQ consumption**: the right operand tokens are always consumed from `syntaxQ` during expansion (at the splice point). The laziness is a runtime property — the generated code may not execute the spliced tokens, but parsing always consumes them.

---

## Open Questions

1. **Builtin resolution during expansion.** If the body calls a builtin like `bool()`, the `call_identifier("bool")` token is copied as-is during expansion. If builtins are resolved by symbol ID (not by i16 offset), this works. If they are resolved by offset, the offset will be wrong at the expansion site. Verify how builtins are registered in `declarations[]`.

2. **Normal call syntax for lazy functions.** Can `OR(a, b)` call a lazy function using the standard call convention (evaluating both arguments eagerly)? The body exists in `parsedQ` for Phase 1 codegen. Both paths could work. Decision deferred.

3. **Scope restoration correctness.** The spec describes `resolution.endScope()` in terms of forward-ref patching. Verify that it also restores `declarations[]` entries for symbols that were shadowed by the inline scope's eager parameter binding.

4. **Variable binding power.** All `op_identifier` tokens currently share Comparison (60) binding power. If different lazy operators need different precedences, the grammar table entry for `op_identifier` would need per-token power lookup — possibly via the fn_header's reserved bits in `arg1`. Deferred.
