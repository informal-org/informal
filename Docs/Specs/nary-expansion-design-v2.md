# N-ary Inline Expansion — Data-Oriented Design (Revision 2)

**Status:** design notes, superseding revision 1. All nine triage questions
now settled. This revision incorporates Sir's direction on four structural
changes:

1. **Infix remains 2-param, first operand always eager.** No left-operand
   patching ever required.
2. **Prefix N-ary admits any mix of eager and lazy, in any order.** No
   "first must be eager" constraint — at a prefix call site there's no
   pre-emitted operand to patch.
3. **Function calls with at least one lazy argument inline.** Pure-eager
   user function calls remain genuine runtime calls via the existing
   `call_identifier` path (future call convention to be specified
   separately). Only the presence of a lazy parameter triggers template
   expansion.
4. **Preserve `(`, `,`, `)` tokens in `parsedQ`** as a forward-linked
   chain, giving O(1)-per-hop param navigation with no cap on parameter
   count and no dedicated metadata bitmask.

Additionally, following Sir's guidance on flag-vs-kind usage: the lazy-fn
marker and splice marker both move from flag bits to distinct kinds.
Flags are for orthogonal signals that compose across variants; kind space
is abundant and should absorb true variants.

---

## 0. What changed from revision 1

| Area | Revision 1 | Revision 2 |
|------|-----------|-----------|
| Max param count | Hard cap N ≤ 8 | No cap; limited only by `u16` chain offsets |
| Laziness classifier | Bit 15 of `fn_header.metadata` | New kind `kw_lazy_fn` (distinct from `kw_fn`) |
| Splice marker | `flags.splice` bit | New kind `ident_splice` (distinct from `identifier`/`const_identifier`) |
| Param classification | Re-read `parsedQ[declIdx+2+i].kind` in a sequential sweep | Walk the `(` → `,` → `,` → `)` chain; kind at `sep_idx + 1` |
| Lazy-arg operand capture (prefix) | Stack-local `[8](start, end)` array | Chain-resident — the `(` token links directly to each `,`, giving arg boundaries without a bespoke scratch buffer |
| `skimArg` helper | Needed (tracks `()[]{}` depths) | Not needed — chain already knows where the args are |
| `fn_header.metadata` | 16-bit field with `lazy:1, reserved:7, param_count:8` | 16-bit field now free of lazy bit and param count. Reserved for future use. |
| Pure-eager user calls | Legacy `call_identifier` emission | **Unchanged** — still a runtime call; only lazy-bearing calls inline |
| `call_identifier` at codegen | Mixed user-and-builtin with heuristic | Still mixed — pure-eager user calls and builtins both reach codegen as `call_identifier`. Heuristic cleanup is orthogonal to this work. |

The redesign is materially simpler than revision 1 in three of its hottest
paths (collection, splice dispatch, and definition-time metadata packing).

---

## 1. The preserved paren-chain

This is the structural change that cascades into everything else.

### Tokens now emitted to `parsedQ`

Where the lexer produces `grp_open_paren`, `sep_comma`, `grp_close_paren`,
the parser now **emits** them to `parsedQ` (today they are consumed but
discarded). They are threaded into a forward-linked chain:

```
    (  ──▶  ,  ──▶  ,  ──▶  )
    ◀───────────────────────
               (back-ref on ')' to '(')
```

### Token layouts

**`grp_open_paren` in parsedQ:**
```
 63       48 47                    16 15        8 7         0
┌───────────┬────────────────────────┬───────────┬──────────┐
│ arg_cnt16 │  fwd_offset to , or )  │grp_open_p │ flags    │
└───────────┴────────────────────────┴───────────┴──────────┘
  fwd_offset : u32 offset to first sep_comma (or matching grp_close_paren if arg_cnt == 0)
  arg_cnt    : u16 total arg count (redundant with chain walk, but O(1))
```

**`sep_comma` in parsedQ:**
```
 63       48 47                    16 15        8 7         0
┌───────────┬────────────────────────┬───────────┬──────────┐
│ arg_idx 16│  fwd_offset to next    │sep_comma  │ flags    │
└───────────┴────────────────────────┴───────────┴──────────┘
  fwd_offset : u32 offset to next sep_comma or to grp_close_paren
  arg_idx    : u16 index of the argument that follows this comma (0-based)
```

**`grp_close_paren` in parsedQ:**
```
 63       48 47                    16 15        8 7         0
┌───────────┬────────────────────────┬───────────┬──────────┐
│ reserved  │  back_offset to '('    │grp_close_p│ flags    │
└───────────┴────────────────────────┴───────────┴──────────┘
  back_offset : u32 offset back to matching grp_open_paren
```

All offsets are u32 — effectively unbounded for any realistic program.

### Invariant

**For any `(` token at index `p` with `arg_cnt = N > 0`:**
- Arg 0 starts at `p + 1`.
- Walking the chain k times from `p` lands on a `sep_comma` (for k < N) or
  the matching `grp_close_paren` (for k = N).
- Arg i (for 1 ≤ i < N) starts at `(chain_hop(p, i)) + 1`.

**For function definitions** (`fn NAME(param : Type = value, …)`) and
**call sites** (`NAME(expr, expr, …)`), this invariant means:

- Param i's declaration token (or arg i's first token) is always at
  `sep_idx + 1` for i ≥ 1, or at `open_paren_idx + 1` for i = 0.
- Classification of a param's eagerness is one load: read
  `parsedQ[sep_idx + 1].kind`. `identifier` → eager. `const_identifier`
  → lazy.

### Emission during parsing

The paren-handling code (`groupParen`, `callExpr`, `kwFn`'s param list
parser) all share one mechanism: a small stack-local "chain tail index"
tracking the most recently emitted `(` or `,` awaiting linking.

- On `(`: emit `grp_open_paren` at current index, push index onto the
  chain-tail stack. `arg_cnt` starts at 0.
- On `,` (at the group's top level): emit `sep_comma` at current index.
  Patch the top of the chain-tail stack's token: `fwd_offset = current_idx − chain_tail_idx`.
  Update chain_tail_idx to the new `,`. Increment the enclosing `(`'s
  `arg_cnt` (via a separate "open-paren-idx" saved alongside the chain
  tail — or by a single back-ref from `,` to `(` if preferred).
- On `)`: emit `grp_close_paren` at current index. Patch the chain-tail
  token's `fwd_offset` to here. Write `back_offset` to point back at the
  matching `(`. Pop chain-tail stack.

This is structurally identical to the existing indent/dedent patching
logic — same shape, different tokens.

### Interaction with existing paren handlers

`groupParen`, `groupBracket`, `groupBrace` currently swallow paren pairs
without emitting. Under this design, `grp_open_paren` / `grp_close_paren`
**are** emitted for every paren group — function calls, parenthesised
sub-expressions, and fn parameter lists. The chain is always present.

Brackets and braces get the same treatment for consistency (their chains
are useful for array and struct-literal handling later), but this design
only relies on the paren chain.

### Codegen impact

Codegen currently skips nothing because these tokens don't reach it.
After this change, codegen needs to treat `grp_open_paren`, `sep_comma`,
and `grp_close_paren` as **structural no-ops** — skip them in the linear
walk. This is a trivial case in the main switch.

---

## 2. Token layout changes: kinds, not flags

Following Sir's principle that flags are an extra layer on top of kind
and that pure variants deserve their own kind, we introduce two new kinds
and retire one flag bit.

### New kinds

**`kw_lazy_fn`** — replaces the "has-any-lazy-params" bit on `fn_header`.
Emitted by `kwFn` when the definition contains at least one
`const_identifier` parameter. Otherwise `kw_fn` is emitted as today.
Codegen dispatches on kind for skip-over (both kinds skip `body_length`
tokens). Call-site dispatch reads this single kind value.

**`ident_splice`** — replaces `flags.splice`. Used in two contexts:
- In a lazy function body, every reference to a lazy parameter is
  rewritten to `ident_splice` (with `flags.declaration = 0`) at definition
  time by `kwFn`. The body walker dispatches splice action on kind, not
  on a flag bit.
- At a call site during expansion, every synthesised parameter binding
  is emitted as `ident_splice` (with `flags.declaration = 1`). This tells
  codegen "bind this declaration to the stack-top value; do not allocate
  a fresh register."

The `flags.declaration` bit still disambiguates the two contexts — this
is a legitimate use of the flag layer (an orthogonal signal composing
with the kind), not a variant marker.

### Retired / renamed

- **`flags.splice` bit is removed.** The bit position is freed for future
  use.
- **`fn_header.metadata` loses its lazy flag** (bit 15) and its param
  count (bits 0–7). The field is reclaimed for future use. The header
  now carries only `body_length: u32` plus 16 reserved bits.

### Updated `fn_header`

```
 63       48 47                    16 15        8 7         0
┌───────────┬────────────────────────┬───────────┬──────────┐
│ reserved  │    body_length (32)    │kw_fn /    │ flags    │
│   (16)    │                        │kw_lazy_fn │          │
└───────────┴────────────────────────┴───────────┴──────────┘
```

Param count is now read from the preceding `(` token's `arg_cnt` field.
Laziness is read from the header's kind.

### Adjacency invariant now slightly different

Today: `kw_fn` at `declIdx + 1`, params at `declIdx + 2 .. declIdx + 2 + paramCount`.

Under this design, the param list lives inside a paren group. The order
is:

```
parsedQ[declIdx]       identifier (fn name) with flags.declaration = 1
parsedQ[declIdx + 1]   kw_fn or kw_lazy_fn  (header, with body_length)
parsedQ[declIdx + 2]   grp_open_paren       (head of param chain)
parsedQ[declIdx + 3]   first param decl     (eager or lazy kind)
... chain of sep_comma + param decls ...
parsedQ[last_arg + 1]  grp_close_paren      (tail of param chain)
                       — body tokens begin —
```

`declIdx + 2` is now the paren head, not the first param decl. Call-site
expansion reads the header at `declIdx + 1`, reads the paren head at
`declIdx + 2`, and navigates the chain for param access.

---

## 3. Restating the observable truths

Updated from revision 1:

1. `parsedQ` stays postfix-valid at every point during expansion, now
   including valid paren-chain invariants (every `(` matched by a `)`,
   every `,` linked forward).
2. Re-resolved identifiers in the body carry correct
   `prev_offset`/`next_offset` against the **call-site scope**.
3. Indent/dedent pairs, and paren-chain pairs, emitted during the walk
   have matching offsets pointing at each other.
4. `declarations[]` is restored exactly for the synthesized param
   bindings on handler exit — no shadow leakage.
5. Codegen skip-over for fn bodies continues to work using
   `fn_header.body_length`. The `body_length` now counts from the token
   **after** the header up to and including the last body token —
   including the param-list paren group, for simplicity (codegen skips
   over the whole lot in one step).
6. The existing 2-param infix call site produces identical **resulting**
   output to today, though the collection path is reorganised around the
   paren chain for uniformity.

---

## 4. The data — before the algorithm (revised)

### Hot data

| Element | Size | Count at scale | Access pattern |
|---------|------|---------------|----------------|
| fn_header (`kw_fn` / `kw_lazy_fn`) | 8 B | 1 per fn | Read once at call-site entry |
| `grp_open_paren` for params | 8 B | 1 per fn | Read once; then chain walk |
| Param decls (interleaved with `sep_comma`s) | 8 B each | N params + N−1 commas | Sequential via chain |
| `grp_close_paren` for params | 8 B | 1 per fn | Seldom — used only for skip-over boundary |
| Body template | 8 B × body_length | body_length | Sequential sweep during walk |
| Call-site `grp_open_paren` + its chain | 8 B × (2N+1) | at call site | Emitted during arg collection |

### Stack-local state at an expansion

```
saves:       [MAX_SAVES]{ sym_id: u16, prev_tail: u32 }
             // MAX_SAVES sized per the hard cap chosen (see §7)
save_count:  u16
fixup_stack: [4]u32   // indent fixup (existing)
fixup_depth: u8
cursor_state: ...     // for syntaxQ rewind bookkeeping during splices
```

Lazy operand ranges are **not** stored in the stack frame under this
revision — they're in the paren chain. More on this in §6.

### Access patterns remain L1-friendly

Entry: read `fn_header`, walk paren chain to classify params. The paren
head, first `,`, and close `)` are adjacent-ish in parsedQ (within the
span of the param list). For realistic N (< ~32) this is one or two cache
lines. The chain walk is O(N) loads but each load is sequential-adjacent
to the previous, i.e. prefetcher-friendly.

Body walk: unchanged from revision 1.

---

## 5. The expansion core (revised)

### Call-site dispatch

Both `callExpr` (prefix) and `opIdentifierInfix` (infix) now follow the
same resolve-then-dispatch shape:

```
1. resolve identifier → decl_idx
2. header_kind = parsedQ[decl_idx + 1].kind (if decl is a fn) else none
3. branch:
   - kw_lazy_fn    → inline expansion (mixed collection)
   - kw_fn         → legacy call_identifier emission (runtime call; args
                     parsed eagerly into parsedQ, call_identifier emitted
                     after)
   - not a fn decl → legacy path as today (builtin / syscall)
```

Only `kw_lazy_fn` triggers template expansion. Pure-eager user functions
remain runtime calls; this work does not touch their call convention.

### Prefix collection (new)

`callExpr` on a `call_identifier` that resolves to `kw_lazy_fn`
(pure-eager `kw_fn` takes the legacy runtime-call path and is not
discussed further here):

1. Pop `grp_open_paren` from `syntaxQ`. Emit it to `parsedQ`, push its
   index onto the chain-tail stack.
2. Walk the fn definition's param chain to classify each param:
   - Start at `parsedQ[decl_idx + 2]` (the definition's `grp_open_paren`).
   - For i = 0 .. N-1:
     - `param_decl_idx = chain_hop_plus_1(i)` against the definition's
       paren chain.
     - `is_lazy_i = (parsedQ[param_decl_idx].kind == const_identifier)`
3. For each arg i:
   - **Eager i:** call `parse(Separator)` to consume the arg into
     `parsedQ`.
   - **Lazy i:** mark the current `parsedQ` position as the arg's
     "splice anchor" — see §6 for how this connects the splice walker to
     the arg's tokens. Emit the arg's tokens into `parsedQ` verbatim by
     a lightweight non-semantic copy (token-level, no resolution, no
     emit side-effects), bounded by a top-level `,` or `)` via the
     call-site paren chain.
   - On `,`: emit `sep_comma` to `parsedQ`, patch chain tail.
   - On `)`: emit `grp_close_paren`, patch chain tail, pop.
4. Call `expandTemplate(decl_idx)` using the just-built call-site paren
   chain as the operand source.

### Infix collection (unchanged in spirit, simpler in plumbing)

`opIdentifierInfix` only fires when the resolved declaration's header is
`kw_lazy_fn` with exactly 2 params, first eager. Under this design:

- Slot 0 (eager, first): left operand already in `parsedQ`. Emit a
  `sep_comma` before the call expansion begins, or more cleanly,
  synthesise a mini call-site paren chain wrapping the emitted left
  operand. This makes the infix path look identical to a prefix call
  with two args: `(left_operand, right_operand)`.
- Slot 1 (lazy): pending in `syntaxQ`. The "right operand" captured for
  splice is the unconsumed syntaxQ range up to end-of-expression.

Making the two call-site paths share a paren-chain wrapper means the
expansion core has exactly one input shape. The infix adapter becomes
~20 lines: wrap the already-emitted left operand in a synthetic `(`/`,`/`)`
chain, position the right operand as a lazy arg, call `expandTemplate`.

If Sir prefers to leave infix-2 entirely untouched in its current form
for risk reasons, the fallback is that `opIdentifierInfix` keeps its own
bespoke 2-op handling. The cost is minor code duplication in the handler
itself. Either is defensible; I lean toward unification because it
shrinks the testing surface.

### `expandTemplate(decl_idx)` — the shared core

Works entirely off the call-site paren chain and the definition's paren
chain. Pseudocode:

```
1. header_idx = decl_idx + 1
2. def_paren_idx = decl_idx + 2
3. call_paren_idx = <emitted at start of current call-site collection>
4. N = parsedQ[def_paren_idx].arg_cnt

5. For each slot i in 0..N:
     def_slot_idx  = chain_hop_plus_1(def_paren_idx, i)
     call_slot_idx = chain_hop_plus_1(call_paren_idx, i)
     param_kind    = parsedQ[def_slot_idx].kind

     If param_kind == identifier (eager):
       // Synthesize binding: emit ident_splice decl tied to call-site operand
       sym_id     = parsedQ[def_slot_idx].sym_id
       Save declarations[sym_id] into saves[save_count++]
       Emit at current parsedQ index:
         kind            = ident_splice
         flags.declaration = 1
         sym_id          = sym_id
       resolution.declare() on the emitted token.

     If param_kind == const_identifier (lazy):
       // No emission. declarations[lazy_sym_id] stays untouched; every
       // reference to this param in the body is kind == ident_splice and
       // dispatches via splice path (not through declarations[]).
       Record: expansion_slot_to_call_operand[i] = call_slot_idx
       (Kept in stack-local state; needed at splice time.)

6. Walk body tokens [body_start, body_end]. Dispatch on kind:
     kind == ident_splice (and flags.declaration == 0):
       // Splice point.
       // Need to identify which lazy slot this is.
       Follow prev_offset from current template token to the param decl.
       slot_i = chain_hop_count from def_paren_idx to that param decl.
       call_operand_idx = expansion_slot_to_call_operand[slot_i]
       // Copy the call-site operand's tokens into parsedQ at current pos.
       // The operand's token range is [call_operand_idx,
       //   next_comma_or_close − 1], available via the call-site chain.
       Copy tokens one by one. For identifier/const_identifier tokens
       in the copied range, patch prev_offset/next_offset to be correct
       against their new position (they were already resolved against
       the call-site scope when originally emitted into the call-site
       chain, so only the relative offsets need updating for the copy
       delta).

     kind == identifier or const_identifier:
       // Re-resolve against call-site scope.
       Emit the token; call resolution.resolve() on the emitted index.

     kind == grp_indent:
       Emit with arg0 = 0 placeholder; push emit index to fixup stack.

     kind == grp_dedent:
       Pop fixup stack; emit; patch the paired grp_indent.

     kind == grp_open_paren, sep_comma, grp_close_paren:
       // Nested paren chain inside the body template.
       Emit; maintain a local chain-tail index analogous to the main
       parser's chain handling.

     Otherwise:
       Copy the 64-bit token as-is.

7. Restore declarations[] from saves[].
```

### Key point about lazy-arg copy

Sir noted that "copy-patching overhead is minimal". The overhead breaks
down as:

- Each token in the lazy arg range gets memcpy'd to the new position.
  At ~8 bytes/token, this is effectively streaming memcpy — bandwidth-bound,
  not latency-bound.
- Identifier tokens in the copied range need `prev_offset` and
  `next_offset` adjusted by the copy delta (`new_pos − old_pos`). Since
  they were resolved against the call-site scope when originally emitted,
  their targets haven't moved — only their position has. So the patch is:

  ```
  new_prev_offset = old_prev_offset + (old_pos − new_pos)
  new_next_offset = old_next_offset + (old_pos − new_pos)
  ```

  That is a single add per offset per identifier token. For a typical
  lazy arg of ~10 tokens with ~3 identifiers, we're talking about ~6
  adds plus a streaming copy. Negligible.

- **Use-chain stitching.** Trickier: the call-site chain may have
  `next_offset` pointers from earlier references into this copied range
  (if the lazy arg references a variable also referenced elsewhere).
  When we copy the range, any `next_offset` in *earlier* tokens that
  pointed into the old range now dangles. And any `next_offset` in the
  copied range that pointed *outside* needs its delta adjusted (same
  formula as above). Fixing dangling outside-in `next_offset`s requires
  one more step:

  After copy, for each identifier in the copied range, walk its
  `prev_offset` one hop. If that prev token is outside the copied range,
  patch *its* `next_offset` to point to the new copy position. This is
  one additional write per identifier in the copy range — still cheap.

- **If the lazy arg is never spliced** (dead-branch-in-template case):
  the arg tokens remain in the call-site paren chain as dead code.
  Codegen's constant-propagation / DCE pass (future) will elide them.
  No active cleanup needed at expansion time.

- **If the lazy arg is spliced multiple times** — prohibited by the
  "exactly one use per lazy param" rule validated at definition time.
  The chain copy logic assumes at most one splice consumer per lazy arg.

---

## 6. Splice → param-index lookup (revised)

Given an `ident_splice` token in the body template, derive its lazy-param
index:

1. Follow `prev_offset` → lands on the lazy param's declaration token
   in the definition's param chain.
2. The param declaration sits at `def_sep_idx + 1` for some separator.
   Read the preceding `sep_comma` (or `grp_open_paren` for slot 0).
3. That separator's `arg_idx` field (for `sep_comma`) directly gives
   the slot index. For the `grp_open_paren` case, slot is 0.

One extra load compared to revision 1's "subtract from header base"
approach, but it works with variable-length param declarations (type
annotations, default values — `param : Type = default` spans multiple
tokens), which revision 1's subtraction did not.

---

## 7. Hard caps — what scales now

Under revision 2:

- **Parameter count** is capped by the `u16` `arg_cnt` field on the
  paren token — 65535. In practice, the practical limit is much lower
  (call conventions, readability), but the data structure does not
  impose an artificial one.
- **Body length** is already `u32`, unchanged — 4 billion tokens.
- **Lazy arg nesting** (macros inside macros inside macros) is still
  unguarded — inherits today's limitation.
- **Indent-fixup stack** remains at depth 4 as it does today. Changing
  this is orthogonal to N-ary work.
- **`saves` stack** for per-expansion declaration-slot restoration:
  sized to match the paren-chain's `arg_cnt`, but eager-param-only.
  Needs to be dynamic (heap or per-expansion arena) only if we want no
  cap at all. A fixed cap of 32 eager params would cover all realistic
  uses at 256 B of stack; Sir's call on whether to grow dynamically.

### Recommendation on the `saves` cap

Stack-allocated `[32]SaveSlot` at 8 B each = 256 B per expansion frame.
Generous, deterministic, stack-only. Error on N_eager > 32 at call
site. This is still ample headroom — any fn with 32 eager parameters
is almost certainly a code smell.

If Sir prefers zero caps, the alternative is: allocate saves from a
per-parse arena that resets at the end of parsing. Still O(1) amortised
per slot, no per-expansion syscalls. The complexity addition is a small
arena type. Happy to pursue either.

---

## 8. Stress-testing (revised cases)

Most cases from revision 1 carry over. New wrinkles:

**N = 0 call.** `f()`. `grp_open_paren.arg_cnt = 0`, so the chain goes
`( → )` directly with no `,` between. The expansion core's slot loop
runs zero times. Body walk proceeds unchanged. Correct by construction.

**N = 1 lazy.** `f(MAYBE_X)`. One lazy slot, one splice in body, copy
path runs once. Fine.

**Nested paren chains in body.** `fn WRAP(A, B): g(A, h(B))` — the body
contains two paren groups. Each maintains its own chain during
definition-time parsing. During expansion walk, the walker emits these
paren tokens and maintains a *local* chain-tail stack for any nested
paren groups *inside the body*. The walk's chain-tail stack is
stack-local, sized at some reasonable depth (say 8). Hard error on
overflow.

**Paren-chain disruption by a splice.** When a splice replaces an
`ident_splice` token that sits inside a nested `( … )` in the body,
the spliced tokens may themselves contain paren groups. Those groups'
chains are already correctly self-contained in the original lazy-arg
emission (step 3 of prefix collection). The copy patches offsets but
does not disturb the internal structure of the copied range. The
enclosing body-local paren chain (the one *around* the splice point)
must be extended: the chain-tail that was about to connect to the next
`,` or `)` now has a larger gap to cross. This is handled because chain
offsets are patched at emission, not in advance — the next `,` or `)`
emission picks up the current write position, which is already past
the spliced tokens.

**Every arg lazy.** `IFTE(a, b, c)` with all three lazy. Expansion
emits zero synthesised param decls (no eager slots), zero saves,
three splice points in the body. Clean.

**Adversarial param count.** N = 1000. `arg_cnt: u16` accommodates it.
Chain walk is O(1000) loads, sequential-adjacent, still well under a
millisecond. Not a performance concern. If Sir caps `saves` at 32 and
N_eager exceeds that, hard error; otherwise fine.

---

## 9. Trade-offs (revised)

The paren-chain approach is a net win over revision 1 on every axis I
can identify:

- **Simpler**: no bespoke `skimArg` helper, no operand-descriptor array,
  no fn_header metadata bitmask.
- **More scalable**: no N ≤ 8 cap.
- **Better-aligned with future work**: type annotations and default
  values (`param : Type = value`) land naturally — the param name is
  always at `sep_idx + 1`, regardless of what follows it.
- **Cleaner kind hygiene**: `kw_lazy_fn` and `ident_splice` are kinds,
  not flag bits. Flag space is preserved for genuinely orthogonal
  signals.

The cost:

- parsedQ grows by `(2N + 1)` tokens per paren group (N args → N commas
  +1 each for `(` and `)` — actually `(N + 1 + N = 2N + 1)` is wrong;
  it's `1 + (N − 1) + 1 = N + 1` tokens for a group of N args, or
  just `2` for nullary. For a realistic program with many small calls,
  this is a modest expansion of parsedQ — perhaps 10–15% larger overall.
  Offset by simpler codegen and no skim helpers.
- Every handler that walks parsedQ now sees paren tokens and must skip
  them. Minor.
- The in-place offset patching during lazy-arg copy requires careful
  testing to ensure dangling `next_offset`s are correctly stitched.

---

## 10. Recommendation

**Adopt revision 2.** The paren-chain idea is structurally the right
move — it's the data-oriented answer to "how do we navigate variable-
shaped parameter lists without metadata bloat?" The answer Sir proposed
(preserve structure tokens and link them) is cleaner than any scheme
that tries to compress the information into a fixed field.

On the edge question of whether infix-2 unifies with the prefix path via
a synthesised paren wrapper: mild preference for unification (one code
path, fewer tests). Happy to leave it as two handlers if risk aversion
on the infix path dominates.

**Decisions still warranting explicit confirmation, Sir:**

1. **`saves` cap: 32 with hard error, or dynamic via parse-arena?**
   Either is defensible; 32 is simpler, arena is more uniform with
   "no arbitrary caps" principle.
2. **Infix-2 unification via synthesised paren wrapper, or two
   distinct handlers sharing the expansion core at a deeper seam?**
   First is slightly tidier, second preserves the infix path exactly
   as today.

Everything else I'm confident enough to turn into a spec.

---

## 11. Implementation sketch (revised)

### At initialisation
No new state.

### Per-expansion stack frame
```
saves:             [32]{sym_id: u16, prev_tail: u32}
save_count:        u16
slot_operand_map:  [N?]u32   // for lazy slots only; index into call-site
                             // paren chain giving each slot's operand start
fixup_stack:       [4]u32
fixup_depth:       u8
body_chain_stack:  [8]u32    // chain-tail stack for paren groups within
                             // the body walk
body_chain_depth:  u8
```

The `slot_operand_map` is logically present but under revision 2 is
redundant — the call-site paren chain already maps slot → operand
position. We can skip this array entirely and do chain walks on demand
at splice time. Chain walks are N steps, but splices are rare, and we
avoid carrying per-expansion state.

So the expansion frame is actually just: `saves`, `save_count`,
`fixup_stack`, `fixup_depth`, `body_chain_stack`, `body_chain_depth` —
about 320 B worst case.

### Wiring

- **Paren-chain emission** added to `groupParen`, `callExpr`, `kwFn`,
  and any other handler that today consumes paren tokens. One shared
  helper.
- **`kwFn`** emits `kw_lazy_fn` instead of `kw_fn` when ≥1
  `const_identifier` param is observed. Rewrites each lazy-param
  reference in the body to `ident_splice` kind during its splice-flag
  pass (renamed: splice-*kind* pass).
- **`callExpr`** dispatches three ways: resolved-to-`kw_lazy_fn` →
  template expansion (mixed collection via paren chain);
  resolved-to-`kw_fn` → legacy runtime-call path (unchanged from today,
  emits `call_identifier` after eager arg parse); anything else →
  legacy path (builtin / syscall).
- **`opIdentifierInfix`** becomes a thin wrapper that builds a
  synthetic call-site paren chain around the left operand and the
  pending right operand, then delegates to the shared expansion core.
  (Or remains its own handler, per the open question above.)
- **`expandTemplate`** is the shared core: takes `decl_idx` and
  `call_paren_idx`, walks param-chain for classification, synthesises
  eager-param bindings, walks body with splice/re-resolve/fixup/copy
  dispatch.
- **Codegen** gains a "skip structural token" case for `grp_open_paren`,
  `sep_comma`, `grp_close_paren` in the main switch. No semantic work.
  Also a clause for `ident_splice` with `flags.declaration = 1`:
  "bind the declaration to the register currently on top of the register
  stack; do not allocate." The existing `call_identifier` handling
  remains unchanged — pure-eager user calls still arrive here and use
  whatever runtime call convention is in place (today, the syscall
  heuristic; future work to generalise).

### Key links where this is most likely to break

1. **Lazy-arg copy with embedded identifiers.** Offset patching must
   handle all three directions: in-range-to-in-range (offsets unchanged),
   in-range-to-out-of-range (offset delta applied), out-of-range-to-in-
   range (the earlier `next_offset` needs stitching to the new copy
   position). This is the most intricate piece of the implementation.
2. **Nested paren chains during body walk.** The walker's local
   chain-tail stack must be correctly maintained across recursive-
   looking token sequences. Testing should include deeply nested body
   templates.
3. **Infix-2 adapter (if unified).** Synthesising a paren chain around
   the already-emitted left operand means inserting `grp_open_paren`
   *before* the left operand retroactively. Doable only by shifting the
   left operand forward by one slot — which is the exact thing Sir's
   design note says we want to avoid. So: either the unification is
   done by emitting the paren chain *after* the left operand (with the
   left operand positioned as if it were at `open_paren + 1` despite
   the physical layout being different), or the infix handler remains
   non-unified. Leaning toward the latter given Sir's guidance.

So on reflection, **two distinct handlers is the right call**. Revision
2's core delegates from `callExpr` only; `opIdentifierInfix` keeps its
own minimal 2-param handling that shares low-level helpers (like
splice-copy) but not the collection pipeline. That resolves open
question 2 above.

---

## 12. Remaining unknowns

- **`saves` cap**: 32 or dynamic arena? Slight preference for 32 given
  Informal's existing "fixed caps, hard errors" style, but Sir may
  prefer arena for uniformity.
- **Lazy-arg copy depth limit**: if a lazy arg itself contains a
  (future) macro call, the copy will pull in a macro expansion's
  output. Since the expansion happened at the call site *before* the
  copy, this should just work — expansion is call-site time, copy is
  walk time. Still, worth a dedicated test.
- **Recursive macros**: deferred, unchanged from revision 1.
- **Pure-eager user calls** continue through the legacy
  `call_identifier` runtime-call path. Generalising that path beyond
  the current syscall-shortcut heuristic is separate future work,
  explicitly out of scope for this design.

---

*This revision represents the design as it should be implemented,
subject to confirmation on the two decisions in §10. Ready to be turned
into a detailed spec for Claude Code.*
