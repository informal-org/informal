# Group Chain & Iteration Order

## Status

Proposed. Replaces position-math (`openIdx + 1 + 2*slot`) in `parser.zig` for param-list and group introspection.

## Motivation

The parser currently assumes a rigid param-list layout `(decl, sep, decl, sep, ..., decl, close)` and indexes params by `openIdx + 1 + 2*slot`. This breaks once params gain type annotations (`a : Int`) or default-value expressions (`a = 1 + 2`), since the sep/decl stride is no longer fixed. It also forces body-side lazy-arg consumption to be monotonic in positional order (`walkBodyBlock`'s `slot_cursor`), preventing the design goal of body-order flexibility for lazy parameters.

Replace the position math with a linked-list structure woven through every group's separator tokens (open, commas, close). Parens currently carry `raw = 0`; `sep_comma` currently carries only `arg_idx`. Repurpose all three to carry a common triple of offsets.

## Requirements

1. Every `grp_open_*`, `grp_close_*`, and `sep_comma` token carries three `i16` offsets: `prev_offset`, `next_offset`, `iter_offset`. Total: 48 bits — fits in the existing `Data` payload.
2. `prev_offset` / `next_offset` form a doubly-linked chain through the group in positional order.
   - Open paren: no predecessor; `prev_offset` is overloaded (see below).
   - Close paren: `next_offset = 0` (no successor).
   - Each comma has both set.
   - **Fn open paren overload**: `open_paren.prev_offset` is repurposed two ways. (a) During param/body parse, it transiently holds the iter-chain *tail* (what handleLazyParamUse extends). (b) After the fn finishes parsing, it is reset to point at the matching close paren — the stable post-parse meaning used by `opIdentifierInfix` for O(1) open→close lookup.
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

Extends `groupDelim` with an iter-chain cursor stored entirely on parsed tokens (no parser field):
- During param parse, track the eager iter tail in a local `iter_tail` variable. After each **eager** param decl, the separator *immediately preceding* this decl (open paren for param 0, else the most recently emitted comma) is appended:
  - Set `parsedQ[iter_tail].iter_offset = preceding_sep_idx - iter_tail`.
  - Update `iter_tail = preceding_sep_idx`.
- Each **lazy** param decl gets its own forward channel: patch `decl.next_offset = offset(open_paren, decl_idx)` (negative). This open-paren ref is consumed on first body reference.
- After emitting the close paren and writing `close.iter_offset = offset(eager_head, close)` (when eagers exist), seed the iter-tail channel:
  - `open.prev_offset = offset(initial_tail, open)` where `initial_tail = iter_tail` if eagers exist, else `closeIdx`. The no-eagers bootstrap makes the first lazy append uniformly write `close.iter_offset` (the head anchor) without a special case.

The lazy segment of the iter chain is extended **in-place during body parsing**, with no parser field and no save/restore around nested fn bodies.

- When `handleLazyParamUse` resolves a `const_identifier` body reference to a lazy param decl:
  1. `decl_to_open = decl.next_offset` (interpreted as i16); `open_idx = decl_idx + decl_to_open`.
  2. `tail_idx = open_idx + open.prev_offset` — the current iter tail.
  3. `sep_idx = decl_idx - 1`.
  4. Extend chain: `parsedQ[tail_idx].iter_offset = sep_idx - tail_idx`.
  5. Advance tail: `open.prev_offset = sep_idx - open_idx`.
- `Resolution.resolve` then overwrites `decl.next_offset` with the use-chain link (positive offset to the splice in the body), consuming the open-paren ref in the same step.
- Validation: `error.LazyParamUsedMoreThanOnce` is detected via `tail_tok.flags.declaration == false` — the second body reference sees a use, not the decl, in `declarations[sym_id]`. Unused-lazy is not enforced at parse time (assume good input).
- After body parse completes, restore `open.prev_offset = offset(close, open)` — the stable post-parse meaning.

By the time the fn finishes parsing: the iter chain is fully linked, `iter_offset` on the tail stays `0` as the terminator, and `open.prev_offset` is the close ref.

### `opIdentifierInfix` — infix lazy-fn detection

Replaces the fixed-offset shape check (`openIdx + 1`, `openIdx + 3`) with an iter-chain walk:
- Walk from `close_paren.iter_offset`. Require exactly two entries.
- First iter sep must expose an `identifier` (eager) decl.
- Second iter sep must expose a `const_identifier` (lazy) decl.
- Otherwise fall back to `binaryOpResolved`.

### `callExprInline` / `walkBodyBlock` — call-site splice

The `syntaxQ` is a consumer queue with a `head` cursor — prior tokens remain in storage after consumption, so seeking back is `syntaxQ.head = pos`. We use this to splice each lazy arg in O(1) at body walk: the eager pass records each lazy arg's `syntaxQ` offset on its body splice token, and the body pass reads it back.

1. **Record anchors.** After popping `grp_open_paren`, record `args_start = syntaxQ.head`.
2. **Eager pass.** Walk the fn's positional param chain in `parsedQ` (via `next_offset`). For each param decl:
   - Between params (except for param 0): `assert(syntaxQ.pop().kind == sep_comma)`.
   - If `kind == identifier` (eager): `parse(Separator)` to consume the arg, then emit the synthesized `ident_splice` decl.
   - If `kind == const_identifier` (lazy): locate the body splice via `splice_idx = decl_idx + decl.next_offset` (use-chain link written by `Resolution.resolve` during body parse). Patch `splice.next_offset = syntaxQ.head - args_start`. Then `skipArg()`.
3. **After eager pass.** Assert the matching `grp_close_paren` and record `post_call = syntaxQ.head`.
4. **Body pass.** Walk body tokens. For each `ident_splice`:
   - Read `arg_offset = splice.next_offset`. Set `syntaxQ.head = args_start + arg_offset`.
   - `parse(Separator)` to splice the arg.
   - Reset `splice.next_offset = 0` so the next call site's eager pass sees a clean slot.
5. **Restore.** `syntaxQ.head = post_call`.

Per-splice cost is O(1): one read, one seek, one parse, one zero-out. No prev-walk, no slot count. The `splice.next_offset` slot is safe to commandeer because lazy params are single-use by construction (so it's `0` after body parse), and call sites are independent (every call's eager pass writes before its body pass reads).

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
