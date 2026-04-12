# N-ary Inline Expansion — Problem Definition

**Status:** problem framing only. No design. Open questions below are the point.

## Context

Today, inline expansion is hardwired to two-parameter functions used as infix
operators:

- `parser.zig:431` — `opIdentifierInfix` asserts `paramCount == 2` after
  reading the `kw_fn` header. It reads exactly two param decls at
  `declIndex + 2` and `declIndex + 3`, classifies each as eager vs lazy by
  `kind` (`identifier` vs `const_identifier`), and dispatches to one of two
  hardcoded branches: pure-eager (both operands fully evaluated, two splice-
  flagged synthesized decls) or one-eager-one-lazy (left operand only, walker
  parses the right operand at the single splice point).
- `parser.zig:386` — `kwFn`'s lazy detection is
  `isLazy = eagerCount == 1 and lazyCount == 1`. Splice stamping reads the
  single lazy param decl's `next_offset`, asserts `!= 0`, stamps the use, and
  asserts the use's `next_offset == 0` (exactly one use).
- `fn_header.metadata` (16 bits): bit 15 = lazy flag, bits 0-7 = param count,
  bits 8-14 reserved (`parser.zig:398`, `token.zig:143`).
- `callExpr` (`parser.zig:264`) already parses `name(a, b, c, …)` as a prefix
  expression and emits the `call_identifier` in postfix. Codegen's only
  consumer of `call_identifier` is a hardcoded two-arg syscall path
  (`codegen.zig:275`) — there is no wiring today that maps
  `call_identifier` back to a fn_header for either a runtime call or a
  template expansion.

The ask is to generalise both handlers to arbitrary parameter counts while
keeping the existing two-operand infix syntax intact. Before designing, the
shape of the problem needs to be pinned down.

## Goal

A user should be able to define a function with any N and any mix of eager
and lazy parameters, and invoke it in whatever form(s) the language chooses
to support, with correct inline expansion at every call site that takes the
macro path. The existing two-param infix call syntax must still work exactly
as it does today.

## What is unambiguous

- `kw_fn` already emits N param decls regardless of N; the header's
  `paramCount` field is 8 bits, which is more than enough. The template in
  `parsedQ` is already position-indexed at `declIndex + 2 + paramCount`
  onward. None of this needs to change for N > 2.
- Body-template walking (`walkBodyTemplate`) is already N-agnostic for the
  copy / re-resolve / indent-fixup paths. The only N-specific behaviour is
  at splice points, which today encode "parse the single right operand".
- Re-resolution uses existing `resolution.resolve()` machinery regardless of
  how many params there are. No scaling problem there.
- The save/restore of `declarations[sym]` across an expansion is
  straightforward to extend from 1-2 entries to N entries (stack-local
  buffer sized to N, or a small fixed cap like 8).

## Open questions

Answering these — or explicitly deferring them — is a prerequisite to
picking an implementation shape.

### Q1. What call syntaxes are in scope?

Three candidate surfaces. The generalisation looks different depending on
which of these we admit.

1. **Prefix call, all eager:** `name(a, b, c)`. Parses via `callExpr` today.
   Not currently wired to fn_header / template expansion — `call_identifier`
   is opaque to codegen except for the syscall shortcut. Open: does the
   generalised design route user-defined eager calls through template
   expansion here, through a real runtime call convention, or both?

2. **Prefix call, mixed eager/lazy:** `name(a, b_expr, c, d_expr)` where
   `b_expr` and `d_expr` are captured unevaluated. Does this syntax exist
   at all, or is mixed-laziness only reachable through macro-building forms
   (e.g. a macro whose body itself uses `op_identifier` against another
   macro)? The specs cover only infix for lazy; nothing says what a
   call-site for a mixed N > 2 function looks like.

3. **Infix with N > 2:** `a OP (b, c)` or similar. Could be read as
   "left operand is param 0, remaining operands follow in parens". No syntax
   for this exists today. Do we want one, or is infix frozen at N == 2?

Decision needed before any design work. If (3) is out and (2) is macro-only,
the infix handler's assert stays valid for any infix call and the whole
generalisation becomes a `callExpr`-side problem.

### Q2. Two-param infix as a special case — preserve how?

Once N-ary is in, the handler must still take the two-operand infix path on
`a OP b` without penalty. Two ways to preserve it:

- **Dispatch on paramCount inside `opIdentifierInfix`**, with a dedicated
  fast path for `paramCount == 2`. The existing code is this fast path.
- **Only accept infix for paramCount == 2**, and route N > 2 through the
  prefix path (`callExpr`). The assert stays; a separate N-ary path lives
  elsewhere.

The second option keeps each handler simple but splits the expansion logic
across two sites. The first keeps one site but grows an N-ary branch. Open.

### Q3. With multiple lazy params, how does the walker know which operand
        each splice consumes?

Today there is exactly one lazy param and one splice in the body, so the
walker's splice action — `parse(power(opToken) + 1)` from `syntaxQ` — has
only one possible operand to consume. With K > 1 lazy params the walker
needs to know, at each splice, which lazy param index it corresponds to,
because each param is bound to a different argument slot.

Sub-questions:

- At the splice point, is the operand still pending in `syntaxQ` (as it is
  today for infix's single right operand), or have all lazy args been pre-
  buffered in some other form at the call site (range of syntaxQ indices,
  captured aux offsets, etc.)?
- If buffered: where does the buffer live? A heap allocation is an abrupt
  departure from the current "24 bytes of stack state" invariant.
- If still pending in `syntaxQ`: what forces evaluation order to match the
  walker's encounter order? The macro body decides the encounter order, but
  `syntaxQ` has the source order. They only coincide by coincidence today
  (one lazy means one of each).
- How does a splice token identify its lazy-param index? Candidates:
  - The param index is encoded directly on the splice token (spare bits in
    flags, or reuse an identifier-token field). Fixed cost per splice.
  - The walker does a one-hop through `prev_offset` to the param decl, and
    recovers the param's position within `[declIndex+2 .. +2+paramCount]`
    by subtracting indices. Zero extra storage; one extra load per splice.

### Q4. What is the splice-counter invariant under multiple lazies?

Current rule (inline-expansion-spec.md §"Open Questions" and §"Invariants"):
exactly one use of the single lazy param in the body. Natural generalisation:
exactly one use of *each* lazy param.

Open:

- Is "exactly one" still the right rule? A macro like
  `fn WHEN(COND, THEN): if bool(COND): THEN else: null` has each lazy used
  once. But macros like `fn IFTE(COND, THEN, ELSE): if bool(COND): THEN else: ELSE`
  also have each used once, and that's the natural shape. So "exactly one
  per lazy" likely still holds.
- What's the error message for "lazy param used zero times" versus "used
  twice" when there are multiple lazies? The per-param distinction matters
  for the diagnostic; today's code only needs to say "the lazy param".
- Does the single-use rule need to relax for conditional use (splice in
  only one branch of an `if`)? The current 1-lazy macros already sidestep
  this because the one use is typically the result of a conditional. With
  N lazies, each on a different branch, the invariant becomes "textually
  exactly one use" rather than "dynamically executed exactly once". Worth
  confirming that "textually one" is what we mean today, not "executed one".

### Q5. Does `fn_header.metadata` need to grow?

Two representable choices within the existing 16-bit metadata field:

1. **Keep 8-bit paramCount. Recover per-param kind at expansion time** by
   re-reading `parsedQ[declIndex + 2 .. declIndex + 2 + paramCount]`. The
   kind byte of each decl already encodes eager (`identifier`) vs lazy
   (`const_identifier`). Cost: N extra loads at each expansion site, all
   adjacent to the header — likely already in cache after the header read.
   No schema change. This is closest to what's there.
2. **Pack a per-param lazy bitmask** into the reserved bits (bits 8-14 give
   7 bits; enough for up to 7 params with per-param kind in the header, or
   14 bits if bit 15 is repurposed). Cost: caps N at ~7-14 cheaply, or
   forces a spill if N exceeds the bitmask. Avoids the N sequential decl
   reads at expansion time.

The first choice is data-oriented: don't duplicate what the decl tokens
already encode, and trust that the linear read through those tokens is
cache-friendly. The second choice is latency-oriented: the expansion-time
fast path wants a single-load classifier. Open which matters more; depends
on whether expansion is on a hot path for the common shapes.

Separately: the lazy flag (bit 15) is currently a single bit. With multiple
lazy params, "is this function a macro?" generalises to "does this function
have any lazy params?". The bit is still meaningful — it gates whether the
expansion path runs at all — but the name should change. Keeping the bit is
cheap; removing it forces every opIdentifierInfix to re-derive from param
kinds, which defeats the header's purpose.

### Q6. Does the call-site splice flag stay overloaded?

Today `flags.splice` means two things depending on context:

- **On body-template identifier tokens (definition time):** "when the
  walker sees me, parse the right operand from syntaxQ and emit its tokens
  here."
- **On synthesized param decl tokens at the call site (expansion time):**
  "codegen, don't allocate a fresh register; bind this decl to the stack-top
  value left by the preceding operand."

These never coexist in the same region of `parsedQ`, so the overload is
safe. Open: under N-ary, does the second meaning still hold for all param
slots the same way? For eager-infix with N > 2, all N synthesized decls
would carry splice=true, each binding to its own stack-top operand. That is
a straightforward generalisation. For prefix calls with N > 2, the same
applies if the convention remains "operands already on the stack by the
time the decl is declared". Worth confirming before relying on it.

### Q7. What limits does stack-local state impose?

Current walker uses `[4]u32` fixup stack for indent/dedent pairs plus a `u8`
depth counter — 24 bytes total. An N-ary generalisation may need:

- Save/restore buffer for up to N param decls' `declarations[]` entries.
  Fixed cap (say 8) vs grow-on-demand.
- If lazy args are buffered rather than consumed at their splice points, a
  per-arg buffer of syntaxQ index ranges, size K (lazy count).

Both are small. Open whether we pick a fixed cap ("macros have at most 8
params") and fail loudly above it, or allocate on the heap above some
threshold. The existing project style prefers fixed caps with hard errors.

### Q8. What is the interaction with codegen?

Today codegen processes the expanded tokens uniformly — it doesn't know an
expansion happened. This holds as long as expansion produces valid postfix
with correct offsets, which the walker already guarantees. But:

- The current syscall shortcut in codegen (`codegen.zig:275`) fires on any
  `call_identifier`, which would collide with a user-defined function's
  call site if we route prefix calls through `callExpr` + template
  expansion. Does the expansion of a prefix call produce a `call_identifier`
  at the end, or does it replace it entirely? If the former, codegen needs
  to distinguish user calls from syscalls. Today that distinction is
  `flags.declaration` for the syscall shortcut (a heuristic).
- If instead prefix N-ary eager calls are expanded in the parser (like
  infix today), the `call_identifier` token emitted by `callExpr` gets
  consumed / replaced during expansion. The expansion plan for prefix
  differs structurally from infix because `callExpr` runs as a *prefix*
  handler (operands parsed before the function name is emitted) whereas
  `opIdentifierInfix` runs as an *infix* handler (left operand already in
  `parsedQ`, right operand unconsumed).

### Q9. Recursion and macro-within-macro

Noted as an existing limitation (parser-spec.md TODOs). With N-ary lazies
a macro body can contain `op_identifier` calls to other macros, or to
itself. The walker currently has no recursion guard. This is not *new*
under N-ary, but N-ary makes the likelihood higher (more splice sites, more
opportunities for macro-calling-macro patterns). Open: do we need a depth
cap for N-ary, or keep deferring?

## Summary of decisions needed before design

1. Which call surfaces admit N-ary (infix, prefix eager, prefix mixed)?
2. Does infix stay 2-only, or does it grow an N-ary form?
3. Where does a lazy operand live between the start of expansion and the
   walker reaching its splice point — `syntaxQ` (as today) or a per-call
   buffer?
4. How does a splice token carry its lazy-param index (encoded vs derived)?
5. Does `fn_header.metadata` stay 16 bits / 8-bit paramCount, or grow a
   per-param kind bitmask?
6. What is the fixed cap on N (if any), and what's the failure mode above
   it?
7. How do prefix-call expansions interact with codegen's `call_identifier`
   syscall path?
