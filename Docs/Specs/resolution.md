# Resolution Spec

## Overview

Symbol resolution maps identifier references to their declarations within the parsed queue. It runs inline during parsing — no separate pass. Every identifier token in `parsedQ` carries signed offsets that thread together declarations and uses into navigable chains, so codegen and later passes can walk between a declaration and any of its uses without a symbol table lookup.

---

## Goals

- **Single-pass**: resolve symbols as they are parsed, no second traversal
- **Scope-aware**: declarations are visible only within their enclosing scope
- **Forward references**: allowed in module and object scopes; not in function or block scopes
- **Cheap cleanup (planned)**: `endScope` is intended to revert only the declarations that actually shadowed something via a bitset; the bitset and revert pass are currently commented out (see *Current Limitations*)
- **No heap AST**: resolution data is encoded directly in token fields — no separate symbol table output

---

## Token Encoding

Identifiers in `parsedQ` use the `Data.Ident` packed layout (48 bits):

```
 63       48 47                    32 31                    16 15        8 7         0
┌───────────┬────────────────────────┬────────────────────────┬───────────┬──────────┐
│next_off 16│      prev_off 16       │     symbol_id (16)     │ kind (8)  │ flags(8) │
└───────────┴────────────────────────┴────────────────────────┴───────────┴──────────┘
```

- `symbol_id` (u16) — interned by the lexer
- `prev_offset` (i16, stored as u16 via `@bitCast`) — signed offset to the previous link in this symbol's chain
- `next_offset` (i16) — signed offset to the next resolved use of this symbol (`0` = last / no next use yet)
- `flags.declaration = 1` at declaration sites

### Offset Convention

All offsets are relative: `offset = target_index − current_index`.
- A reference at index 10 whose declaration is at index 3 has `prev_offset = −7`.
- A forward-reference at index 5 that is later resolved to a declaration at index 12 has `prev_offset = +7`.
- `0` is the `UNDECLARED_SENTINEL`, meaning "no previous link" (first in chain, or still unresolved).

Helpers in `resolution.zig`:
- `calcOffset(T, target, index)` — compute a signed offset, narrowed to `T` (u16 for identifier fields, u28 for branch labels)
- `applyOffset(signedT, index, offset)` — add a signed offset back to an index

---

## Chains

Each symbol has a single chain that threads through `parsedQ`:

```
decl@3 ──next──▶ use@8 ──next──▶ use@12
   ◀────prev────    ◀────prev────
```

- **`prev_offset`** on a resolved use points back to the declaration (one hop, always).
- **`prev_offset`** on a declaration that shadows a prior declaration points back to the *tail* of the outer chain (declaration or most recent use) — whichever was active when the shadow started. (Intended for `endScope` to revert state; revert is not yet implemented.)
- **`next_offset`** on the declaration and each intermediate use points to the next use. The final (most recent) node has `next_offset = 0`.

`declarations[symbol_id]` is the **tail** of the chain — not always the declaration. It is:
- The declaration itself, if no references have been resolved yet, or
- The most recently resolved reference, whose `prev_offset` lands on the declaration in one hop.

This representation means `resolve()` does no staleness walk — it only reads the tail, writes two offsets, and updates `declarations[symbol_id]`.

---

## Declarations

A declaration is created when the parser encounters an assignment (`=`, `+=`, etc.) or a function parameter. The assignment handler retroactively rewrites the LHS identifier as a declaration.

For each declaration (`declare(index, token)`):

1. Read `prev_tail = declarations[symbol_id]`.
2. If `prev_tail == UNDECLARED_SENTINEL`: this is the first declaration of this symbol. `prev_offset = 0`.
3. Otherwise this declaration *shadows* the outer chain. Set `prev_offset = calcOffset(u16, prev_tail, index)` so the outer tail can be restored later. (A call to mark `index` in a shadow bitset is present but commented out — the revert pass is not yet active.)
4. Emit the token via `token.newDeclaration(prev_offset)` — sets `flags.declaration = true`.
5. Update `declarations[symbol_id] = index`.
6. Call `resolveForwardDeclarations()` for module/object scopes (see below).

---

## References

`resolve(index, token)` is called for every non-declaration identifier.

**If no declaration exists** (`tail == UNDECLARED_SENTINEL`):
- Chain this ref into `unresolved[symbol_id]`: `prev_offset = calcOffset(prev_unresolved, index)` (or `0` if first).
- Write `unresolved[symbol_id] = index`.
- The token is emitted with `next_offset = 0`.

**If a declaration exists**:
- Derive the declaration index from the tail: if the tail is itself a declaration, use the tail; otherwise one-hop via the tail's `prev_offset`.
- Emit the reference with `prev_offset = calcOffset(decl_idx, index)` (negative).
- Patch the previous tail's `next_offset = calcOffset(index, tail)` (positive) so the use-chain stays doubly threaded.
- Update `declarations[symbol_id] = index` — this reference is the new tail.

---

## Forward References

Forward references are supported only in **module** and **object** scopes, where the order of declarations should not matter (e.g. a function can reference another function defined later in the same module).

`unresolved[symbol_id]` stores the head of a singly-linked chain of unresolved refs, threaded through their `prev_offset` fields. On `declare()`, `resolveForwardDeclarations()` walks that chain:

1. Read the next unresolved index from the current ref's `prev_offset`.
2. If the unresolved ref falls within the current scope (`unresolvedRefIdx ≥ currentScope.start`), patch it:
   - `symbol_id` = this symbol (it may have been overwritten by the unresolved-chain pointer)
   - `prev_offset` = offset to the new declaration
   - `next_offset` = 0 (will be linked in as part of the normal chain)
   - Splice the ref into the use-chain: the previous tail's `next_offset` is patched to point at it, and `declarations[symbol_id]` advances to it.
3. Continue with the next unresolved ref.
4. Stop at the first unresolved ref outside the current scope. `unresolved[symbol_id]` is updated to that cutoff.

Forward references are **not** supported in `function` or `block` scopes — identifiers must be declared before use.

---

## Scopes

### Scope Stack

`scopeStack` is a stack of `Scope { start: u32, scopeType: ScopeType }`. A `base` scope is always on the bottom. `scopeId` is a monotonically increasing counter, assigned to each new scope as an identity used by `grp_indent`/`grp_dedent` tokens.

### Scope Types

| Scope Type | Forward Declarations | Description                                 |
|------------|----------------------|---------------------------------------------|
| `base`     | No                   | Root scope, always present                  |
| `module`   | Yes                  | Module-level declarations                   |
| `object`   | Yes                  | Object/type body                            |
| `function` | No                   | Function body and parameters                |
| `block`    | No                   | Indent blocks, conditional bodies           |

### Scope Lifecycle

**`startScope(scope)`** — pushes the scope, increments `scopeId`.

**`endScope(index)`**:
1. Pops the scope.
2. If the scope's start token is a `grp_indent`, patches its `Data.Scope.index` with `index` (the block's end position).
3. *Planned:* call `revertShadows(scope.start, index)`. Currently commented out — shadowed `declarations[]` entries persist past their scope's end.

### revertShadows (planned, not active)

The intended design is a `shadow_masks: []u64` bitset over `parsedQ` indices. A set bit at index `i` would mean the declaration at that position shadows a prior declaration and must be reverted when its scope ends.

`revertShadows` would scan only the words in `[start/64, end/64]`, skipping any that are `0`. For each set bit `i`:
- Read the declaration token at `i`. Extract `symbol_id` and `prev_offset`.
- If `prev_offset == 0`: this was the first declaration of the symbol within the outer scope. Reset `declarations[symbol_id] = UNDECLARED_SENTINEL`.
- Else: `declarations[symbol_id] = applyOffset(i16, i, prev_offset)` — restore the outer tail.
- Clear the bit from the mask.

Target cost is O(shadows), not O(scope_size). Neither the bitset nor the scan exists in the current code; `setShadowBit` and `revertShadows` calls are present as comments only.

---

## Data Structures

- `declarations: []u32` — indexed by `symbol_id`. Holds the current chain tail, or `UNDECLARED_SENTINEL (0)`.
- `unresolved: []u32` — indexed by `symbol_id`. Head of the unresolved forward-ref chain, threaded through `prev_offset`.
- `scopeStack` — dynamic array of `Scope`, preallocated to depth 64. A `base` scope is appended at init.
- `scopeId: u16` — monotonic scope identity counter.

`Resolution` is a plain struct. There is no compile-time shadow-mode variant (allow/disallow) in the current code, and no shadow bitset; both are planned but inactive.

---

## Assumptions & Invariants

- **Symbol IDs are preserved on declaration tokens.** This matters for the planned `endScope` revert, which would read `symbol_id` from each shadowed declaration to know which `declarations[]` entry to restore. Codegen later overwrites `symbol_id` on declarations with an allocated register ID (`Token.assignReg`), which is fine because this happens strictly after all scopes have ended.
- **References' `symbol_id` may be overwritten by the unresolved-chain pointer** while they are still unresolved. `resolveForwardDeclarations` restores the correct `symbol_id` when it patches the ref.
- **Chain tails are always reachable in one hop from the declaration.** Either the tail *is* the declaration, or its `prev_offset` points at the declaration directly.

---

## Current Limitations

| Area | Status |
|------|--------|
| Shadow reversion on `endScope` | Not implemented. `setShadowBit` and `revertShadows` calls are present as comments only, and there is no `shadow_masks` field. Shadowed `declarations[]` entries persist past their scope's end. |
| Unresolved chain `symbol_id` transience | Refs on the unresolved chain temporarily lose their `symbol_id` (it's overwritten by the chain pointer). `resolveForwardDeclarations` restores it, but any pass that reads `symbol_id` on an unresolved ref before it is patched will see garbage. |
| Forward refs outside scope | `unresolved[]` is reset only up to the current scope's start boundary. Refs from outer scopes remain unresolved across inner scope boundaries. |
| Scope stack depth | `scopeStack` is preallocated to 64 (`appendAssumeCapacity`) — deeper nesting will panic rather than grow. |
