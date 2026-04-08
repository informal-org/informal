# Refined Symbol Resolution

## Problem
Two existing implementations (eager, lazy) have complementary weaknesses. Eager does O(scope_size) cleanup on endScope. Lazy defers cleanup but pays O(chain_length) on every resolve() via staleness walks. With ~3-5 declarations and ~10-30 references per scope, and shadowing being rare, neither is optimal.

## Approach
Eager cleanup of only shadowed declarations via a bitset. A bit at parsedQ index `i` means that declaration shadows a previous one and needs reverting on endScope. Common case (no shadows) scans 1-2 u64 words and finds nothing. Use-def forward chains are maintained during resolution for the register allocator. Comptime shadow mode parameter eliminates the shadowing-allowed/disallowed branch at compile time.

## Token Encoding

| Token type | arg0 (u32) | arg1 (u16) | flags.declaration |
|---|---|---|---|
| Declaration | symbolId | i16 offset to prev decl (0 if first) | true |
| Reference | next_use_index (0 if last) | i16 offset to decl (negative) | false |
| Unresolved ref | symbolId | i16 offset to prev unresolved (0 if first) | false |

## Data Structures

- `DeclEntry` (packed u64): `decl_index: u32`, `chain_tail: u24`, `_padding: u8`
- `declarations: []DeclEntry` — indexed by symbol ID
- `unresolved: []u32` — indexed by symbol ID, head of unresolved forward-ref chain
- `shadow_masks: []u64` — bitset over parsedQ indices (only when shadow_mode == .allow)
- `scopeStack` — dynamic array of `Scope { start: u32, scopeType: ScopeType }`
- `Resolution` is `ResolutionImpl(comptime shadow_mode: ShadowMode)`, defaulting to `.allow`

## Rules

1. declare() chains to previous declaration via arg1 offset. If shadowing, marks the bitset.
2. resolve() looks up declarations[], computes offset, patches use-chain tail. No staleness walk.
3. endScope() scans shadow_masks in [scope.start, index), reverts each shadowed declaration by reading sym_id from arg0 and previous decl from arg1 offset.
4. Forward references only in module/object scopes. Walks unresolved[] chain on declare().
5. shadow_mode == .disallow: declare() returns error on any shadow; bitset and cleanup are omitted.
6. Symbol IDs are discarded from reference tokens (arg0 reused for next-use chain). Kept in declaration tokens for endScope lookup, then overwritten by codegen with register ID.
