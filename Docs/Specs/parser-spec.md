# Parser Spec

## Overview

The parser takes the dual token streams from the lexer and produces a **postfix-ordered parsed queue** suitable for direct bytecode emission. It is a hybrid state-machine / operator-precedence parser using compile-time lookup tables for precedence resolution.

**Key properties:**
- Single-pass, no backtracking, no lookahead beyond one token
- Direct-threaded style: each state function processes one token and tail-calls the next state
- No heap-allocated AST nodes — output is a flat postfix token queue
- Symbol resolution is interleaved with parsing (no separate pass)

---

## Input

**Token Stream:**
- Consumes the syntax queue (`syntaxQ`) produced by the lexer
- Tokens arrive in-order; each is consumed exactly once via `pop()`
- Auxiliary queue (`auxQ`) is available but currently unused by the parser
- Stream terminates with `aux_stream_end` sentinel token (kind = 255)

**Assumptions from Lexer:**
- Multi-token keywords are combined into a single token
- Unary minus is normalized into negative literals or negative multiplication (no ambiguous `-`)
- `call_identifier` tokens guarantee the next token is `grp_open_paren`
- Indentation is already converted to `grp_indent` / `grp_dedent` tokens
- Lines are never split across chunks

---

## Output

### Parsed Queue (`parsedQ`)

The output is stored in **postfix order** — all operands appear before their operator. This structure:
- Eliminates the need for explicit child pointers
- Matches dependency order and evaluation order
- Enables direct bytecode emission without a second pass

Example: `1 + 2 * 3` → `[AUX_STREAM_START, 1, 2, 3, *, +]`

`parsedQ` always begins with `aux_stream_start` (index 0) so no valid declaration ever holds index 0. Index 0 is used as a null sentinel by symbol resolution.

### Offset Queue (`offsetQ`)

A parallel `u16` queue: for each token in `parsedQ`, stores the distance back to its corresponding position in `syntaxQ`. Enables mapping parsed tokens back to source positions for error reporting and IDE features.

---

## Operator Stack

The parser maintains an explicit operator stack (`opStack`) using the shunting-yard algorithm. Each entry is a `ParseNode`:

```
ParseNode {
    token: Token
    index: usize   // syntaxQ index at the time of push
}
```

- **Push:** Flush higher/equal-precedence operators first (see Precedence), then append
- **Pop:** Emit token to `parsedQ` with its recorded `syntaxQ` offset

---

## Token Categories (Bitset Membership)

```
LITERALS        lit_string, lit_number, lit_bool, lit_null
IDENTIFIER      identifier, const_identifier, call_identifier
BINARY_OPS      All infix operators: arithmetic, comparison, logical,
                assignment, member access, choice, colon, in/is/as,
                op_identifier (user-defined infix)
UNARY_OPS       op_not, op_unary_minus
SEPARATORS      sep_comma, sep_newline
GROUP_START     grp_indent, grp_open_paren, grp_open_brace, grp_open_bracket
GROUP_END       grp_close_brace, grp_close_paren, grp_close_bracket
KEYWORD_START   kw_if, kw_for, kw_fn, kw_else
PAREN_START     grp_open_paren
```

---

## Operator Precedence (Highest to Lowest)

| Level | Operators | Notes |
|-------|-----------|-------|
| 1 | `.` | Member access |
| 2 | `NOT`, unary `-` | Unary prefix |
| 3 | `^` | Exponentiation |
| 4 | `*`, `/`, `%` | Multiplicative |
| 5 | `+`, `-` | Additive |
| 6 | `>=`, `<=`, `<`, `>` | Relational comparison |
| 7 | `==`, `!=` | Equality |
| 8 | `AND` | Logical conjunction |
| 9 | `OR` | Logical disjunction |
| 10 | `=`, `+=`, `-=`, `*=`, `/=` | Assignment |
| 11 (lowest) | `,`, newline, `:` | Separators / association |

**Right-associative** (do not flush self): `NOT`, `^`, `:`, `=`, `+=`, `-=`, `*=`, `/=`

All other operators are **left-associative**.

### Precedence Flush Table

`TBL_PRECEDENCE_FLUSH` is a compile-time 64-entry array of `BitSet64`. For a given operator at index `k`, `TBL_PRECEDENCE_FLUSH[k]` is the set of operators with equal-or-higher precedence that should be flushed from the opStack before pushing `k`. Right-associative operators exclude themselves from their own flush set.

This collapses the precedence comparison + associativity check into a single bitset lookup per operator push.

---

## State Machine

### States

```
initial_state    — Expecting an expression start (operand or prefix)
expect_binary    — Saw an operand; expecting binary operator, separator, or group close
expect_unary     — Saw a binary operator; expecting right-hand operand
```

All state functions are direct-threaded: they process one token and tail-call the next state with no return value (except on stream-end).

---

### `initial_state`

Entry point at file start. Re-entered after separators, group opens, and dedent closes.

| Token | Action | Next State |
|-------|--------|------------|
| Literal | Emit to `parsedQ` | `expect_binary` |
| `identifier`, `const_identifier` | Resolve symbol; emit resolved token | `expect_binary` |
| `call_identifier` | Pop next token (assert `grp_open_paren`); push `(` onto opStack; push identifier onto opStack | `initial_state` |
| `sep_newline` | Skip | `initial_state` |
| `grp_indent` | Emit `grp_indent` marker to `parsedQ`; start scope; push `grp_dedent` sentinel onto opStack | `initial_state` |
| `grp_dedent` | Flush opStack until matching `grp_dedent`; end scope | `initial_state` |
| `grp_open_paren` | (TODO: unary grouping) | — |
| Unary ops | (TODO) | — |
| `aux_stream_end` | Return | — |
| Other | Error: invalid token | — |

---

### `expect_binary`

Entered after an operand has been emitted to `parsedQ`.

| Token | Action | Next State |
|-------|--------|------------|
| Other binary op | Precedence-flush opStack; push operator | `expect_unary` |
| `op_assign_eq` (`=`) | Retroactively declare LHS: set `declaration` flag on last `parsedQ` token; push `=` | `expect_unary` |
| `op_colon_assoc` (`:`) | Push `:` onto opStack (with flush); flush opStack until keyword-start | `initial_state` |
| Separator (`,`, `sep_newline`) | Flush opStack for separator precedence | `initial_state` |
| Group start (`(`, `[`, `{`) | Push onto opStack | `initial_state` |
| Group end (`)`, `]`, `}`) | Flush until matching group-open; pop and validate group-open from `parsedQ`; remove from `offsetQ` | `initial_state` |
| `grp_indent` | Error: unexpected indent | — |
| `aux_stream_end` | Return | — |
| Other | Error: invalid token | — |

---

### `expect_unary`

Entered after a binary operator. Expecting a right-hand operand, possibly with unary prefix.

| Token | Action | Next State |
|-------|--------|------------|
| Literal | Emit to `parsedQ` | `expect_binary` |
| `identifier`, `const_identifier` | Resolve symbol; emit resolved token | `expect_binary` |
| `grp_open_paren` | (TODO: sub-expression grouping) | — |
| Keyword start | (TODO: keyword sub-expression) | — |
| Unary ops | (TODO) | — |
| `aux_stream_end` | Return | — |
| Other | Error: invalid token | — |

---

### End-of-Stream

After `initial_state` returns, the main `parse()` function flushes all remaining operators from `opStack` to `parsedQ`. Any unmatched group-start tokens remaining on the stack indicate a compilation error (unclosed grouping).

---

## Operator Stack Flush Operations

### `flushOpStack(token)`

Before pushing a new operator, look up `TBL_PRECEDENCE_FLUSH[token.kind]` and pop+emit all operators from the stack top whose kind is set in that bitset.

### `flushUntil(bitset)`

Pop and emit operators until an operator matching the bitset is found. Emit that matching operator too, then stop. Used for:
- **Group close:** flush until matching group-open kind
- **Colon:** flush until keyword-start
- **Dedent:** flush until `grp_dedent` sentinel

If an unmatched `GROUP_START` token is encountered before the target, it is a compilation error.

### `flushUntilToken(kind)`

Convenience wrapper: constructs a single-token bitset and calls `flushUntil`.

---

## Grouping

### Parentheses, Brackets, Braces

- **Open** (`(`, `[`, `{`): Pushed onto opStack. Acts as a scope floor — operators below this point are not flushed by subsequent operators
- **Close** (`)`, `]`, `}`): `flushUntil(GROUP_START)` pops all operators down to the matching open. The group-open token is then popped from `parsedQ` and `offsetQ` (groups are structural fences, not emitted in the output). Mismatched open/close types produce a compilation error

### Indentation Blocks

`grp_indent` and `grp_dedent` are treated as a first-class grouping pair, equivalent to `{` / `}`.

**On `grp_indent`:**
1. Emit `grp_indent` token to `parsedQ` immediately as a block start marker
2. Push a `grp_dedent` sentinel onto opStack as the matching close marker
3. Call `resolution.startScope(block)`

The `grp_indent` in `parsedQ` stores the scope ID in `arg1`. Its `arg0` is patched when the scope closes to hold the scope's end index.

**On `grp_dedent`:**
1. `flushUntilToken(grp_dedent)` flushes pending operators and pops the sentinel
2. `resolution.endScope()` patches `parsedQ[scope.start].arg0 = end_index`

The `grp_indent` token in `parsedQ` thus encodes both endpoints: `arg0 = end_index`, `arg1 = scope_id`.

### Function Calls

The lexer emits `call_identifier` when an identifier is immediately followed by `(`, avoiding parser lookahead. On `call_identifier`:
1. Pop the next token from `syntaxQ` (asserted to be `grp_open_paren`)
2. Push `grp_open_paren` onto opStack
3. Push the `call_identifier` itself onto opStack above the paren

This produces a Lisp-style postfix layout where the function identifier precedes its arguments.

---

## Symbol Resolution

Symbol resolution is performed inline during parsing by the `Resolution` module. No separate pass is required.

### Declarations

A symbol becomes a declaration when the parser encounters `identifier = ...`. At that point:
- `resolution.declare()` is called with the index of the identifier already in `parsedQ`
- The identifier token is rewritten: `flags.declaration = true`, and `arg1` is set to a **signed i16 offset** to the previous declaration of the same name (`prev_decl_index - current_index`, a negative value, or 0 if this is the first)
- This forms a **linked list of declarations** for each symbol name, traversable by following offsets backward through `parsedQ`

### References

When an identifier is resolved outside of a declaration context:
- If a prior declaration exists: `arg1` = signed offset to it (`decl_index - ref_index`, negative)
- If no declaration exists yet (forward reference): `arg1` = 0 and the reference index is recorded in the `unresolved` table

### Forward Declarations

Forward references (use before declaration) are resolved lazily when the declaration is encountered:
- Only supported in `module` and `object` scope types — not in `function` or `block`
- On declaration, the unresolved linked list for that symbol is walked; every unresolved ref within the current scope is patched in `parsedQ` with the correct positive offset (`decl_index - ref_index`)

### Scope Types

| Scope Type | Forward Declarations | Used For |
|------------|---------------------|---------|
| `base` | No | Root scope at file start |
| `module` | Yes | Module-level declarations |
| `object` | Yes | Object/type body |
| `function` | No | Function body |
| `block` | No | if/for/indent block |

---

## Token Encoding in `parsedQ`

Most tokens carry the same 64-bit layout as the lexer output. Key differences after parsing:

### Resolved Identifiers

```
 63       48 47                    16 15        8 7         0
┌───────────┬────────────────────────┬───────────┬──────────┐
│offset (16)│    symbol index (32)   │ kind (8)  │ flags    │
└───────────┴────────────────────────┴───────────┴──────────┘
  offset = signed i16: declaration_index - this_index
           negative = backward ref to prior declaration
           positive = forward ref (patched when decl is seen)
           zero     = first declaration, or unresolved forward ref
  flags.declaration = 1 at declaration sites
```

### Scope Start (`grp_indent`)

```
 63       48 47                    16 15        8 7         0
┌───────────┬────────────────────────┬───────────┬──────────┐
│scope_id(16)│    end_index (32)     │grp_indent │ flags    │
└───────────┴────────────────────────┴───────────┴──────────┘
  end_index = parsedQ index of the closing scope boundary
              (patched by endScope when grp_dedent is seen)
  scope_id  = monotonically incrementing scope identifier
```

---

## Current Limitations and TODOs

| Area | Status |
|------|--------|
| Unary operators (`NOT`, unary `-`) | Recognized in bitsets; state handlers are stubs |
| Paren sub-expressions `(expr)` | Not yet implemented in `initial_state` / `expect_unary` |
| Keyword blocks (`if`, `else`, `for`, `fn`) | Token kinds defined; parser stubs only |
| `type_identifier` | Not included in `IDENTIFIER` bitset — currently unhandled |
| `op_identifier` (user-defined infix) | In `BINARY_OPS` bitset; no special handling |
| `op_colon_assoc` flush | `flushUntil(KEYWORD_START)` needs refinement as keyword handling develops |
| Error recovery | Parse errors log and return; no continuation |
| Const-folding | `popOp` has a TODO to fold literal operands at parse time |
| Separator metadata | `sepIndex`/`grpIndex` linked-list threading is commented out |
| Range operators (`..`, `...`) | Pending lexer implementation |
