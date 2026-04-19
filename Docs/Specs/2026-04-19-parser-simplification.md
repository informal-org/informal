# Parser Simplification — Strip Inlining and Macro Expansion

## Goal

Reduce `parser.zig` to a purely structural front-end. The parser emits a flat
postfix `parsedQ` of tokens with resolved identifier chains and an intact
grouping chain. All call-site lowering and macro expansion are deferred to a
new IR stage that will sit between the parser and codegen.

## Background

The old parser did two jobs in one pass:

1. Structural parsing and symbol resolution (Pratt dispatch, postfix emission,
   paren/bracket/brace chain emission, indent blocks, `if/else`, function
   definitions, use-def chains).
2. Inline macro expansion — prefix N-ary function inlining, infix fexpr-style
   expansion, body-template walking with identifier re-resolution, lazy-param
   splice-kind rewriting, and an iter-chain overlay on group-link metadata
   that reordered fn params "eager-first" to make expansion cheap.

The expansion logic added ~300 lines of unrelated concerns to the parser and
forced the token layout to carry expansion bookkeeping (`kw_lazy_fn` kind,
`ident_splice` kind, `group_link.iter_offset` reorder, transient `next_offset`
parking on lazy decls). Since a new IR stage is planned and macros will be
reintroduced on top of that IR, the expansion logic is stripped now so the IR
can be designed against a clean, minimal contract.

## Requirements

1. The parser emits a flat postfix `parsedQ` sufficient for later stages
   without re-tracing structure.
2. Function definitions stay intact with `kw_fn`, `body_length` /
   `body_offset`, and a linked param group chain.
3. Function calls stay as `call_identifier` postfix with their paren-group
   chain.
4. Every identifier — including `op_identifier` and `const_identifier` in
   infix position — carries a resolved `prev_offset` to its declaration.
5. No expansion happens at parse time. No `ident_splice` tokens are emitted.
   No `iter_offset` writes to `group_link`. No `kw_lazy_fn` headers.
6. `open.prev_offset` on a fn-param open paren is preserved as the O(1)
   open→close link (general-purpose, not laziness-dependent).
7. The parser continues to drive scope management from natural scope openers
   only — `kwFn` (`.function`), `indentBlock` (`.block`), and the root
   `.base`. No synthetic `.block` scopes pushed around expansion, no
   save/restore of `declarations[sym_id]`, no re-resolution.

## Parser Surface After the Change

- `identifier` — `resolve` + `emit`.
- `opIdentifierInfix` — `resolve` + `binaryOpResolved`. Infix `op_identifier`
  and `const_identifier` resolve their operator-name reference before the
  right operand is parsed (so later stages see a resolved `prev_offset`).
- `callExpr` — `pop grp_open_paren`, emit paren group chain via `groupDelim`,
  emit the `call_identifier`.
- `kwFn` — declare name, emit `kw_fn` header, emit param group chain, parse
  body at `Separator` power, write `open.prev_offset = offset(close, open)`,
  patch header with `body_length` / `body_offset`.
- Everything else unchanged: Pratt dispatch, `groupDelim`, `emitChainedSep`,
  `indentBlock`, `kwIf`/`kwElse`, binary/unary/assign handlers, separators.

## Token Layout

- `kw_lazy_fn` and `ident_splice` enum entries are removed from `token.zig`.
  The IR stage will reintroduce whatever tokens macros need.
- `GroupLink.iter_offset` stays in the packed union — every `Data` variant is
  48 bits wide, so the unused field costs no memory. Parser writes zero.

## Tests

### Removed

- `"Lazy param used more than once raises diagnostic"` — `handleLazyParamUse`
  is gone; the error is no longer raised.
- `"Parse lazy fn inline expansion"` — expansion no longer happens at parse
  time.
- `"Parse N-ary prefix inline expansion"` — same.
- `"Parse reordered lazy iter chain"` — no iter chain.

### Updated

- `"Parse fn with const_identifier param"` (renamed from `"Parse lazy fn with
  splice detection"`) — header is now `kw_fn`; no `ident_splice` rewrite;
  `iter_offset` values all zero.
- `"Parse fn body_offset points to first body token"` — `iter_offset` values
  on open / seps / close go to zero; `body_length`, `body_offset`, identifier
  offsets unchanged.
- `"Parse fn definition"` — `iter_offset` on open/close go to zero; all other
  expected values unchanged.

### Unchanged

Structural tests: basic add, math precedence, if/else, nullary/unary/ternary
paren groups, brackets, braces, nested parens, nested calls, skipNewLine.

## File Tests

Moved to `Tests/FileTests/deferred/` because they depend on call lowering or
macro expansion:

- `fn_inline.ifi`, `fn_lazy.ifi`, `fn_nary_prefix.ifi`, `fn_nary_mixed.ifi`,
  `fn_ifte.ifi`, `fn_nested_call.ifi`, `fn_nested_paren.ifi`.

`fn_skip.ifi` stays in place — it's the regression guard that codegen still
skips fn bodies via `body_length`. Its body is skipped; only the top-level
literal `5` is evaluated.

The two wired-up file tests (`fn_inline.ifi`, `fn_lazy.ifi`) are removed from
`filetest.zig`. They'll be reintroduced when the IR stage lands.

## Codegen Patch

- Remove `TK.ident_splice` from the identifier-family match.
- Drop `TK.kw_lazy_fn` from the header skip-over (keep `TK.kw_fn`). The skip
  is essential; without it fn body tokens would execute as top-level code.
- User-defined function calls reach the `call_identifier` syscall handler and
  produce incorrect syscalls. This is expected until the IR stage lowers
  calls.

## Deferred Follow-Ups

- IR stage between parser and codegen.
- Macro reintroduction on top of IR.
- Call-site lowering (function calls produce real calls, not the syscall
  stub).
