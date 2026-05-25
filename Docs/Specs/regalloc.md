# Register Allocation Spec

## Overview

`regalloc.zig` is the last pass before codegen. It consumes a `Sequence`
(per-block layers of `BitSet64`, see `ir_sequence.md`) and produces a flat
stack of `Token`s annotated with concrete `u16` *locations* — either a
physical register index or a spill-slot id. Codegen pops that stack and
emits machine code; it never sees the abstract IR node ids again.

The allocator is **linear-scan with LRU-driven spilling**, walked
**backward** over the schedule:

1. Each block's layers are processed last-to-first; within a layer, nodes
   are processed high-bit-to-low-bit (`@clz`-based pop). Backward order
   means we meet a node's *use* before its *definition*, which is exactly
   when register allocation needs to make decisions.
2. When a node is visited (`processElement`), we first finalize its
   **result** location (`declareResult`) — the register the producer must
   write into — then assign **operand** locations (`useDependency`) — the
   registers the producer must read from.
3. Allocation requests against a full register file evict the
   least-recently-touched live value (`RegisterPool`, backed by a
   fixed-capacity intrusive LRU list in `lru.zig`). The evicted value gets
   a fresh spill slot and we emit a `op_load` token so codegen later
   reloads it from the stack.
4. Tokens are pushed in reverse program order. After `build()` finishes,
   `popToken()` yields them in **forward** program order, which is how
   codegen consumes the stack.

This spec covers:

- `regalloc.zig` — the per-block backward walk, the token stack, and the
  location encoding.
- `registerpool.zig` — the free-list + LRU policy that picks which
  register to allocate or evict.

It builds on `ir.md` (kind ranges, `BINARY_OPS` / `UNARY_OPS` /
`LITERALS`) and `ir_sequence.md` (block-local bit positions, layered
schedule).

---

## Location Encoding (`u16`)

Every IR node gets one `u16` *location* stored in `RegAlloc.locations`
(parallel-indexed to the global IR queue):

| Range                            | Meaning                                 |
| -------------------------------- | --------------------------------------- |
| `0 .. MAX_REGISTERS` (64)        | Physical register index                 |
| `SPILL_BASE .. FIRST_SENTINEL`   | Spill slot (`location - SPILL_BASE`)    |
| `NO_LOCATION` (= max-2)          | Operand slot is unused (e.g. unary `right`) |
| `FREED_LOCATION` (= max-1)       | Result has been declared and freed      |
| `UNASSIGNED_LOCATION` (= max)    | Node not yet visited (initial state)    |

`SPILL_BASE = 1 << 15` keeps registers and spill slots in disjoint
numeric ranges so `isRegister` / `isSpill` are simple range checks. The
three sentinels live in the top of the `u16` range below `SPILL_BASE +
spill_count`, with `FIRST_SENTINEL = NO_LOCATION` as the upper bound on
legal spill ids. `nextSpillLocation` errors with `TooManySpills` if a
program ever needs more than `FIRST_SENTINEL - SPILL_BASE` slots.

`registerLocation(reg)` / `isRegister` / `isSpill` / `spillSlot` are the
small helpers callers use to encode/decode without touching the constants
directly.

---

## Why Backward?

The schedule is in forward-execution order: producers come before
consumers. But the *natural* time to decide what register a value lives
in is when we see its first **use** — at that point we know the value is
live, and we know which other values are competing for registers around
it. A forward walk would have to either guess at definition time or
defer-and-patch.

Walking backward inverts the problem:

- The **first time** we see a node in the backward walk is at its **last
  use** (or the block output). That's when we allocate a register for it.
- The **last time** we see a node — when we visit the node itself — is
  its **definition**. By then the register has already been chosen by an
  earlier (in walk order, later in program order) consumer. The producer
  just needs to free it.

The pushed-token stack flips the order back. Codegen sees: producer
first, then each consumer in forward order, with loads/stores interleaved
exactly where the backward walk decided spills were needed.

---

## RegAlloc (`regalloc.zig`)

### State

```zig
RegAlloc = struct {
    register_pool: RegisterPool       // free list + LRU
    token_stack:   []Token            // reverse-order output, popped forward
    locations:     []u16              // one entry per IR node, see encoding above
    next_spill_slot: u16              // monotonically increasing spill counter
}
```

`locations` is sized to the full IR length (one slot per absolute IR
index); `reset()` initializes every entry to `UNASSIGNED_LOCATION`.
`token_stack` is reserved to `irQ.len + seq.layersList.len` — a loose but
cheap upper bound (every node plus one potential load per layer entry).

### Per-Block Walk

```
for each block (forward):
    take layers[layerStart .. layerStart + blockLen] from Sequence
    for layer_index = layers.len - 1 .. 0:        // backward
        for each bit set in layers[layer_index], high-to-low:
            processElement(absoluteIndex)
```

Layers are independent within a block, so the high-to-low ordering inside
a layer is arbitrary — we use `@clz` because it lets us pop one bit per
iteration with `mask &= ~(1 << local_index)`.

Blocks are walked **forward**, but each block's layers are walked
**backward**. That's intentional: within a block the walk needs to see
the output first; across blocks, codegen wants block 0's tokens before
block 1's, and the token stack already reverses order, so pushing them
forward-block first gives forward-block order on pop.

### `processElement`

```
result   = declareResult(index)           // finalize THIS node's home
operands = operandsFor(node)              // allocate homes for its inputs
pushToken(kind, operands.left, operands.right, result)
```

The order matters: `declareResult` runs **first** because it *frees* the
result register before `operandsFor` allocates operand registers. This is
the classic "two-address-friendly" trick — once the result is computed,
its register is dead and can be reused for an operand. Without freeing
first, a binary op on a tight register budget would always need an extra
spill.

Literals are a special case: they have no operands, so they skip
`operandsFor` and push a `regLiteral` token carrying the raw value
payload from the IR node.

### `declareResult`

When we process a node, the result's `locations` entry tells us what
earlier (later-in-program) consumers chose:

- **Already in a register** (`isRegister`): the only consumer used that
  register. Free it and return the register — the producer will write
  there.
- **In a spill slot** (`isSpill`): consumers couldn't keep it in a
  register; it got evicted. Allocate a fresh register for the producer to
  write into, emit an `op_store` so the value reaches the spill slot
  consumers expect, then free the register. (We emit the store *now*
  because tokens are pushed reverse-order: in forward execution this
  store appears right after the producer.)
- **Unassigned**: no consumer was reached. This is a live-output node
  whose value the block didn't otherwise need — give it a register,
  immediately free it, and let codegen emit the write. (Dead results
  could be skipped, but the `Sequence` pass already drops unreachable
  nodes, so anything that reaches `processElement` is reachable.)

In all three branches the slot ends up `FREED_LOCATION` because the node
itself has no live consumers *after* its definition.

### `operandsFor` / `useDependency`

`operandsFor` dispatches on the IR kind:

- `BINARY_OPS` → `(useDependency(left), useDependency(right))`
- `UNARY_OPS`  → `(useDependency(left), NO_LOCATION)`
- everything else → `(NO_LOCATION, NO_LOCATION)`

`useDependency(dep_index)` is the heart of the allocator. The dep's
current location tells us whether the dep is already live in a
later-program-order consumer:

- **In a register**: another consumer (visited earlier in the backward
  walk, i.e. *later* in the program) already pinned it there. `touch` it
  in the LRU so it doesn't get evicted by an upcoming allocation, and
  return the register.
- **In a spill slot**: the dep was assigned a spill earlier in the walk.
  Allocate a register and emit an `op_store` — in forward execution this
  store happens after the producer writes, so the value lands in the
  spill slot where *other* consumers reload it. (Yes, the producer's path
  through `declareResult` will then also emit a store; this is one of two
  cases — see *Spill cost* below.)
- **Unassigned**: this is the first (= latest in program order) consumer
  to touch the dep. Allocate a register; that register is the dep's home
  until the producer is reached.

The key invariant: when the producer eventually runs `declareResult` for
this same dep, the slot is whatever the *first* (earliest-walked, latest-
in-program) consumer set, after subsequent consumers may have shifted it
into a spill via eviction.

### Token Emission Order

Tokens are pushed during the backward walk, so the stack grows in
**reverse program order**:

```
token_stack: [ block_N tokens (rev), ..., block_0 tokens (rev) ]
                                                          ^ top
```

`popToken` pops from the top, yielding block 0's first instruction first.
Inside a block, the producer is pushed last (visited last in the backward
walk) and so pops first. Loads and stores end up interleaved in the right
place: a load emitted while allocating-for-a-spill ends up *before* its
consumer on pop; a store emitted in `declareResult` ends up *after* the
producer on pop.

### Spill Cost

The current policy isn't optimal — it can emit redundant stores when a
spilled value has multiple consumers. The first consumer to visit it
emits a store (to materialize it in the spill slot it reloads from); the
producer's `declareResult` then emits another store. A future pass could
collapse these; today we accept the duplication for the simpler
backward-walk invariant.

`spillSlotCount()` lets codegen learn how much stack frame to reserve
once `build` finishes.

### API

```zig
RegAlloc.init(allocator, free_registers) !RegAlloc
RegAlloc.reserve(irQ, maps, seq) !void       // size token_stack & locations
RegAlloc.build(irQ, maps, seq) !void         // walk all blocks, push tokens
RegAlloc.popToken() ?Token                   // forward-order consumption
RegAlloc.tokenCount() usize
RegAlloc.spillSlotCount() u16
RegAlloc.deinit()
```

`reserve` is split from `build` so the caller can preallocate once and
re-`build()` (e.g. across iterations) without reallocation. `build`
itself calls `reset()` first, so it is idempotent on a `reserve`d
instance.

`free_registers` is a `BitSet64` mask of architecture-available
registers, passed through to `RegisterPool.init`. An empty mask is an
error.

---

## RegisterPool (`registerpool.zig`)

`RegisterPool` decouples the **policy** ("which register should I use?")
from the **bookkeeping** (`RegAlloc.locations` etc.). It owns three
parallel pieces of state plus a frozen base mask:

```zig
RegisterPool = struct {
    register_pool:    BitSet64                 // base set, immutable after init
    free_registers:   BitSet64                 // currently unallocated
    recent_registers: Lru(MAX_REGISTERS)       // eviction order
    register_values:  [MAX_REGISTERS]u32       // which IR node lives in reg r
}
```

- `register_pool` is the **architecture-fixed** set of registers the
  allocator may touch (e.g. caller-saves on ARM64). It is set once in
  `init` and used as the source-of-truth in asserts (`isSet(reg)` checks
  that a `free`/`touch` only ever names a real register).
- `free_registers` starts as a copy of `register_pool` and tracks
  what's currently unallocated.
- `recent_registers` is an intrusive doubly-linked list (`lru.zig`)
  ordering **only allocated** registers from least-recently-touched
  (`head`) to most-recently-touched (`tail`). Popping the LRU gives the
  next spill victim.
- `register_values[r]` is the IR index currently materialized in register
  `r`, or `NO_NODE` (`maxInt(u32)`) if the register is free. This is the
  back-pointer `allocate` returns as `evicted` when a spill happens, so
  the caller can update its `locations` entry.

### `allocate(index)`

```
if free_registers has a bit set:
    pick the lowest free register
    assign it to index (touch + record value + clear free bit)
    return { register, evicted = null }

reg = recent_registers.popLru()    // err NoRegisterToSpill if list is empty
evicted = register_values[reg]
register_values[reg] = NO_NODE
assign reg to index
return { register, evicted }
```

`findFirstSet` is preferred over LRU even when the LRU is non-empty: free
registers carry no cost; reusing one would still need an eviction later
when we genuinely run out. The LRU is only consulted when there is no
free register.

`NoRegisterToSpill` only fires if the architecture mask was tiny *and*
every register in it is held by a value that has been `free`d but not yet
reallocated — currently unreachable in practice, but kept as a hard
guardrail.

### `free(reg)` vs `touch(reg)`

- `free` returns a register to the pool: sets the free bit, removes it
  from the LRU, clears `register_values[reg]`. Called by `RegAlloc` once
  a node has been fully processed (in `declareResult`).
- `touch` marks a register as most-recently-used **without** changing
  allocation state. Called by `useDependency` when a dep is already in a
  register so subsequent allocations don't evict it.

The two asserts on `touch` (`!isSet(free_registers, reg)` and
`register_values[reg] != NO_NODE`) catch the common bug of touching a
register that has already been released.

### `reset()`

Restores `free_registers` from `register_pool`, zeroes the LRU, and clears
`register_values`. Called once per `RegAlloc.build` so the pool is
deterministic across re-builds.

### LRU Implementation (`lru.zig`)

`Lru(N)` is a fixed-capacity intrusive doubly-linked list keyed by handle
`0..N`. Each handle stores its own `{prev, next}` pair (two bytes total
for `N ≤ 256`), and the list maintains `head`/`tail` cursors. A "vacant"
node is encoded by `prev == next == self` — that lets `isLinked` answer
without a side table, and `popLru` / `set` / `remove` are O(1).

This is what gives `RegisterPool` an O(1) eviction choice. The cost is
that the LRU capacity is fixed at compile time (`MAX_REGISTERS = 64`),
which matches the `BitSet64` everywhere else.

---

## Worked Example

```
block: lit 1     // local 1, abs index = a
       lit 3     // local 2, abs index = b
       add 1 3   // local 0 = output, abs index = c
```

`Sequence` emits `[ {1, 2}, {0} ]`. The allocator walks layers in
reverse: first `{0}`, then `{1, 2}`. Assume 2 registers free, both
initially unassigned.

| step | action                        | locations after                | tokens pushed (top→bottom)              |
| ---- | ----------------------------- | ------------------------------ | --------------------------------------- |
| 1    | `processElement(c = add)`     |                                |                                         |
| 1a   | `declareResult(c)`: unassigned → alloc r0, free r0 | c: FREED                | —                                       |
| 1b   | `useDependency(a)`: unassigned → alloc r0 | a: r0                  | —                                       |
| 1c   | `useDependency(b)`: unassigned → alloc r1 | b: r1                  | —                                       |
| 1d   | push `add r0, r1 → r0`         |                                | `[add r0,r1→r0]`                        |
| 2    | `processElement(b = lit 3)`    |                                |                                         |
| 2a   | `declareResult(b)`: r1 → free r1 | b: FREED                       | —                                       |
| 2b   | push `lit 3 → r1`              |                                | `[lit 3→r1, add r0,r1→r0]`              |
| 3    | `processElement(a = lit 1)`    |                                |                                         |
| 3a   | `declareResult(a)`: r0 → free r0 | a: FREED                       | —                                       |
| 3b   | push `lit 1 → r0`              |                                | `[lit 1→r0, lit 3→r1, add r0,r1→r0]`    |

After pop, codegen sees: `lit 1 → r0; lit 3 → r1; add r0, r1 → r0` —
correct forward-order machine code.

---

## Out of Scope

- **Calling conventions.** The pool is given a `free_registers` mask;
  pinning specific registers for args / returns / clobbers is the
  caller's job. ABI lowering will live in `codegen.zig` or a wrapper
  pass.
- **Coalescing.** No attempt is made to fuse `mov` chains by aligning
  result and operand registers. Two-address ISAs benefit; we accept the
  occasional copy today.
- **Cross-block register state.** Each block starts with a fresh
  `RegisterPool.reset` (well, the pool persists, but every `locations`
  entry pointing into the previous block is `FREED_LOCATION`). Values
  that flow between blocks travel via spill slots until a future pass
  handles inter-block allocation.
- **Spill placement quality.** LRU is cheap and predictable; it is not
  optimal. A node that's about to be reused but happens to be the least-
  recently-touched will still be evicted. Furthest-next-use would be
  better but needs liveness info we don't currently compute.
- **Redundant store elimination.** As noted under *Spill cost*, a
  spilled value with multiple consumers emits one store per consumer
  plus one from the producer; a peephole pass can drop the duplicates.
- **Register classes.** Today every register is interchangeable. Float /
  vector / address-class splits will need parallel pools.
