# Parser Spec

## Overview

The parser takes the token stream from the lexer and produces a **postfix-ordered parsed queue** suitable for direct bytecode emission. It is a **recursive Pratt (top-down operator precedence) parser** using compile-time lookup tables for dispatch and precedence resolution.

**Key properties:**
- Single-pass, no backtracking, no lookahead beyond one token
- Recursive descent: each handler calls `parse(minBindingPower)` for sub-expressions
- No heap-allocated AST nodes — output is a flat postfix token queue
- Symbol resolution is interleaved with parsing (no separate pass)
- Call-site lowering and macro expansion are deferred to the IR stage (see `inline-expansion-spec.md` for the paused design)

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
| `callExpr` | `call_identifier` | Emit paren group chain (`grp_open_paren`, args separated by `sep_comma`, `grp_close_paren`); emit identifier afterwards |
| `unaryOp` | `op_not`, `op_unary_minus` | `parse(Unary)`; emit operator (postfix) |
| `skipNewLine` | `sep_newline` | `parse(None)` — newline at expression start is skipped |
| `groupParen` | `grp_open_paren` | Emit `grp_open_paren`; loop `parse(Separator)` + emit `sep_comma` until `grp_close_paren`; emit `grp_close_paren` |
| `groupBracket` | `grp_open_bracket` | Same shape as `groupParen` with bracket tokens |
| `groupBrace` | `grp_open_brace` | Same shape as `groupParen` with brace tokens |
| `indentBlock` | `grp_indent` | See Indentation Blocks below |
| `kwIf` | `kw_if` | See Conditionals below |
| `kwElse` | `kw_else` | No-op stub; a standalone `else` is silently swallowed (no error yet) |

`kw_fn` has no grammar entry — it falls through the default (`none` / `literal`) and is emitted as a bare token. Function declaration parsing is not yet wired (see Functions below).

### Infix Handlers

| Handler | Tokens | Behavior |
|---------|--------|----------|
| `binaryOp` | Most binary ops | `parse(power + 1)` (left-assoc); emit operator |
| `binaryRightAssocOp` | `op_pow` | `parse(power)` (right-assoc); emit operator |
| `assignOp` | `op_assign_eq`, `op_plus_eq`, `op_minus_eq`, `op_mul_eq`, `op_div_eq` | Retroactively declare LHS; `parse(Assign)`; emit operator |
| `separator` | `sep_comma`, `sep_newline` (infix) | `parse(Separator)` — continues expression after separator |

`colonAssocOp` exists as a handler (`parse(Separator)` + emit) but has no grammar entry; `op_colon_assoc` is currently consumed directly by `kwIf`. `const_identifier` and `op_identifier` only have prefix entries — there is no infix handler that turns them into user-defined binary operators yet.

---

## Grouping Chain Emission

Every `(…)`, `[…]`, and `{…}` group in `parsedQ` is a doubly-linked chain
through the opener, each top-level `sep_comma`, and the matching close. All
three nodes share the same `Data.GroupLink` layout:

```zig
GroupLink = packed struct(u48) {
    prev_offset: i16, // signed offset to the previous link in the chain
    next_offset: i16, // signed offset to the next link
    iter_offset: i16, // reserved; currently unused
}
```

There are no separate `GroupOpen` / `GroupSep` / `GroupClose` variants and no
`arg_cnt` / `close_offset` / `open_offset` fields. Linkage is built by a
single helper, `emitChainedSep(prev_sep_idx, sep_token)`:

1. Write `prev_offset` on the new token = signed offset from the new emit
   index back to `prev_sep_idx`.
2. Emit the token.
3. Patch the previous link's `next_offset` to point forward at the new token.

`groupDelim(open_kind, close_kind)` is the shared loop used by `groupParen`,
`groupBracket`, and `groupBrace`:

1. Emit the open token (no `emitChainedSep`; it has no predecessor yet).
2. If the next syntax token isn't the close, loop: `parse(Separator)`; if the
   next token is `sep_comma`, pop it and call `emitChainedSep` with a fresh
   `sep_comma` token; otherwise break.
3. Pop the close token from `syntaxQ` (asserted to match) and call
   `emitChainedSep` for the close.

`callExpr` pops the lexer-guaranteed `grp_open_paren`, runs `groupDelim`, then
emits the `call_identifier` last (counted as `ir_use` for IR sizing).

Top-level commas outside any group still dispatch to the ordinary `separator`
infix handler.

There is no explicit grouping stack and no fixed depth limit — nesting is
handled by recursion through `parse()`. The opener's own `prev_offset` is
never patched and the `iter_offset` field is reserved for future use.

## Indentation Blocks

`indentBlock` is the prefix handler for `grp_indent`:

1. Capture current `scopeId` and `startIdx` (`parsedQ` length).
2. Emit `grp_indent` with `Data.Scope.index = 0` (patched later), `scope_id = scopeId`.
3. Call `resolution.startScope({ start = startIdx, scopeType = .block })` — pushes the scope and increments `scopeId`.
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

**Status: not yet wired in the parser.** `kw_fn` is emitted by the lexer but
has no entry in the parser grammar table, so it falls through the default
`literal` handler and is emitted bare (with `Data.raw = 0`, i.e.
`body_length = 0` if read as `FnHeader`). Function names, parameter lists,
and bodies are not parsed into the structured layout described here.

Downstream, `codegen.zig` already special-cases `kw_fn` by reading
`data.fn_header.body_length` and skipping that many tokens — so once the
parser is taught to emit the header it will slot in without codegen
changes. The intended shape and conventions are:

**Syntax:**
```
fn name(param1, param2): body_expression
```

**Intended `parsedQ` layout:**
```
name_decl kw_fn[body_length, body_offset] group_open param1_decl [sep_comma param_decl]* group_close [body tokens...]
```

- `body_length: u32` — tokens to skip past the header (codegen jump-over).
- `body_offset: u16` — distance from the header to the first body token (one past the matching `grp_close_paren`).

Call-site lowering (ordinary calls and fexpr-style macro expansion) is
deferred to a separate IR stage between the parser and codegen. The
historical design is preserved in `inline-expansion-spec.md` as a
reference. Calls today pass through to codegen's syscall stub and produce
incorrect machine code until the IR lands.

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
```

Every identifier token sits in a **doubly-linked use-def chain**: you can walk backward from any use to its declaration in one hop, or forward from the declaration through all resolved uses via `next_offset`.

### Declarations

Currently triggered only when `assignOp` fires (the LHS identifier is reclassified as a declaration in-place). Once function parsing lands, parameter and function-name declarations will also flow through `resolution.declare`. The handler calls `resolution.declare(index, lastToken)`, which:
- Sets `flags.declaration = 1` on the emitted token.
- Stores `prev_offset = 0` if this is the first declaration of the symbol, or the offset to the outer chain tail if shadowing.
- Updates `declarations[symbol_id] = index` (index becomes the new chain tail).
- Walks and patches any pending forward references (only in `module`/`object` scopes).

Shadow reversion on `endScope` is described in the spec but not yet active in code — see Resolution Spec.

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
| `FnHeader` | `kw_fn` (intended; not yet emitted by parser) | `body_length: u32`, `body_offset: u16` |
| `Scope` | `grp_indent`, `grp_dedent` | `index: u32`, `scope_id: u16` |
| `Newline` | Syntax-queue `sep_newline` | `aux_index: u32`, `prev_offset: u16` |
| `Aux` | Aux tokens | `position: u32`, `length: u16` |
| `GroupLink` | All group endpoints — opens, `sep_comma` inside a group, and closes | `prev_offset: i16`, `next_offset: i16`, `iter_offset: i16` (reserved) |
| `RegAlloc` / `RegLiteral` | Post-codegen register-assigned forms (`op_load`, `op_store`, literals after register allocation) | three u16 / u32+u16 register-id fields |

---

## Current Limitations and TODOs

| Area | Status |
|------|--------|
| Unary ops (`NOT`, unary `-`) | `unaryOp` handler exists; parsing works but lacks full semantic wiring |
| `if`/`else` | Implemented. `kwElse` standalone is a no-op stub (does not error). Nested `elif` requires nesting `if` inside `else` |
| `fn` declarations | **Not wired in the parser.** No grammar entry for `kw_fn`; token is passed through as a literal with empty `FnHeader`. Codegen knows how to skip a populated header but the parser doesn't emit one |
| `op_colon_assoc` | `colonAssocOp` handler exists but is not registered in the grammar table; `kwIf` consumes the colon directly |
| `op_identifier` / `const_identifier` infix | No infix handler — user-defined infix operators aren't recognized in expressions yet |
| Call lowering / macro expansion | Deferred to the IR stage. Calls currently pass through to codegen's syscall stub and produce incorrect machine code until the IR lands |
| `for` loops | Token kind defined; no handler registered |
| Paren sub-expressions `(expr)` | `groupParen` handles it as prefix |
| `type_identifier` | Not in grammar table; currently unhandled |
| `Call` binding power | Defined (120) but no token uses it |
| `TBL_PRECEDENCE_FLUSH` | Defined in `token.zig` (shunting-yard artifact); not used by the Pratt parser |
| Error recovery | Parse errors bubble up as Zig errors; no continuation |
| `offsetQ` correctness | `emit` offset calculation has a TODO — may not produce correct source mapping |
