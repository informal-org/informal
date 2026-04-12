# Simplify paren-chain metadata (scheme C)

## Problem

The paren/comma chain currently carries bidirectional offsets and an
arg count on every link, yet downstream code only reads a small subset:

- `callExpr` / `groupParen` / list / brace: no downstream reader of the
  metadata at all — the offsets exist purely to satisfy the invariant.
- `opIdentifierInfix`: reads `group_open.close_offset` to locate the
  body start and `group_open.next_sep` to locate the second param.
  Both are equally reachable via the fn header or a short walk.
- Splice lookup: described in specs as "one hop via `prev_offset` from
  the splice token to its param decl, then `parsedQ[decl_idx - 1]`",
  which needs only `arg_idx` on the adjacent separator.

The extra offsets waste emission effort and complicate `emitGroupOpen /
emitGroupSep / emitGroupClose` with a shared `[16]GroupFrame` stack.

## Approach

1. **`sep_comma`** retains only `arg_idx: u16`; the forward-offset
   field is removed. Remaining bits are reserved.
2. **`grp_open_*`** carries no payload — `arg_cnt`, `next_sep`, and
   `close_offset` are removed.
3. **`grp_close_*`** carries no payload — `open_offset` and `prev_sep`
   are removed.
4. **`kw_fn` / `kw_lazy_fn` fn header** becomes
   `{ body_length: u32, body_offset: u16 }`. `body_offset` is patched
   exactly once when the param list's `)` is emitted, to
   `close_paren_idx + 1 - header_idx` — so `header_idx + body_offset`
   is the first body token. The old `metadata` bitmask (lazy flag +
   param count) is retired; laziness is now encoded by the header
   token's kind (`kw_fn` vs `kw_lazy_fn`).
5. **Per-handler arg counter**. `callExpr`, `groupParen`,
   `groupBracket`, `groupBrace`, and `kwFn`'s param-list parser each
   keep a single `u16 arg_counter` local. It starts at 0 and
   pre-increments on each top-level `sep_comma` emission, so the
   emitted sep's `arg_idx` equals the 0-based index of the argument
   that follows it. The Pratt recursion handles paren nesting — no
   shared stack, no depth counter, no fixup array.

## Invariants preserved

- `parsedQ[sep_idx + 1]` is always the declaration/expression for
  the argument the sep precedes; `parsedQ[open_idx + 1]` is slot 0.
- Splice → slot lookup: follow `prev_offset` from a splice token to
  its template param decl, then `parsedQ[decl_idx - 1]` is the
  preceding sep_comma (or open paren for slot 0). Its `arg_idx`
  gives the slot; slot 0 is the short-circuit (open paren, no
  `arg_idx`).
- Param classification: walk forward from `open_paren_idx + 1`,
  tracking paren/bracket/brace depth, stopping at each top-level
  `sep_comma` or the matching close.
- Codegen skip-over: `kw_fn` / `kw_lazy_fn` advances by
  `body_length`. `grp_open_paren`, `sep_comma`, `grp_close_paren`
  (and bracket/brace analogues) remain structural no-ops.

## Non-goals

- No O(1) jump from `(` to matching `)`. A linear scan over the
  param list is sufficient for every current consumer.
- No depth counter, group stack, or fixup list for paren nesting.

## Test plan

- Existing parser tests for fn definition, call expansion, paren /
  bracket / brace groups, nullary / unary / ternary groups, and
  nested groups must pass with updated expectations.
- New test: nested calls `f(g(1, 2), h(3, 4))` — verifies each
  paren-opening handler's local arg counter is correctly scoped,
  no cross-talk between nested calls.
- New test: fn-definition `body_offset` lands on the first body
  token after the param list's `)`.
