# Parser Spec

## Overview

The parser takes the token stream from the lexer and produces a **postfix-ordered parsed queue** suitable for direct bytecode emission. It is a **recursive Pratt (top-down operator precedence) parser** using compile-time lookup tables for dispatch and precedence resolution.

**Key properties:**
- Single-pass, no backtracking, no lookahead beyond one token
- Recursive descent: each handler calls `parse(minBindingPower)` for sub-expressions
- No heap-allocated AST nodes — output is a flat postfix token queue
- Symbol resolution is interleaved with parsing (no separate pass)

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
Comparison   = 60   (< > <= >= in is as op_identifier)
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
| `opIdentifierInfix` | `const_identifier`, `op_identifier` | See Function Expansion below |

---

## Indentation Blocks

`indentBlock` is the prefix handler for `grp_indent`:

1. Capture current `scopeId` and `startIdx` (`parsedQ` length)
2. Emit `grp_indent` token to `parsedQ` (with `scopeId` in `arg1`; `arg0` is patched later)
3. Call `resolution.startScope(.block)` — pushes scope onto scope stack, increments `scopeId`
4. `parse(None)` — consumes the indented body
5. Pop `grp_dedent` from `syntaxQ` if present
6. Emit `grp_dedent` token (with `startIdx` in `arg0`, `scopeId` in `arg1`)
7. Call `resolution.endScope(end_index)` — patches `parsedQ[startIdx].arg0 = end_index`

The `grp_indent` token in `parsedQ` thus encodes: `arg0 = end_index` (patched at close), `arg1 = scope_id`.

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
name_decl kw_fn[bodyLength, metadata] param1_decl param2_decl ... [body tokens...]
```

The `kw_fn` header token encodes:
- `arg0` = body length (token count)
- `arg1` = `(isLazy << 15) | paramCount` — bit 15 flags lazy functions, bits 0-14 hold parameter count

**Example:** `fn add(a, b): a + b` emits:
```
decl(add) kw_fn[bodyLen=5, params=2] decl(a) decl(b) ref(a) ref(b) op_add
```

### Eager vs Lazy

Parameters use naming convention to determine evaluation strategy:
- **Lowercase** identifiers → eager (evaluated before expansion)
- **ALL_CAPS** `const_identifier` → lazy (a splice point where the operand is parsed during expansion)

A function with exactly one eager and one lazy parameter is a **lazy function**. All other functions are eager.

### Inline Expansion

Functions are not called at runtime — they are **expanded inline** at the call site. When an infix identifier resolves to a function declaration, the parser:

1. Binds operands to parameter declarations (marked with `splice=true`)
2. Walks the function body template, re-resolving identifiers against the current scope
3. For lazy functions, splice points in the body trigger parsing of the right operand from `syntaxQ` at expansion time rather than pre-evaluating it

**Example:** `3 add 4` (where `add` is `fn add(a, b): a + b`) emits:
```
lit(3) decl(a,splice) lit(4) decl(b,splice) ref(a) ref(b) op_add
```

Codegen skips function declaration bodies using `bodyLength` — they serve only as templates.

---

## Symbol Resolution

Resolution is performed inline by the `Resolution` module. No separate pass. See [Resolution Spec](resolution-spec.md) for full details.

### Token Encoding (identifiers in `parsedQ`)

```
 63       48 47                    16 15        8 7         0
┌───────────┬────────────────────────┬───────────┬──────────┐
│ arg1 (16) │      arg0 (32)         │ kind (8)  │ flags(8) │
└───────────┴────────────────────────┴───────────┴──────────┘
  arg0 = symbol ID (from lexer normalization)
  arg1 = signed i16 offset to declaration:
         negative → backward ref to prior declaration
         positive → forward ref (patched when decl is seen)
         zero     → first declaration, or unresolved forward ref
  flags.declaration = 1 at declaration sites
```

### Declarations

Triggered when `assignOp` fires. The handler calls `resolution.declare(index, lastToken)` which:
- Rewrites the most recent `parsedQ` token with `flags.declaration = true`
- Sets `arg1` to a signed i16 offset to the previous declaration of the same symbol (`prevDecl - thisIndex`), or 0 if first
- Updates `declarations[symbolId] = thisIndex`
- Walks and patches any pending forward references (in `module`/`object` scopes only)

### References

`resolution.resolve(index, token)` is called for every non-declaration identifier:
- If a prior declaration exists: `arg1 = declarations[symbolId] - index` (negative)
- If none exists: `arg1 = 0`; index recorded in `unresolved[symbolId]` as head of unresolved chain

### Forward Declarations

Supported only in `module` and `object` scope types. When a declaration is encountered, `resolveForwardDeclarations` walks `unresolved[symbolId]` and patches each ref within the current scope's start index with the correct positive offset (`declarationIndex - refIndex`).

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
    aux:  Flags,  //  8 bits
    kind: Kind,   //  8 bits
    data: Data,   // 48 bits (union of Value, Split, Triple layouts)
}
```

The `Data.Value` layout used by identifiers and scope tokens:
```
arg0: u32  — symbol ID (identifiers) or end_index (grp_indent)
arg1: u16  — signed i16 offset (identifiers) or scope_id (grp_indent)
```

---

## Current Limitations and TODOs

| Area | Status |
|------|--------|
| Unary ops (`NOT`, unary `-`) | `unaryOp` handler exists; parsing works but lacks full semantic wiring |
| `if`/`else` | Implemented. Nested `elif` requires nesting `if` inside `else` — no dedicated `elif` token |
| `fn` declarations | Implemented. Inline expansion for eager and lazy functions |
| `for` loops | Token kind defined; no handler registered |
| Paren sub-expressions `(expr)` | `groupParen` handles it as prefix; commas inside not yet handled |
| `type_identifier` | Not in grammar table; currently unhandled |
| `TBL_PRECEDENCE_FLUSH` | Defined in `token.zig` (shunting-yard artifact); not used by the Pratt parser |
| Error recovery | Parse errors bubble up as Zig errors; no continuation |
| `offsetQ` correctness | `emit` offset calculation has a TODO — may not produce correct source mapping |
