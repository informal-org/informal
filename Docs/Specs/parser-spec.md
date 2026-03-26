# Parser Spec

## Input

**Token Stream:**
- Consumes the syntax queue (`syntaxQ`) produced by the lexer
- Tokens arrive in-order; each is consumed exactly once via `pop()`
- Auxiliary queue (`auxQ`) is available but currently unused by the parser
- Stream terminates with `aux_stream_end` sentinel token

**Assumptions from Lexer:**
- Multi-token keywords are combined into a single token
- Unary minus is normalized into negative literals or negative multiplication (no ambiguous `-`)
- `call_identifier` tokens guarantee the next token is `grp_open_paren`
- Indentation is already converted to `grp_indent` / `grp_dedent` tokens
- Lines are never split across chunks

---

## Output: Postfix Token Queue

### Parsed Queue (`parsedQ`)

The AST is stored in **postfix order** — all operands appear before their operator. This structure:
- Eliminates explicit child pointers
- Matches dependency/evaluation order
- Matches the order needed for bytecode emission

Example: `1 + 2 * 3` produces `[1, 2, 3, *, +]`

### Offset Queue (`offsetQ`)

For each token in `parsedQ`, stores a `u16` offset back to its position in the `syntaxQ`. Enables mapping parsed tokens back to source positions for error reporting and diagnostics.

### Stream Markers

- `parsedQ` begins with `aux_stream_start` as a sentinel so index 0 is never a valid declaration target

---

## Architecture

### Hybrid State-Machine / Operator-Precedence Parser

The parser is a **direct-threaded state machine** with an explicit operator stack for precedence handling. Each state function:
1. Pops one token from `syntaxQ`
2. Dispatches on token category (via bitset membership)
3. Emits operands to `parsedQ` or pushes operators onto `opStack`
4. Tail-calls the next state (no lookahead, no backtracking)

### Operator Stack (`opStack`)

An `ArrayList(ParseNode)` where each node pairs a `Token` with its `syntaxQ` index. Operators are pushed here and flushed to `parsedQ` according to precedence rules before lower-precedence operators are pushed.

### Symbol Resolution

Integrated single-pass resolution via the `Resolution` module:
- **References**: `resolution.resolve()` maps identifiers to their declaration
- **Declarations**: On `=`, the left-hand identifier is retroactively marked via `resolution.declare()`
- **Scoping**: `grp_indent` opens a new scope (`resolution.startScope`), `grp_dedent` closes it (`resolution.endScope`)

---

## Token Categories (Bitset Membership)

```
LITERALS        lit_string, lit_number, lit_bool, lit_null
IDENTIFIER      identifier, const_identifier, call_identifier
BINARY_OPS      All infix operators: arithmetic, comparison, logical,
                assignment, member access, choice, colon, in/is/as,
                op_identifier (user-defined)
UNARY_OPS       op_not, op_unary_minus
SEPARATORS      sep_comma, sep_newline
GROUP_START     grp_indent, grp_open_paren, grp_open_brace, grp_open_bracket
GROUP_END       grp_close_brace, grp_close_paren, grp_close_bracket
KEYWORD_START   kw_if, kw_for, kw_fn, kw_else
PAREN_START     grp_open_paren
```

---

## Operator Precedence (Highest to Lowest)

```
1.  .               Member access
2.  NOT  -          Unary operators
3.  ^               Exponentiation
4.  %  /  *         Multiplicative
5.  +  -            Additive
6.  >=  <=  <  >    Relational comparison
7.  ==  !=          Equality comparison
8.  AND             Logical conjunction
9.  OR              Logical disjunction
10. =  /=  -=  +=  *= Assignment
11. ,  \n  :        Separators / association
```

**Associativity:**
- **Right-associative:** `=`, `/=`, `-=`, `+=`, `*=`, `^`, `:`, `NOT`
- **Left-associative:** Everything else

### Precedence Flush Mechanism

`TBL_PRECEDENCE_FLUSH` is a compile-time 64-entry lookup table of bitsets. For a given operator, its entry encodes which operators on the stack have equal-or-higher precedence and should be flushed (popped to output) first. Right-associative operators exclude themselves from their own flush set.

---

## State Machine

### States

#### `initial_state` — Expecting a value or start of expression

Entry state. Also re-entered after separators, group opens, and dedents.

| Token Category | Action | Next State |
|---|---|---|
| **LITERAL** | Emit to `parsedQ` | `expect_binary` |
| **IDENTIFIER** | Resolve; emit to `parsedQ` | `expect_binary` |
| **call_identifier** | Pop next token (assert `(`); push `(` then call_id onto opStack | `initial_state` |
| **grp_indent** | Emit `grp_indent` to `parsedQ`; start scope; push `grp_dedent` onto opStack | `initial_state` |
| **grp_dedent** | Flush opStack until matching `grp_dedent`; end scope | `initial_state` |
| **sep_newline** | Skip | `initial_state` |
| **PAREN_START** | (Noted, currently prints debug) | — |
| **UNARY_OPS** | (Noted, currently prints debug) | — |
| **stream_end** | Return (parsing complete) | — |
| Other | Error: invalid token | — |

#### `expect_binary` — Have a left operand, expecting an operator

Entered after emitting a value (literal or identifier).

| Token Category | Action | Next State |
|---|---|---|
| **BINARY_OPS** (general) | Precedence-flush opStack; push operator | `expect_unary` |
| **op_assign_eq** (`=`) | Retroactively declare LHS identifier; push `=` | `expect_unary` |
| **op_colon_assoc** (`:`) | Push `:`; flush until keyword | `initial_state` |
| **SEPARATORS** | Flush opStack for separator precedence | `initial_state` |
| **GROUP_START** (not indent) | Push group-open onto opStack | `initial_state` |
| **GROUP_END** | Flush opStack until matching group-open; pop & validate match from `parsedQ` | `initial_state` |
| **stream_end** | Return (expression complete) | — |
| Other | Error: invalid token | — |

#### `expect_unary` — Right side of a binary operator, expecting an operand

Entered after pushing a binary operator.

| Token Category | Action | Next State |
|---|---|---|
| **LITERAL** | Emit to `parsedQ` | `expect_binary` |
| **IDENTIFIER** | Resolve; emit to `parsedQ` | `expect_binary` |
| **PAREN_START** | (Noted, currently prints debug) | — |
| **KEYWORD_START** | (Noted, currently prints debug) | — |
| **UNARY_OPS** | (Noted, currently prints debug) | — |
| **stream_end** | Return | — |
| Other | Error: invalid token | — |

### Terminal Condition

After `initial_state` returns, the main `parse()` function flushes any remaining operators from `opStack` to `parsedQ`. Unmatched group-opens at this point indicate a compilation error.

---

## Operator Stack Flush Rules

### `flushOpStack(token)`

Before pushing an operator, consult `TBL_PRECEDENCE_FLUSH[token.kind]` for a bitset of higher-precedence operators. Pop and emit all matching operators from the stack top.

### `flushUntil(bitset)`

Pop and emit operators until a token matching the bitset is found, then pop that token too. Used for:
- **Group close:** flush until matching group-open
- **Colon:** flush until keyword-start
- **Dedent:** flush until matching `grp_dedent`

If an unmatched `GROUP_START` is hit before the target, it's a compilation error (unmatched grouping).

### `flushUntilToken(kind)`

Convenience wrapper — creates a single-token bitset and calls `flushUntil`.

---

## Grouping and Scope

### Parentheses / Brackets / Braces

- **Open:** Pushed onto `opStack`
- **Close:** `flushUntil(GROUP_START)` pops all operators down to the matching open. The group-open token is then removed from `parsedQ` and `offsetQ` (groups are structural, not emitted in output). Mismatched open/close types produce a compilation error.

### Indentation Blocks

- **`grp_indent`:** Emitted directly to `parsedQ` as a block marker. A corresponding `grp_dedent` token is pushed onto `opStack`. A new resolution scope is opened.
- **`grp_dedent`:** Triggers `flushUntilToken(grp_dedent)` to close the block, then ends the resolution scope.

### Function Calls

`call_identifier` tokens trigger special handling:
1. The next token (`grp_open_paren`) is consumed and pushed onto `opStack`
2. The call identifier itself is pushed onto `opStack` above the paren
3. This produces a Lisp-like `(fn args...)` structure in the output

---

## Planned / TODO

- **Unary operator handling:** Currently logged but not fully wired
- **Keyword blocks:** `if`/`else`/`for`/`fn` keyword parsing (header/colon/body/continuation)
- **Type annotations:** `<Type> (<Type>..) <Value>` parsing
- **Error recovery:** Continue parsing after errors instead of halting
- **Const-folding:** Fold literal operands at parse time during `popOp`
- **Separator indexing:** Linked-list threading of comma/newline positions (commented out `sepIndex`/`grpIndex`)
