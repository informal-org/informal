# IR Sequence Spec

## Overview

After `ir.zig` has lowered `parsedQ` into the IR queue, the IR is still in
*kind-major* order — within each block, nodes are grouped by kind, not by
dataflow. Two passes turn that layout into an executable schedule:

1. **`depmap.zig` — DepMap.** For every node in every block, record which
   other nodes it depends on and which nodes reference it, in **block-local
   bit positions** (one 64-bit mask per node).
2. **`sequence.zig` — Sequence.** Walk each block backward from its output
   node and emit "layers" — sets of nodes whose dependencies are already
   satisfied — until every transitively-used node is scheduled.

The result is a per-block linearization expressed as a stream of `BitSet64`
layers, plus a per-block length count. Each layer is a set of nodes that
have no dependency on each other and whose deps are already produced; the
backend is free to emit them in any order within the layer (and any
allocator that wants ILP can use that fact).

Dead nodes — anything not transitively reached from a block's `ir_exit`
output — are silently dropped. Structural nodes (`ir_enter`, `ir_exit`)
participate in `DepMap` but are not pulled into the schedule unless
something else depends on them, which today nothing does.

This spec covers:

- `depmap.zig` — per-block dependency / reference bitsets
- `sequence.zig` — layered scheduling driven off `DepMap`

It builds on `ir.md` (lowering, kind ranges, blocks). Register allocation
(`regalloc.zig`) consumes a `Sequence` and gets its own spec.

---

## Block-Local Coordinates

Both passes work in a 64-bit-per-node namespace local to one block:

- A block has `blockLen ≤ 64` nodes. Local index `i` (where `0 ≤ i <
  blockLen`) is the i-th node of the block in kind-major order
  (`blockIter.toBlockRelativeIndex`).
- Nodes **inside** the block occupy the low `blockLen` bits of any mask.
- Nodes **outside** the block (values referenced from an enclosing block)
  get synthetic input IDs in the **high** bits, assigned top-down starting
  at bit 63 (see *External Inputs* below).

That layout is what makes the scheduler's "is this dep available?" check a
single bitwise AND.

---

## DepMap (`depmap.zig`)

`DepMap` produces three parallel arrays, all indexed by **block-local
slot** (`blockOutputStart + localIndex`):

- `depsList: []BitSet64` — for node at slot `s`, which nodes (by local
  index, or input id) does it consume.
- `refsList: []BitSet64` — the reverse: which local nodes consume this
  node. Inputs (external) have no ref entries — `refsList` only tracks
  in-block references.
- `inputIdsList: []u8` — scratch table keyed by **absolute IR index** that
  remembers "we already gave this external value bit *k* in the current
  block." Zero means "no id yet."

### Layout

`depsList` and `refsList` are sized to `irQ.list.items.len` — one entry
per node slot in the global IR. Blocks fill in a contiguous run; the run
for block `b` starts at `blockOutputStart` and is `blockLen` entries long.

The "slot" address `blockOutputStart + localIndex` is the same slot the
`Sequence` walks via `depMapOffset`. The implicit invariant: across all
blocks, the sum of `blockLen` equals `depsList.items.len`. The asserts at
the bottom of `build()` and `Sequence.build()` enforce this.

### Build Walk

```
for each block:
    for each kind in block (kind-range order):
        for each absolute index in the kind's block range:
            addNodeDependencies(index, kind, node)
    finish()   // reset inputIds touched by this block
```

`addNodeDependencies` looks at the node's role to decide which `args`
fields are dataflow dependencies:

- `BINARY_OPS` → `(left, right)`
- `UNARY_OPS` → `(left)`
- `ir_exit`, `ir_enter`, `ir_def`, `ir_use`, `ir_arg` → `(left, right)`
- `ir_param` → `left` always, `right` only if non-zero
- `ir_frame` → `left` only if `right != 0` (the arg count)
- anything else → no deps

`addDependency(localIndex, dependencyIndex)` then dispatches on whether
`dependencyIndex` is in this block:

- **In-block**: set `deps[output].bit[depLocal]` and `refs[dep].bit[output]`.
  Self-references (`depLocal == localIndex`) are silently dropped — a node
  cannot depend on itself, and `ir_enter`'s `args(enterIdx, enterIdx)`
  placeholder relies on this.
- **External**: set `deps[output].bit[inputId]`. No ref entry is recorded
  (external values are produced elsewhere).

### External Inputs (High-Bit Allocation)

External values get unique bit positions per block, allocated **downward
from bit 63**:

- `LAST_INPUT_ID = 63` is the starting cursor (`nextInputId`).
- First external value referenced in the block gets bit 63, second gets
  62, and so on.
- `MAX_INPUTS = 32` caps the per-block input count, leaving bits 32..63
  available. Combined with the `blockLen ≤ 64` cap and `nextInputId ≥
  blockLen` assert, this keeps local-node bits (low) and input bits (high)
  from colliding.
- `inputIds[absoluteIndex]` memoizes the assignment so a second use of the
  same external value reuses its bit.

`BlockState.finish()` clears every `inputIds` entry the block touched so
the next block starts from a zeroed scratch. (Resetting the whole `u8`
array each block would be O(N) per block; the stack-based reset is O(deps
seen).)

### What's *Not* Tracked

- **Control / effect edges.** Today every dep is a value dep. As effects,
  memory ordering, or stores land, they'll need additional dep bits or a
  parallel mask.
- **Cross-block refs.** `refsList` is per-block; an inner block that uses
  an outer value records that on the *inner* side as an input, but the
  outer producer does not learn about the inner consumer. That's
  intentional — schedules are per-block, so cross-block refs would be
  noise.

---

## Sequence (`sequence.zig`)

`Sequence` turns each block's `DepMap` into a layered schedule.

### Output Shape

```zig
Sequence = struct {
    layersList: []BitSet64        // concatenation of all blocks' layers
    blockLayerLengths: []usize    // layersList.items[ Σ prev lengths .. + length ]
    depMapOffset: usize           // running offset into DepMap during build
}
```

- `layersList` is a flat array of `BitSet64` layers across the whole
  program. Each bit `i` in a layer is a **block-local index** — the bit
  positions are only meaningful relative to the block the layer came from.
- `blockLayerLengths[b]` is how many entries of `layersList` belong to
  block `b`. A block with no live output produces zero layers (see *Empty
  Blocks*).
- A layer is one "ready set": its nodes have all dependencies in
  previously-scheduled layers (or external inputs) and may be issued in
  any order.

### Build Walk

```
for each block:
    layerStart = layersList.len
    buildBlock(...)            // appends 0+ layers
    blockLayerLengths.append(layersList.len - layerStart)
    depMapOffset += blockLen
```

`buildBlock` is the core scheduler.

### Single-Block Scheduling

Inputs to `buildBlock`:

- `blockDeps`, `blockRefs` — slices of `DepMap` covering this block (each
  of length `blockLen`).
- The block's output — the node whose value the `ir_exit` returns. If the
  output isn't a block-local node, or if it is the `ir_enter` placeholder,
  the block has no work and `buildBlock` returns immediately (zero layers
  appended).

The scheduler maintains four bitsets:

- `output` — bit set for the output local index (seed of the walk).
- `needed` — nodes that must eventually be scheduled (transitive
  predecessors of `output`, plus `output` itself).
- `available` — bits already "produced": all **input** bits (the high bits
  outside `lowBits(blockLen)`) start available; in-block bits are added as
  layers are emitted.
- `needsToCheck` — working set for the next iteration: candidates whose
  dependency status to inspect.

```
available = ~lowBits(blockLen)        // external inputs pre-available
needed    = { output }
needsToCheck = { output }

while needsToCheck nonempty:
    metNeeds, newNeeds = ∅, ∅
    for each i in needsToCheck:
        unmet = deps[i] \ available
        if unmet == ∅:
            metNeeds.add(i)
        else:
            newNeeds ∪= unmet           // pull deps into the frontier

    needed ∪= newNeeds                  // remember unmet deps for later

    if metNeeds nonempty:
        append metNeeds as a layer
        for each i in metNeeds:
            newNeeds ∪= refs[i] ∩ needed   // wake parents still pending
        available ∪= metNeeds
        needed    \= metNeeds            // scheduled — remove from frontier

    needsToCheck = newNeeds ∩ needed     // only chase still-pending nodes
```

Two invariants make this terminate:

- Every iteration either appends a layer (`metNeeds` nonempty) or expands
  `needed` (`newNeeds` nonempty). The `metNeeds != 0 or newNeeds != 0`
  assert pins this down.
- `needed` is a subset of in-block bits and only ever loses bits via
  `metNeeds`; the in-block bit pool is finite, so the loop terminates in
  at most `blockLen` ready-rounds.

### Why This Order

The walk is **demand-driven backward, scheduled forward**:

- It starts at the output and expands outward to find what's actually
  needed. Anything not reachable from the output stays out of `needed`
  and is never scheduled — dead code is dropped for free.
- It emits a node as soon as its deps are available, so leaves (literals,
  external uses) appear in early layers and the output appears in the
  last layer.
- Layers carry no intra-layer ordering, which is the input shape register
  allocation / codegen want when they care about scheduling latency or
  parallel issue.

### Empty Blocks

`buildBlock` returns early when:

- The block's `ir_exit` references the matching `ir_enter` (the block had
  no computed result — equivalent to `return ()`), or
- The exit's referenced output is *external* to the block (forwarding a
  value from an enclosing block).

In both cases the block contributes **zero layers** and
`blockLayerLengths[b] = 0`. The `depMapOffset` still advances by
`blockLen` so subsequent blocks read their `DepMap` slice from the right
place.

### Worked Example

```
block: lit 1   // local 1
       lit 3   // local 2
       add 1 3 // local 0 = output
```

DepMap entries (local → deps):
- local 0 (add):  bits {1, 2}
- local 1 (lit):  ∅
- local 2 (lit):  ∅

Schedule trace:

| pass | needsToCheck | metNeeds      | newNeeds | layer appended | available             |
|------|--------------|---------------|----------|----------------|-----------------------|
|  1   | {0}          | ∅             | {1, 2}   | —              | high bits             |
|  2   | {1, 2}       | {1, 2}        | {0}      | `{1, 2}`       | high bits ∪ {1, 2}    |
|  3   | {0}          | {0}           | ∅        | `{0}`          | high bits ∪ {0, 1, 2} |

Resulting layers: `[ {1, 2}, {0} ]` — emit both literals (any order),
then the add. Matches `test "Sequence emits simple expression
dependencies before output"`.

---

## API

### DepMap

```zig
DepMap.init(allocator) !DepMap
DepMap.reserve(allocator, irQ) !void   // size depsList/refsList/inputIds
DepMap.build(irQ) void                 // walk every block, fill deps & refs
DepMap.get(absoluteSlot) BitSet64      // deps mask
DepMap.refs(absoluteSlot) BitSet64     // refs mask
DepMap.deinit(allocator)
```

`reserve` zero-initializes all three lists; safe to call on a fresh
instance. `build` requires `reserve` to have been called for the matching
`IRQueue`.

### Sequence

```zig
Sequence.init(allocator) !Sequence
Sequence.reserve(allocator, irQ, maps) !void  // ensure layer/length capacity
Sequence.build(irQ, maps) void                // produce layers + lengths
Sequence.deinit(allocator)
```

After `build`, `layersList.items[ Σ blockLayerLengths[0..b] ..
+ blockLayerLengths[b] ]` is block `b`'s layer stream.

`reserve` over-allocates `layersList` to `maps.depsList.items.len` — the
worst case is one node per layer per block; that bound is loose but cheap
and avoids reallocation during `build`.

---

## Out of Scope

- **Cross-block scheduling.** Each block's layers are independent; there
  is no global ordering between blocks beyond their natural source order.
- **Effect / memory ordering.** Once stores and other effects land,
  scheduling will need to honor an effect chain, not just value deps.
- **Latency / cost-aware reordering within a layer.** Layers are
  set-valued; an issuer is free to reorder, but `Sequence` itself doesn't
  pick a winner.
- **Register pressure.** The scheduler emits as-early-as-possible, which
  can inflate live ranges. A future pass may want to delay nodes to
  reduce pressure; that belongs in `regalloc.zig`.
