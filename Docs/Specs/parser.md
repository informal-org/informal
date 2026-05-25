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
| `opIdentifierInfix` | `const_identifier`, `op_identifier` | Resolve the identifier-family infix operator; emit as a binary op (`parse(power+1)` + emit resolved token) |

---

## Grouping Chain Emission

Every `(…)`, `[…]`, and `{…}` group in `parsedQ` is a bidirectionally linked
chain of tokens: the opener, each top-level `sep_comma` between args, and the
matching close. Handlers emit tokens via three helpers:

- `emitGroupOpen(kind)`: push a stack frame with the emit index; emit a
  `group_open` token with placeholder `arg_cnt`, `next_sep`, `close_offset`.
- `emitGroupSep()`: patch the last link's `next_sep` to point at the new
  `sep_comma`; emit a `sep_comma` with `arg_idx` (1-based post of the
  preceding arg), `prev_sep` back to the last link, and zero `next_sep`.
- `emitGroupClose(kind)`: patch the last link's `next_sep` to point at the
  close; patch the opener's `arg_cnt` and `close_offset`; emit a
  `group_close` with `open_offset` and `prev_sep`.

A parser frame (`GroupFrame { open_idx, last_sep_idx, arg_cnt }`) is kept on
a fixed-size `[16]` stack; depth beyond 16 is a hard error. `arg_cnt` is
incremented on each separator and one more on close iff the group was
non-nullary (nullary is detected by seeing the close token as the first
emission after the open).

All three grouping handlers — `groupParen`, `groupBracket`, `groupBrace` —
share the same loop shape: emit open, conditionally parse at `Separator`
power, on top-level `,` pop and `emitGroupSep`, on close pop and
`emitGroupClose`. `callExpr` follows the same shape (after popping its
leading `grp_open_paren`) and then emits the trailing `call_identifier`.
`kwFn` uses the same helpers around its parameter list so definition-site
and call-site chains are structurally identical.

Top-level commas outside any group still dispatch to the ordinary
`separator` infix handler.

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
name_decl kw_fn[body_length, body_offset] group_open param1_decl [sep_comma param_decl]* group_close [body tokens...]
```

The parameter list is emitted as a grouping chain (see *Grouping Chain
Emission*).

The header token uses the `Data.FnHeader` layout:
- `body_length: u32` — token count of everything that follows the header up to and including the final body token. Used by codegen to skip over the body.
- `body_offset: u16` — distance from the header to the first body token (one past the matching `grp_close_paren`).

The header's **kind** is always `kw_fn`. Param kinds (`identifier` vs
`const_identifier`) are preserved at the declaration site so a later IR stage
can recover lazy-vs-eager status. Parameter count is not stored — derive it
by walking the param-list chain if needed.

**Adjacency invariant:** the header is always at `parsedQ[declaration_index + 1]` where `declaration_index` is the function name's identifier token. Nothing is emitted between the two.

**Example:** `fn add(a, b): a + b` emits:
```
decl(add) kw_fn[body_length=8, body_offset=6]
group_open decl(a) sep_comma(arg_idx=1) decl(b) group_close
ref(a) ref(b) op_add
```

Call-site lowering (ordinary calls and fexpr-style macro expansion) is
deferred to a new IR stage between the parser and codegen. The historical
design is preserved in `inline-expansion-spec.md` as a reference.

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

Every identifier token sits in a **doubly-linked use-def chain**: you can walk backward from any use to its declaration in one hop, or forward from the declaration through all resolved uses via `next_offset`. The forward walk is what `kwFn` uses to locate a lazy parameter's single use so it can rewrite that use's kind to `ident_splice`.

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
| `FnHeader` | `kw_fn`/`kw_lazy_fn` in `parsedQ` | `body_length: u32`, `body_offset: u16` |
| `Scope` | `grp_indent`, `grp_dedent` | `index: u32`, `scope_id: u16` |
| `Newline` | Syntax-queue `sep_newline` | `aux_index: u32`, `prev_offset: u16` |
| `Aux` | Aux tokens | `position: u32`, `length: u16` |
| `GroupOpen` | `grp_open_paren`, `grp_open_bracket`, `grp_open_brace` | `arg_cnt: u16`, `next_sep: u16` (to first sep or close), `close_offset: u16` (to matching close) |
| `GroupSep` | `sep_comma` (inside a group) | `arg_idx: u16`, `prev_sep: u16`, `next_sep: u16` |
| `GroupClose` | `grp_close_paren`, `grp_close_bracket`, `grp_close_brace` | `open_offset: u16`, `prev_sep: u16`, `_reserved: u16` |

---

## Current Limitations and TODOs

| Area | Status |
|------|--------|
| Unary ops (`NOT`, unary `-`) | `unaryOp` handler exists; parsing works but lacks full semantic wiring |
| `if`/`else` | Implemented. Nested `elif` requires nesting `if` inside `else` — no dedicated `elif` token |
| `fn` declarations | Implemented. Header kind is always `kw_fn`; param decls preserve their original kind (`identifier` / `const_identifier`) for later IR lowering |
| Call lowering / macro expansion | Deferred to the IR stage. Calls currently pass through to codegen's syscall stub and produce incorrect machine code until the IR lands |
| `for` loops | Token kind defined; no handler registered |
| Paren sub-expressions `(expr)` | `groupParen` handles it as prefix; commas inside not yet handled |
| `type_identifier` | Not in grammar table; currently unhandled |
| `TBL_PRECEDENCE_FLUSH` | Defined in `token.zig` (shunting-yard artifact); not used by the Pratt parser |
| Error recovery | Parse errors bubble up as Zig errors; no continuation |
| `offsetQ` correctness | `emit` offset calculation has a TODO — may not produce correct source mapping |
