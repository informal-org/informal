# IR Spec

## Overview

The IR is a hybrid of sea-of-nodes, SSA, and continuation-passing style with
one notable encoding twist: **IR nodes do not carry a kind tag**. Instead,
every kind owns a reserved contiguous range in a single backing array
(`IRQueue.list`), so a node's kind is recovered from its index via a small
inverted-index lookup.

Properties this buys us:

- **1 byte saved per node** — no per-node kind discriminator.
- **Iteration by kind is free** — "walk all stores" is a slice over the store
  range.
- **Sorting within a kind range is valid** — opens up cheap canonicalization
  and CSE-style passes within a kind.
- **Cheap kind classification** — given any index, `indexToKind(i)` is one
  shift + bitset peek in the common case.

Lowering walks the parser's postfix `parsedQ` with an explicit value stack
and emits IR nodes into pre-reserved per-kind ranges. A side `Blocks` table
records, per logical block, which kinds appear and where each kind's run
ends, using two 64-bit masks per block.

This spec covers:

- `ir.zig` — the lowering walk from `parsedQ` to IR
- `irq.zig` — the `IRQueue` container and the 64-bit `Node` layout
- `irq/kind_ranges.zig` — per-kind reservation and `indexToKind`
- `irq/blocks.zig` — per-block kind/end masks and the block iterator

Sequence scheduling (`sequence.zig`), the dependency map (`depmap.zig`), and
register allocation (`regalloc.zig`) get their own specs.

---

## Node Layout (`irq.zig`)

Every IR node is 64 bits. Two interpretations are exposed through a packed
union:

```zig
Node = packed union {
    raw:  u64,
    args: packed struct { left: u32, right: u32 },
}
```

There is no `kind` field on the node — kind is derivable from the node's
index (see Kind Ranges). The two views are interchangeable bitwise; pick
the one that matches the node's semantic role:

- `args(left, right)` — generic two-operand node (operator with two operand
  indices, enter/exit linkage, frame `(argIndex, argCount)`, param
  `(argTail, refTail)`, arg `(value, prevArgIndex)`).
- `raw` — a 64-bit literal value stored inline (planned use for large
  constants).

**Argument convention.** First arg is the primary value; second is the
secondary value or linkage. For binary ops this is `(leftOperandIdx,
rightOperandIdx)`. For enter/exit it is `(enterIdx, otherEndIdx)`. For
frame/param/arg see Frames below.

`args(left, right)` is the canonical constructor; `pushArg` and the value
stack also store `Node.args` values, with `left` used as the
just-emitted-node index and `right` as a tag / parser index.

---

## Kind Ranges (`irq/kind_ranges.zig`)

Up to 64 distinct token kinds are mirrored into the IR. `KIND_COUNT = 64`
is the same fixed prefix the parser uses, so we can index by
`@intFromEnum(TK)` directly.

### Reservation

`reserve(kindCounts: [64]u32)` lays out kinds end-to-end in a single index
space:

```
kind 0:  [0          .. count[0]                 )
kind 1:  [count[0]   .. count[0] + count[1]      )
kind 2:  [...                                     )
...
kind 63: [...        .. total                     )
```

Per-kind state is stored in a 64-entry table of `Range { cursor: u32, end:
u32 }`:

- `cursor` — next free slot inside the kind's range; advanced by
  `nextIndex(kind)` on each emit.
- `end` — fixed upper bound; `nextIndex` asserts `cursor < end`.

`reserve()` returns the total length so the backing list can be sized once.
After lowering, `cursor == end` means the kind's reservation was exactly
consumed (no holes); under-consumption leaves trailing zero nodes inside
the kind's slice.

### Reverse Lookup: `indexToKind(index)`

A linear scan over 64 ranges would dominate hot paths, so we maintain a
small inverted index:

- Slice the index space into `INDEX_KIND_MAP_BUCKET_COUNT = 32` buckets.
- Bucket width is `ceil(total / 32)` rounded up to the next power of two,
  so `index >> indexKindMapWidthShift` is the bucket index (one shift, no
  division). The round-up can leave the top buckets unused, but every valid
  index stays in bounds.
- `indexKindMap[bucket]` is a `KindBitSet` (u64) of which kind indices have
  any reserved entry overlapping that bucket.

Lookup procedure for an index:

1. `mapIndex = index >> shift`
2. Fast path: if `indexKindMap[mapIndex].count() == 1`, that one bit is the
   kind.
3. Slow path: iterate the bits of `indexKindMap[mapIndex]` (≤ a handful, by
   construction) and return the one whose `[start, end)` contains the
   index.

`buildIndexKindMap` is called once at the end of `reserve()`. It walks each
kind's range and sets its bit in every bucket it touches.

### Helpers

- `cursor(kind)` — next index to be emitted (used to capture the
  pre-emission index when chaining frames/params/args).
- `emittedCursor(kindIndex)` — same, by integer index.
- `reservedStart(kindIndex)` — stable start of the kind's range (derived as
  the previous kind's `end`; `cursor` is *not* a stable start because it
  moves).
- `reservedLen(kindIndex)` — `end − reservedStart`.
- `relativeIndex(kindIndex, index)` — `index − reservedStart`, with bounds
  asserts.

---

## Blocks (`irq/blocks.zig`)

A block is a logical scope produced during lowering. The IR opens one block
per parser scope plus a final continuation block (see Lowering). The block
table is purely structural metadata; it does not own nodes.

### Per-Block State

```zig
Block = struct {
    kinds: KindBitSet,  // 64-bit: which kinds appeared in this block
    ends:  KindEndSet,  // 64-bit: which local positions are kind-run ends
}
```

- `kinds` — bit *k* set iff at least one node of kind *k* was emitted into
  this block. Iterating set bits walks the kinds in the same order as the
  global kind range layout (low kind index first).
- `ends` — operates on the block's *local* index space (0..blockLen). Bit
  *i* set iff local position *i* is the **last** position of some kind's
  run inside the block. Block length is implicit:
  `blockLen = 64 − clz(ends.mask)`.

The block layout is "kind-major": within a block, all nodes of kind *k*
appear contiguously, in the same relative order as the kind range. The
i-th set bit in `kinds` corresponds to the i-th set bit in `ends`. That
1:1 alignment is what makes the iterator's local↔absolute conversions
cheap.

Per-block storage is 16 bytes (two u64 masks). Both masks fit in 64 bits
because at most 64 kinds can appear in a block (one per bit) and we cap
total nodes per block at 64 (so `ends` is addressable).

### Building Blocks During Emit

- `activeKindStarts: [KIND_COUNT]u32` — scratch table for the currently
  in-progress block. When a kind is first seen in the block,
  `markActiveBlockKind` records the kind's *absolute* cursor as the run
  start.
- `markActiveBlockKind(kind, index)` is called by every `IRQueue.emitKind`
  — it sets the kind bit on the active block and stamps
  `activeKindStarts[kindIndex] = index` (only on first sight in the
  block). If the active block is already closed (`ends.mask != 0`), the
  call is a no-op.
- `endBlock(kindRanges)` walks the just-finished block's set kinds in
  order; for each one it diffs the current emit cursor against
  `activeKindStarts[kind]` to recover the run length, accumulates a
  running local end, and sets that bit in `ends`. Asserts each run is
  non-empty and `localEnd ≤ 64`.

`blockCount()` excludes a trailing empty block (an opened but not-yet-
ended block left in the list) so partial state during lowering remains
consistent for callers.

### Block Iterator

`Iterator(Queue)` walks completed blocks and answers local↔absolute index
queries:

- `initIterator(queue)` — seeds every kind's `(start, end)` at its reserved
  range start (an empty run at the kind's beginning).
- `nextBlock()` — for each kind set in the current block, advances
  `kindBlockRanges[kindIndex]` to `(start = prev.end, end = start +
  runLen, localBase = runningLocalStart)`. `runLen` is recovered from the
  `ends` bitset by differencing consecutive set bits.
- `kindIterator()` — iterates kinds in the current block in kind-range
  order.
- `blockRange(kind)` — absolute `[start, end)` of `kind` inside the
  current block (asserts the kind appears in the block).
- `blockLen()` — `64 − clz(ends.mask)`.
- `toBlockRelativeIndex(absIndex)` — given an absolute index, find its
  kind via `indexToKind`; if the kind is in this block and the index is
  inside its block range, return `localBase + (absIndex − start)`; else
  null.
- `toAbsoluteIndex(localIndex)` — count the `ends` bits strictly below
  `localIndex` via `popcount(lowBits(localIndex) & ends.mask)` — that's
  the ordinal of the kind inside the block. Find the corresponding kind
  via `kindIndexForOrdinal` (iterating set bits of `kinds`) and convert.

`kindIndexForOrdinal` uses an iterator + counter rather than a branchy
`selectSetBit`-style helper; a 50M-iteration benchmark (2026-05-24)
measured 5.249 ns/op vs 8.847 ns/op for the alternative.

---

## Lowering (`ir.zig`)

`IR.lower()` walks `parsedQ` (postfix order, produced by the parser) with
an explicit value stack and emits into `irQ`. Postfix order means operands
appear before their operator, so a stack-based walk works without
recursion.

### Walk

```
startBlock                           // root block
for each token in parsedQ:
    aux_stream_start         -> skip
    grp_indent / grp_dedent  -> endBlock; startBlock
    lit_number               -> emit literal; push index
    op_add / op_mul          -> popBinary; emit op; push index
    else                     -> error.UnsupportedIRKind
endBlock                             // returns final exitIdx
```

Currently only literals and `op_add` / `op_mul` are wired. Other parser
kinds will land as the IR grows.

### Block Bracketing (`startBlock` / `endBlock`)

Each block is bracketed by an `ir_enter` / `ir_exit` pair so the rest of
the pipeline sees blocks-with-params (the CPS/actor framing). Today these
are placeholders; they will carry continuation linkage as the IR matures.

- `startBlock`:
  1. Append a fresh `Block { kinds: empty, ends: empty }` to the block
     table.
  2. Emit an `ir_enter` node with placeholder linkage (`enterIdx` in both
     args).
  3. Push a **block sentinel** onto the value stack — an `args(enterIdx,
     BLOCK_SENTINEL_ARG)` marker. `isBlockSentinel` recognizes it by
     `right == maxInt(u32)`.

- `endBlock`:
  1. Pop the top of the value stack. If it's the sentinel, the block had
     no result; otherwise pop again to consume the sentinel.
  2. Emit an `ir_exit { enterIdx, resultIdx }`.
  3. Call `Blocks.endBlock` to finalize the block's `ends` mask.
  4. Return the `ir_exit` index.

### Kind Count Reservation

`IR.calcKindCounts(parserCounts)` transforms parser-side kind counts into
IR-side counts. Today the transform is small:

- `ir_enter` and `ir_exit` counts each grow by `1 + #grp_indent +
  #grp_dedent` — one bracket pair per parser scope boundary plus the root
  block.
- `grp_indent` / `grp_dedent` counts are zeroed (they don't appear as IR
  nodes; they're consumed as block delimiters).
- Other kinds carry through 1:1. As the IR grows, kinds where a single
  parser token expands into multiple IR nodes will sum their sources here.

`IR.reserve(kindCounts)` forwards to `IRQueue.reserve`, which:

1. Asserts `ir_enter` and `ir_exit` counts match.
2. Zeroes the count for `ir_block_map` (reserved but unused so far).
3. Calls `KindRanges.reserve` to compute the total length and per-kind
   starts.
4. Sizes `list` to the total length and pre-fills with zero nodes (writes
   land into reserved slots by absolute index, not by appending).
5. Sizes `stack` to `maxDepth` and reserves block-table capacity for the
   number of `ir_enter` slots.

### Value Stack

The lowering value stack stores `Node.args` entries `(emittedIdx, parserIdx
or sentinel)`. `pushArg(left, right)` pushes; the `right` slot carries the
originating parser index for diagnostics today and may carry other tags
later. `popBinary` pops two and returns `args(left.left, right.left)` —
i.e. the two operand indices, ready to be emitted as the binary op's
`Node.args`.

### Frames, Params, Args (helpers, not yet wired by `lower`)

For n-ary calls (deferred to a future IR change), three helpers are in
place:

- `createFrame(argCount)` — emits an `ir_frame` node `args(argIndex,
  argCount)` where `argIndex` is the cursor of `ir_arg` at frame creation
  time. The frame implicitly owns the next `argCount` `ir_arg`s.
- `createParam()` — emits an `ir_param` node `args(paramIndex, 0)` whose
  `left` field doubles as the head of an arg list (the "arg tail"). Params
  are the IR's phi-equivalent: one declaration site, many incoming values.
- `createFrameArg(paramIndex, value)` — emits an `ir_arg` node
  `args(value, prevArgTail)` and updates the param's `argTail` to point at
  the new arg. This threads all args for a param into a singly-linked
  list, latest-first.

The current `lower()` doesn't call these — it only handles literals and
binary ops — but they are exercised by tests and pin down the shape of
future call lowering.

---

## Sentinels and Reserved Values

- `BLOCK_SENTINEL_ARG = maxInt(u32)` — value-stack marker for an open
  block; lets `endBlock` distinguish "block had a result" from "block was
  empty". Recognized by `isBlockSentinel(node)` checking `args.right`.
- `ir_block_map` kind is reserved (count zeroed in `reserve`) for future
  use.

---

## Out of Scope

Specs that cover the rest of the IR pipeline:

- **Sequence + Depmap** — see `ir_sequence.md`. Covers `depmap.zig`
  (per-block dependency / reference bitsets) and `sequence.zig` (layered
  scheduling).
- **Register allocator** (`regalloc.zig`) — register assignment over the
  scheduled IR. Spec pending.
