# Group Chain & Iteration Order

## Status

Proposed. Replaces position-math (`openIdx + 1 + 2*slot`) in `parser.zig` for param-list and group introspection.

## Motivation

The parser currently assumes a rigid param-list layout `(decl, sep, decl, sep, ..., decl, close)` and indexes params by `openIdx + 1 + 2*slot`. This breaks once params gain type annotations (`a : Int`) or default-value expressions (`a = 1 + 2`), since the sep/decl stride is no longer fixed. It also forces body-side lazy-arg consumption to be monotonic in positional order (`walkBodyBlock`'s `slot_cursor`), preventing the design goal of body-order flexibility for lazy parameters.

Replace the position math with a linked-list structure woven through every group's separator tokens (open, commas, close). Parens currently carry `raw = 0`; `sep_comma` currently carries only `arg_idx`. Repurpose all three to carry a common triple of offsets.

## Requirements

1. Every `grp_open_*`, `grp_close_*`, and `sep_comma` token carries three `i16` offsets: `prev_offset`, `next_offset`, `iter_offset`. Total: 48 bits — fits in the existing `Data` payload.
2. `prev_offset` / `next_offset` form a doubly-linked chain through the group in positional order.
   - Open paren: `prev_offset = 0` (no predecessor).
   - Close paren: `next_offset = 0` (no successor).
   - Each comma has both set.
3. `iter_offset` is meaningful **only** for a `kw_fn` / `kw_lazy_fn` parameter list. Everywhere else (plain parens, brackets, braces, call arg lists) it is `0` and reserved for future use.
4. For a fn param-list, `iter_offset` encodes iteration order:
   - **Head anchor**: the close-paren's `iter_offset` holds the offset to the first separator in iter order. `0` when the iter chain is empty.
   - **Chain links**: each separator in the iter chain stores the offset to the next iter separator in its `iter_offset`. `0` terminates the chain.
   - **Param exposure**: the separator at position `S` exposes the param decl at `S + 1` (simple layout; generalises to "next decl token after S" when richer param expressions land).
   - **Iter ordering**: all eager params in positional-declaration order, then all lazy params in body-reference order.
5. `arg_idx` on `sep_comma` is removed. The positional index of any separator is derivable via a backward walk of `prev_offset` to the open paren.
6. The `lazyMask: BitSet64` in `kwFn` is removed. The eager/lazy split is fully encoded by the iter chain.

## Data layout

```zig
pub const GroupLink = packed struct(u48) {
    prev_offset: i16,
    next_offset: i16,
    iter_offset: i16,
};
```

`Data.group_sep` (`GroupSep`) is replaced by `Data.group_link` (`GroupLink`).

`Token.groupOpen(kind)`, `Token.groupClose(kind)`, `Token.groupSep()` all initialize the triple to `0`. Chain fields are patched as subsequent separators are emitted.

## Parser procedure

### `groupDelim` — non-fn groups (parens, brackets, braces, call arg lists)

Track a single local `prev_sep_idx: u32`:
- On emitting the open paren: record its index as `prev_sep_idx`. All three offsets stay `0`.
- On emitting each comma: set this comma's `prev_offset` to `prev_sep_idx - current_idx`. Patch `parsedQ[prev_sep_idx].next_offset = current_idx - prev_sep_idx`. Update `prev_sep_idx = current_idx`.
- On emitting the close paren: same as comma handling. `iter_offset` stays `0`.

### `kwFn` — fn param-list

Extends `groupDelim` with an iter-chain cursor:
- `iter_tail: u32 = close_paren_idx` — the close paren acts as the anchor of the iter chain head.
- After emitting each **eager** param decl: the separator *immediately preceding* this decl (either the open paren for param 0, or the most recently emitted comma) is appended to the iter chain.
  - Set `parsedQ[iter_tail].iter_offset = preceding_sep_idx - iter_tail`.
  - Update `iter_tail = preceding_sep_idx`.
- Lazy params are **skipped** during the param-parse pass; they join the iter chain after body parsing.
- Remove `lazyMask`. Lazy params are re-identified later by scanning `kind == const_identifier` tokens along the positional chain.

The lazy segment of the iter chain is extended **in-place during body parsing**. No auxiliary array, no post-body reordering pass.

- `iter_tail` persists from param parse into body parse (stored on the active function's scope entry).
- When the parser resolves a `const_identifier` reference in the body (emitting it as `ident_splice`):
  - Locate the referenced decl via the existing prev-chain.
  - Find the decl's preceding separator: `sep_idx = decl_idx - 1` (simple layout; walk back along positional chain for the general case).
  - Extend the iter chain: `parsedQ[iter_tail].iter_offset = sep_idx - iter_tail; iter_tail = sep_idx`.
- Validation:
  - `error.LazyParamUsedMoreThanOnce` if the decl's use-chain head (`decl.next_offset`) is already non-zero when this reference resolves.
  - `error.LazyParamUnused` — checked after body parse by a single walk of the positional chain: any `const_identifier` decl with `next_offset == 0` was never referenced.

By the time body parse completes, the iter chain is fully linked. `iter_offset` on `iter_tail` stays `0` as the natural terminator.

The iter-chain write lives in the parser's identifier handler (which already dispatches on kind), not in `resolution.resolve` — keeping resolution focused on symbol bookkeeping.

### `opIdentifierInfix` — infix lazy-fn detection

Replaces the fixed-offset shape check (`openIdx + 1`, `openIdx + 3`) with an iter-chain walk:
- Walk from `close_paren.iter_offset`. Require exactly two entries.
- First iter sep must expose an `identifier` (eager) decl.
- Second iter sep must expose a `const_identifier` (lazy) decl.
- Otherwise fall back to `binaryOpResolved`.

### `callExprInline` / `walkBodyBlock` — call-site splice

The `syntaxQ` is a consumer queue backed by a list with a `head` cursor — prior tokens remain in the underlying storage after consumption. Seeking back is as cheap as assigning `syntaxQ.head = args_start`. This lets us drop the monotonic `slot_cursor` scheme (and its positional-order requirement on lazy body references) without any auxiliary bookkeeping.

1. **Record anchors.** After popping `grp_open_paren`, record `args_start = syntaxQ.head`.
2. **Eager pass.** Walk the fn's positional param chain in `parsedQ` (via `next_offset`, not slot math). For each param decl:
   - If `kind == identifier` (eager): `parse(Separator)` to consume the corresponding arg from `syntaxQ`, then emit the synthesized `ident_splice` declaration.
   - If `kind == const_identifier` (lazy): `skipArg()` — advance past the arg without parsing.
   - Between params (except after the last): `assert(syntaxQ.pop().kind == sep_comma)`.
3. **After eager pass.** Assert the matching `grp_close_paren` and record `post_call = syntaxQ.head`.
4. **Body pass.** Walk body tokens. For each `ident_splice`:
   - Compute the referenced lazy param's positional slot: from the splice's `prev_offset`, follow to the decl; from the decl, locate its preceding separator; walk that separator's `prev_offset` chain back to the open paren, counting hops → `slot`.
   - `syntaxQ.head = args_start`. Walk forward `slot` times using `skipArg` + `pop(sep_comma)`.
   - `parse(Separator)` to splice the arg.
5. **Restore.** `syntaxQ.head = post_call`.

Per-splice cost is O(slot) in `syntaxQ` scan. For small arities (typical <8 params) this is negligible; we gain out-of-order lazy-reference support with zero extra state.

## Migration notes

- `Data.GroupSep` removed. `Data.group_link: GroupLink` added.
- `Token.groupSep(arg_idx)` → `Token.groupSep()`. All call sites updated.
- `TokenWriter.format`'s `sep_comma` branch prints the `(prev, next, iter)` triple instead of `arg_idx`.
- No other semantic consumer of `arg_idx` exists in-tree (confirm during impl with a grep).

## Tests

Red tests to add before implementing (in `test/test_parser.zig`):

1. **Positional chain — fn params.** `fn foo(a, b, c): body`. Walk `( → , → , → )` via `next_offset`; reverse walk via `prev_offset`; offsets sum to zero round-trip.
2. **Positional chain — non-fn groups.** `(1, 2, 3)` and `[1, 2]`. Chain walks correctly; all `iter_offset` values are `0`.
3. **Iter chain — all-eager.** `fn foo(a, b, c): a + b + c`. From `).iter_offset`: visits `(`, `comma_0`, `comma_1` in order; terminates at `0`.
4. **Iter chain — lazy in body.** `fn OR(first, SECOND): if bool(first): first else: SECOND`. Iter order = `[first, SECOND]`. Chain: `( → comma_0 → 0`, with `).iter_offset → (`.
5. **Iter chain — reordered lazy.** `fn BUT(COND, then, ELSE): if COND: then else: ELSE`. Positional params = `[COND, then, ELSE]`. Body references: `COND`, then `then`, then `ELSE`. Iter order = `[then, COND, ELSE]` (eager first: `then`; lazy in body-ref order: `COND`, `ELSE`). Chain: `comma_0 → ( → comma_1 → 0`, with `).iter_offset → comma_0`.
6. **Unused lazy.** `fn foo(LAZY): 1`. Returns `error.LazyParamUnused`.
7. **Double-use lazy.** `fn foo(LAZY): LAZY + LAZY`. Returns `error.LazyParamUsedMoreThanOnce`.

File-tests (`Tests/FileTests/`):
- Existing `inline_*` cases continue to pass.
- New: a macro that references lazy params out of positional order, end-to-end through codegen.

## Non-goals

- Default-value expressions and type annotations on params. The chain **enables** these; their parser support is a separate task.
- N-ary (>2 params) lazy inlining through `op_identifier`. Unchanged.
- Iter-chain semantics for non-fn groups. Reserved for future use.
