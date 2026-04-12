# Parser Spec

## Overview

The parser takes the token stream from the lexer and produces a **postfix-ordered parsed queue** suitable for direct bytecode emission. It is a **recursive Pratt (top-down operator precedence) parser** using compile-time lookup tables for dispatch and precedence resolution.

**Key properties:**
- Single-pass, no backtracking, no lookahead beyond one token
- Recursive descent: each handler calls `parse(minBindingPower)` for sub-expressions
- No heap-allocated AST nodes — output is a flat postfix token queue
- Symbol resolution is interleaved with parsing (no separate pass)
- User-defined infix operators are **fexpr-style macros**: the body template lives in `parsedQ`, and `op_identifier` expands it inline at the call site, with one lazy parameter whose operand is captured unevaluated and spliced into the expansion

---

## Input

**Token Streams:**
- Consumes `syntaxQ` produced by the lexer; tokens popped in-order via `pop()`
- `auxQ` is wired in but currently unused
- Stream terminates with `aux_stream_end` sentinel (kind = 255)

**Assumptions from Lexer:**
- Unary minus is pre-normalized to `op_unary_minus` (no ambiguous `-`)
- `call_identifier` tokens guarantee the next token is `grp_open_paren`
- Indentation is already converted to `grp_indent` / `grp_dedent` tokens

---

## Output

### Parsed Queue (`parsedQ`)

Output is in **postfix order** — operands appear before their operator. This eliminates child pointers and enables direct bytecode emission.

Example: `1 + 2 * 3` → `[AUX_STREAM_START, 1, 2, 3, *, +]`

`parsedQ[0]` is always `aux_stream_start`. Index 0 acts as a null sentinel for symbol resolution — no valid declaration holds index 0.

### Offset Queue (`offsetQ`)

A parallel `u16` queue: for each token in `parsedQ`, stores a distance back to its corresponding position in `syntaxQ`. Used to map parsed tokens back to source positions.

---

## Grammar Table

The parser uses a compile-time `[64]TokenParser` table, one entry per `Kind` enum value (only the first 64 values are parsed; aux tokens are ignored).

```zig
const TokenParser = packed struct(u24) {
    prefix: ParserType = .none,  // Null denotation: token starts an expression
    infix:  ParserType = .none,  // Left denotation: token follows an expression
    power:  Power      = .None,  // Left binding power
};
```

Each `ParserType` maps to a handler function via a second compile-time array `parseFns[64]ParseFn`, keyed by `@intFromEnum(ParserType)`. This two-level indirection keeps `TokenParser` packed in 24 bits while still dispatching to full function pointers.

### Binding Power Levels

```
None         = 0    (terminals, unregistered tokens)
Separator    = 10   (,  newline)
Assign       = 20   (=  +=  -=  *=  /=)
Or           = 30   (OR  |)
And          = 40   (AND)
Equality     = 50   (==  !=)
Comparison   = 60   (< > <= >= in is as op_identifier const_identifier-infix)
Additive     = 70   (+ -)
Multiplicative = 80 (* / %)
Exp          = 90   (^)
Unary        = 100  (NOT  unary -)
Member       = 110  (.)
Call         = 120  (reserved, not yet wired)
```

## Handler Reference

### Prefix Handlers

| Handler | Tokens | Behavior |
|---------|--------|----------|
| `literal` | `lit_number`, `lit_string`, `lit_bool`, `lit_null` | Emit token directly |
| `identifier` | `identifier`, `const_identifier` | Call `resolution.resolve()`; emit resolved token |
| `callExpr` | `call_identifier` | Pop & assert `grp_open_paren`; `parse(None)`; pop `grp_close_paren`; emit identifier |
| `unaryOp` | `op_not`, `op_unary_minus` | `parse(Unary)`; emit operator (postfix) |
| `skipNewLine` | `sep_newline` | `parse(None)` — newline at expression start is skipped |
| `groupParen` | `grp_open_paren` | `parse(None)`; pop & assert `grp_close_paren` |
| `groupBracket` | `grp_open_bracket` | `parse(None)`; pop & assert `grp_close_bracket` |
| `groupBrace` | `grp_open_brace` | `parse(None)`; pop & assert `grp_close_brace` |
| `indentBlock` | `grp_indent` | See Indentation Blocks below |
| `kwIf` | `kw_if` | See Conditionals below |
| `kwElse` | `kw_else` | Errors if encountered as standalone prefix (must be consumed by `kwIf`) |
| `kwFn` | `kw_fn` | See Functions below |

### Infix Handlers

| Handler | Tokens | Behavior |
|---------|--------|----------|
| `binaryOp` | Most binary ops | `parse(power + 1)` (left-assoc); emit operator |
| `binaryRightAssocOp` | `op_pow` | `parse(power)` (right-assoc); emit operator |
| `assignOp` | `op_assign_eq`, `op_plus_eq`, `op_minus_eq`, `op_mul_eq`, `op_div_eq` | Retroactively declare LHS; `parse(Assign)`; emit operator |
| `colonAssocOp` | `op_colon_assoc` | `parse(Separator)`; emit token |
| `separator` | `sep_comma`, `sep_newline` (infix) | `parse(Separator)` — continues expression after separator |
| `opIdentifierInfix` | `const_identifier`, `op_identifier` | Fexpr-style macro expansion — see Inline Expansion below |

---

## Indentation Blocks

`indentBlock` is the prefix handler for `grp_indent`:

1. Capture current `scopeId` and `startIdx` (`parsedQ` length).
2. Emit `grp_indent` with `Data.Scope.index = 0` (patched later), `scope_id = scopeId`.
3. Call `resolution.startScope(.block)` — pushes scope and increments `scopeId`.
4. `parse(None)` — consumes the indented body.
5. Pop `grp_dedent` from `syntaxQ` if present.
6. Emit `grp_dedent` with `Data.Scope.index = startIdx`, `scope_id = scopeId`.
7. Call `resolution.endScope(end_index)` — patches the `grp_indent` token's `Data.Scope.index = end_index`.

After the block, the `grp_indent` token carries `index = end_index` (end of the block) and `scope_id`; the `grp_dedent` carries `index = start_index` (position of the indent) and the same `scope_id`.

---

## Conditionals

Conditionals use `if`/`else` with colon-delimited branches. The condition is emitted first in postfix order, followed by the branch bodies.

**Syntax:**
```
if <condition>:
    <then-body>
else:
    <else-body>
```

The `else` branch is optional. Nested conditionals are expressed by placing `if` inside an `else` branch.

**parsedQ layout:**
```
[condition...] kw_if op_colon_assoc [then-branch...] [kw_else op_colon_assoc [else-branch...]]
```

**Example:** `if 1 > 2: 42 else: 7` emits:
```
lit(1) lit(2) op_gt kw_if op_colon_assoc
grp_indent lit(42) grp_dedent
kw_else op_colon_assoc
grp_indent lit(7) grp_dedent
```

A standalone `else` without a preceding `if` is an error.

---

## Functions

### Declaration

Functions are declared with `fn`, a name, parenthesized parameters, a colon, and a body expression. The function name is declared in the enclosing scope. Parameters are declared in a new `function` scope that is closed after parsing the body.

**Syntax:**
```
fn name(param1, param2): body_expression
```

**parsedQ layout:**
```
name_decl kw_fn[body_length, metadata] param1_decl param2_decl ... [body tokens...]
```

The `kw_fn` header token uses the `Data.FnHeader` layout:
- `body_length: u32` — token count of everything that follows the header up to and including the final body token. Used by codegen to skip over the template.
- `metadata: u16` — `(isLazy << 15) | paramCount`; bit 15 flags lazy functions, bits 0–14 hold the parameter count.

**Adjacency invariant:** `kw_fn` is always at `parsedQ[declaration_index + 1]` where `declaration_index` is the function name's identifier token. Nothing is emitted between the two. Inline expansion relies on this to read the header from the name's declaration site.

**Example:** `fn add(a, b): a + b` emits:
```
decl(add) kw_fn[body_length=5, metadata=2] decl(a) decl(b) ref(a) ref(b) op_add
```

### Eager vs Lazy

Parameters use naming convention to determine evaluation strategy:
- **Lowercase** identifiers (`identifier` kind) → eager (evaluated before expansion)
- **ALL_CAPS** `const_identifier` kind → lazy (a splice point where the operand is parsed during expansion)

A function with exactly one eager and one lazy parameter is a **lazy function** (a fexpr-style macro); all other shapes are eager. The `kw_fn` handler detects lazy functions by counting param kinds during the parameter loop and setting bit 15 of `metadata` if the test passes.

### Splice Flag

For lazy functions, the `kw_fn` handler locates the single use of the lazy parameter in the body via the resolution use-chain: starting from the lazy param's declaration, `next_offset` points directly at its first (and only) use. The handler asserts the use exists (`next_offset != 0`) and that no further uses exist (the use's own `next_offset == 0`), then sets `flags.splice = true` on that token. The splice flag is the sole dispatch signal during body walking.

This use-chain-driven detection is why `next_offset` exists on identifier tokens — it turns splice-point detection into O(1).

---

## Inline Expansion (`opIdentifierInfix`)

User-defined infix operators are backed by two-parameter functions. When the parser encounters an `op_identifier` (or `const_identifier`) in infix position, the function body stored in `parsedQ` is expanded inline at the call site. The expansion produces standard postfix tokens with correct `prev_offset`/`next_offset` chains against the current scope, so codegen treats expanded code identically to hand-written code — there is no runtime call.

This is **fexpr-style macro expansion**: for lazy operators, the right operand is captured as unevaluated syntax and spliced into the body template. The left operand is always eager (already in `parsedQ` by the time the infix handler runs).

**Why no new data structures:** the whole macro machinery piggy-backs on what is already in `parsedQ`. The body template is the function definition itself; the splice point is a single flag bit; identifier re-resolution uses the existing `resolution.resolve()`. Expansion uses 24 bytes of stack-local state. No heap allocation, no separate symbol table entry for the macro, no AST.

### Input to expansion

- **Left operand:** already emitted to `parsedQ` before the infix handler ran. Its result sits on top of the evaluation stack.
- **Right operand:** unconsumed tokens in `syntaxQ` after the `op_identifier`. For eager functions they are parsed immediately; for lazy functions they are parsed when the walk hits the splice point.
- **Body template:** a read-only region of `parsedQ` produced by `kw_fn` at definition time. Contains postfix tokens; for lazy functions, exactly one token has `flags.splice = 1`.

### Step 1 — Resolve and dispatch

Call `resolution.resolve()` on the operator token. If `prev_offset == UNDECLARED_SENTINEL`, no declaration exists — fall back to ordinary `binaryOp` semantics (`parse(power+1)`, emit the token). Same fallback applies if the resolved declaration is not immediately followed by a `kw_fn` header (the adjacency invariant lets this be a single index check).

Otherwise, read the `kw_fn` header at `declIndex + 1`:
- `body_length` from `fn_header.body_length`
- `metadata` from `fn_header.metadata`; extract `isLazy = (metadata & 0x8000) != 0` and `paramCount = metadata & 0xFF`
- Assert `paramCount == 2` (only two-parameter infix operators are wired)

Parameter declarations are at `declIndex + 2` and `declIndex + 3`; eager vs lazy is distinguished by `kind` (`identifier` = eager, `const_identifier` = lazy).

### Step 2 — Bind parameters

The macro runs inside the enclosing scope (no new scope is pushed — the inline bindings are ordinary declarations that `endScope`'s shadow-bitset revert on the *enclosing* scope's end). Before introducing a binding, the handler saves `declarations[symbolId]` so it can be restored after expansion; after saving, it calls `resolution.declare()` and sets `flags.splice = true` on the resulting token.

The `splice` flag on the synthesized parameter declaration tells codegen to bind the declaration to the stack-top value (the preceding operand already in `parsedQ`) instead of allocating a fresh register. That is how the declaration "captures" an expression result without any copy or move.

**Lazy path (`isLazy == true`):** only the eager parameter is bound here. The lazy operand stays unconsumed in `syntaxQ` until the body walk hits the splice point.

1. Save `declarations[eagerSymbolId]`.
2. Declare the eager parameter at the current `parsedQ` position with `flags.splice = true`. Emit.
3. `walkBodyTemplate(bodyStart, bodyEnd, opToken)`.
4. Restore `declarations[eagerSymbolId]`.

**Eager path (`isLazy == false`):** both operands are fully evaluated and bound as locals before the body walks.

1. Save `declarations[sym1]` and `declarations[sym2]`.
2. Declare param1 (bound to the already-emitted left operand) with `flags.splice = true`. Emit.
3. `parse(power(opToken) + 1)` — consume and evaluate the right operand, leaving its postfix tokens in `parsedQ`.
4. Declare param2 (bound to that right operand) with `flags.splice = true`. Emit.
5. `walkBodyTemplate(bodyStart, bodyEnd, opToken)`.
6. Restore both `declarations[]` entries.

### Step 3 — Walk the body template (`walkBodyTemplate`)

Iterate body tokens `[bodyStart, bodyEnd]` inclusive. `bodyStart = declIndex + 2 + paramCount`, `bodyEnd = declIndex + 1 + body_length`. For each template token:

| Condition | Action |
|-----------|--------|
| `flags.splice == 1` | **Splice (lazy only)**: call `parse(power(opToken) + 1)` to consume the right operand from `syntaxQ`. The Pratt parser emits the operand's postfix tokens directly into `parsedQ` at the current write position. Do not copy this template token. |
| `kind == identifier or const_identifier` | **Re-resolve**: recover the `symbol_id` (from the declaration token if it's a decl, else via a one-hop through `prev_offset` on the template ref to its original declaration), build a fresh identifier token, and call `resolution.resolve()` against the current scope. Emit. |
| `kind == grp_indent` | **Indent fixup**: emit with `index = 0` (placeholder) and the current `scopeId`. Push the emit index onto a stack-local fixup stack (capacity 4). |
| `kind == grp_dedent` | **Dedent fixup**: pop the fixup stack, emit `grp_dedent` with `index = indentIdx`, then patch the earlier `grp_indent` token's `index` to point at the current position. |
| Otherwise | **Copy**: emit the 64-bit token as-is. Includes `kw_if`, `kw_else`, `op_colon_assoc`, `call_identifier`, literals, operators. |

Re-resolution is what lets eager param references (which appear as ordinary identifier tokens in the template) bind to the inline declaration emitted in Step 2, while other identifiers in the body (closed-over module-level names, for instance) resolve against the call site. All of this reuses the single-pass resolution mechanics — no second symbol-table.

All walking state is stack-local: `[4]u32` fixup stack plus a `u8` depth counter. `parsedQ.list.items[i]` is re-read each iteration because `emit` may reallocate the backing slice.

### Example

Definition: `fn OR(first, SECOND): if bool(first): first else: SECOND`
Call site: `x OR y + 1`

The left operand `x` is already in `parsedQ`. The parser encounters `op_identifier("OR")` with binding power Comparison (60).

- Resolve "OR" → declaration at N. Read `kw_fn` at N+1: `body_length = 12`, `isLazy = 1`, `paramCount = 2`.
- Read N+2 (`identifier "first"`) → `eagerSymbolId = S_first`. Read N+3 (`const_identifier "SECOND"`) → `lazySymbolId = S_second`.
- Save `declarations[S_first]`. Declare `first` at the current position with `flags.splice = 1`. Emit.
- Walk body N+4 … N+15:
  - `identifier("first")` → re-resolve → points to the just-emitted decl.
  - `call_identifier("bool")`, `kw_if` → copy.
  - `grp_indent` → placeholder; push fixup.
  - `identifier("first")` → re-resolve.
  - `grp_dedent` → patch indent.
  - `kw_else`, `op_colon_assoc`, `grp_indent` → copy / fixup.
  - `const_identifier("SECOND")` with `flags.splice = 1` → **splice**: `parse(60)` from `syntaxQ` consumes `y + 1` and emits `identifier(y), lit_number(1), op_add`.
  - `grp_dedent` → patch indent.
- Restore `declarations[S_first]`.

Result (call site):
```
identifier(x)
decl(first, splice=1)       // binds stack-top
identifier(first) → decl
call_bool
kw_if
  grp_indent
  identifier(first) → decl
  grp_dedent
kw_else
  grp_indent
  identifier(y)             // spliced right operand
  lit_number(1)
  op_add
  grp_dedent
```

Postfix-valid, correct identifier offsets against the call site, correct indent/dedent pairs. Codegen processes this like any other expression.

### Notes and constraints

- **Lazy invariant:** exactly one token in the body has `flags.splice = 1`, enforced at definition time. Zero or two+ uses of the lazy parameter is a parse error.
- **Splice-flag overload at the call site:** the flag is also set on the synthesized parameter declarations emitted during expansion. That is a distinct use from the body-template splice and is read by codegen, not by the walker.
- **No expansion-site scope:** the handler does not push a scope. It saves/restores `declarations[]` for exactly the parameter symbols. This is simpler than the earlier spec draft and avoids edge cases around `endScope` running on a scope the handler itself created.
- **Right-operand binding power:** the splice calls `parse(power(opToken) + 1)`. With Comparison (60), `a OR b + 1` absorbs the whole `b + 1` (Additive is higher), which matches user expectation for "OR" binding less tightly than `+`.
- **No runtime call** — the expansion *is* the call. Function bodies in `parsedQ` are templates; codegen skips them using `body_length`.
- **Dead code:** if a function is only ever used as an infix macro, its body tokens are dead code at the definition site. Codegen's skip-over handles this; a dead-code-elimination pass is deferred.

---

## Symbol Resolution

Resolution is performed inline by the `Resolution` module. No separate pass. See [Resolution Spec](resolution-spec.md) for full details.

### Token Encoding (identifiers in `parsedQ`)

Identifiers use `Data.Ident` (48 bits):

```
 63       48 47                    32 31                    16 15        8 7         0
┌───────────┬────────────────────────┬────────────────────────┬───────────┬──────────┐
│next_off 16│      prev_off 16       │     symbol_id (16)     │ kind (8)  │ flags(8) │
└───────────┴────────────────────────┴────────────────────────┴───────────┴──────────┘
  symbol_id  = interned name
  prev_offset = signed i16 to previous chain link
                  declaration (first decl): 0
                  declaration (shadowing): offset to outer chain tail
                  reference: offset to the declaration (always negative, one hop)
  next_offset = signed i16 to next use in chain (0 = last)
  flags.declaration = 1 at declaration sites
  flags.splice      = 1 at inline-expansion splice points (lazy body + synthesized param decls)
```

Every identifier token sits in a **doubly-linked use-def chain**: you can walk backward from any use to its declaration in one hop, or forward from the declaration through all resolved uses via `next_offset`. The forward walk is what `kw_fn` uses to locate a lazy parameter's single use when stamping the splice flag.

### Declarations

Triggered when `assignOp` fires or within `kwFn` for function names and parameters. The handler calls `resolution.declare(index, lastToken)`, which:
- Sets `flags.declaration = 1` on the emitted token.
- Stores `prev_offset = 0` if this is the first declaration of the symbol, or the offset to the outer chain tail if shadowing (tracked in a bitset for cheap revert on `endScope`).
- Updates `declarations[symbol_id] = index` (index becomes the new chain tail).
- Walks and patches any pending forward references (only in `module`/`object` scopes).

### References

`resolution.resolve(index, token)` is called for every non-declaration identifier:
- If a declaration exists: `prev_offset` = offset to the declaration (one-hop, derived from the tail). Patches the previous tail's `next_offset` to point at this reference.
- If no declaration exists: `prev_offset` is chained through `unresolved[symbol_id]` so a future declaration can resolve it forward.

### Scope Types

| Scope Type | Forward Declarations | Used For |
|------------|---------------------|---------|
| `base` | No | Root scope at file start (always on stack) |
| `module` | Yes | Module-level declarations |
| `object` | Yes | Object/type body |
| `function` | No | Function body |
| `block` | No | Indent blocks, if/for bodies |

---

## Token Layout in `parsedQ`

All tokens are 64-bit packed structs:

```zig
Token = packed struct(u64) {
    flags: Flags,  //  8 bits
    kind: Kind,    //  8 bits
    data: Data,    // 48 bits (packed union)
}
```

`Data` is a `packed union` of equal-width (48-bit) variants. The parser picks the variant by context; the raw bits can always be read interchangeably via `Data.raw: u48`.

| Variant | Use | Layout |
|---------|-----|--------|
| `Ident` | Identifiers | `symbol_id: u16`, `prev_offset: u16`, `next_offset: u16` |
| `Literal` | `lit_number`, `lit_string` | `value: u32`, `length: u16` |
| `FnHeader` | `kw_fn` in `parsedQ` | `body_length: u32`, `metadata: u16` |
| `Scope` | `grp_indent`, `grp_dedent` | `index: u32`, `scope_id: u16` |
| `Newline` | Syntax-queue `sep_newline` | `aux_index: u32`, `prev_offset: u16` |
| `Aux` | Aux tokens | `position: u32`, `length: u16` |
| `Sequence` | Grouping/separators | `prev_group: u16`, `prev_sep: u16`, `next_sep: u16` |

---

## Current Limitations and TODOs

| Area | Status |
|------|--------|
| Unary ops (`NOT`, unary `-`) | `unaryOp` handler exists; parsing works but lacks full semantic wiring |
| `if`/`else` | Implemented. Nested `elif` requires nesting `if` inside `else` — no dedicated `elif` token |
| `fn` declarations | Implemented. Lazy detection via use-chain (next_offset); splice flag set from the lazy param's single use |
| Inline expansion | Both eager and lazy paths implemented in `opIdentifierInfix`. Fixed to 2-parameter functions; asserts on `paramCount == 2` |
| Walk fixup stack | `[4]u32` — hard limit of 4 nested indent levels in a body template |
| No expansion-site scope | Expansion uses save/restore on `declarations[]` instead of push/pop scope. Simpler, but revisit if macros ever need their own lexical scope for locals |
| Recursion guard | Lazy macro body calling itself as `op_identifier` would infinite-loop the parser. Not guarded |
| `for` loops | Token kind defined; no handler registered |
| Paren sub-expressions `(expr)` | `groupParen` handles it as prefix; commas inside not yet handled |
| `type_identifier` | Not in grammar table; currently unhandled |
| `TBL_PRECEDENCE_FLUSH` | Defined in `token.zig` (shunting-yard artifact); not used by the Pratt parser |
| Error recovery | Parse errors bubble up as Zig errors; no continuation |
| `offsetQ` correctness | `emit` offset calculation has a TODO — may not produce correct source mapping |
