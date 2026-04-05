# Resolution Spec

## Overview

Symbol resolution maps identifier references to their declarations within the parsed queue. It runs inline during parsing — no separate pass. The result is that every identifier token in `parsedQ` carries a signed offset to its declaration, forming navigable linked lists per symbol.

---

## Goals

- **Single-pass**: Resolve symbols as they are parsed, without a second traversal
- **Scope-aware**: Declarations are visible only within their enclosing scope
- **Forward references**: Supported in module and object scopes (not in function or block scopes)
- **No heap AST**: Resolution data is encoded directly in token fields — no separate symbol table output

---

## Token Encoding

Identifiers in `parsedQ` use the `Data.Value` layout:

```
 63       48 47                    16 15        8 7         0
┌───────────┬────────────────────────┬───────────┬──────────┐
│ arg1 (16) │      arg0 (32)         │ kind (8)  │ flags(8) │
└───────────┴────────────────────────┴───────────┴──────────┘
  arg0 = symbol ID (interned by lexer)
  arg1 = signed i16 offset to declaration:
         negative → backward reference to prior declaration
         positive → forward reference (patched when declaration is encountered)
         zero     → first declaration, or unresolved
  flags.declaration = 1 at declaration sites
```

### Offset Convention

All offsets are relative: `offset = target_index - current_index`.
- A reference at index 10 pointing to a declaration at index 3 has `arg1 = -7`.
- A forward reference at index 5 later resolved to a declaration at index 12 has `arg1 = +7`.

---

## Declarations

A declaration is created when the parser encounters an assignment (`=`, `+=`, etc.) or a function parameter. The assignment handler retroactively marks the left-hand-side identifier as a declaration.

For each declaration:
1. Set `flags.declaration = true` on the token
2. Set `arg1` to the offset of the **previous** declaration of the same symbol (forming a linked list of declarations), or `0` if this is the first declaration of this symbol
3. Update `declarations[symbolId]` to the current index
4. Resolve any pending forward references to this symbol (in module/object scopes only)

---

## References

When an identifier is encountered that is not a declaration site:
- If a prior declaration exists: `arg1 = declarations[symbolId] - current_index` (negative offset)
- If no declaration exists: `arg1 = 0`, and the index is recorded in `unresolved[symbolId]` for later forward-reference resolution

---

## Forward References

Forward references are supported only in **module** and **object** scopes, where the order of declarations should not matter (e.g., a function can reference another function defined later in the same module).

When a declaration is encountered, the resolver walks the unresolved chain for that symbol. Any unresolved reference whose index falls within the current scope's start boundary is patched with a positive offset to the declaration. References outside the current scope are left unresolved.

Forward references are **not** supported in `function` or `block` scopes — identifiers must be declared before use within those scopes.

---

## Scopes

### Scope Stack

The resolver maintains a stack of scopes. Each scope records its start index in `parsedQ` and its type. A base scope is always present at the bottom of the stack.

### Scope Types

| Scope Type | Forward Declarations | Description |
|------------|---------------------|-------------|
| `base`     | No                  | Root scope, always on stack |
| `module`   | Yes                 | Module-level declarations |
| `object`   | Yes                 | Object/type body |
| `function` | No                  | Function body and parameters |
| `block`    | No                  | Indent blocks, conditional bodies |

### Scope Lifecycle

**Starting a scope**: Pushes a new entry onto the scope stack with the current `parsedQ` index as the start boundary. Increments the scope ID counter.

**Ending a scope**:
1. Pops the scope from the stack
2. For **function scopes**: iterates all declaration tokens within the scope and restores `declarations[symbolId]` to the previous declaration in the chain. This prevents function parameters and local bindings from leaking into the enclosing scope.
3. For **indent block scopes** (`grp_indent` start token): patches the start token's `arg0` with the end index, enabling codegen to know the block's extent.

---

## Data Structures

- `declarations[symbolId] → u32`: Maps each symbol ID to the index of its most recent declaration in `parsedQ`. Initialized to `UNDECLARED_SENTINEL` (0).
- `unresolved[symbolId] → u32`: Maps each symbol ID to the index of its most recent unresolved reference. Used as the head of a linked list threaded through `arg1` offsets for forward-reference resolution.
- `scopeStack`: Dynamic array of `Scope { start: u32, scopeType: ScopeType }`.
- `scopeId: u16`: Monotonically increasing counter assigned to each new scope.

---

## Declaration Linked Lists

Declarations of the same symbol form a backward-linked list through `arg1` offsets:

```
decl(x)@3 [arg1=0]  ←  decl(x)@8 [arg1=-5]  ←  decl(x)@15 [arg1=-7]
                                                    ↑ declarations[x] = 15
```

This allows walking all declarations of a symbol from the most recent back to the first. Each declaration's `arg1` is the offset to the previous declaration, or `0` if it is the first.

---

## Current Limitations

| Area | Status |
|------|--------|
| Forward references in function/block scopes | Not supported by design |
| Unresolved reference chains | Uses single head pointer, not a full linked list — may miss chained unresolved refs |
| Scope cleanup | Function scope cleanup iterates all tokens in range — could be optimized with a per-scope declaration list |
