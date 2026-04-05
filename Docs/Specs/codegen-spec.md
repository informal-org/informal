# Codegen Spec

## Overview

The code generator walks the postfix `parsedQ` from the parser and emits AArch64 (ARM64) machine code. It operates in a single linear pass over the token queue, using a register stack to thread operands through operators.

**Key properties:**
- Single-pass, linear traversal of `parsedQ`
- Stack-based register allocation — operands push registers, operators pop and reuse them
- Direct machine code emission (no intermediate representation)
- Targets macOS/Darwin AArch64 syscall ABI
- Branch targets resolved via linked-list fixup after emission

---

## Input

The codegen consumes the `parsedQ` token array produced by the parser. Tokens are in **postfix order** — operands appear before their operators. The source buffer is available for string constant data.

Function bodies in `parsedQ` are skipped (they are templates for inline expansion, already expanded at call sites by the parser).

---

## Output

A flat array of `u32` ARM64 instructions (`objCode`), ready to be written into a Mach-O binary.

---

## Register Allocation

### Register Stack

A 64-bit integer (`regStack`) acts as a packed stack of 5-bit register IDs. Each operand pushes its register; each operator pops its operands' registers.

- `pushReg(reg)`: `regStack = (regStack << 5) | reg`
- `popReg()`: extract low 5 bits, shift right

### Register Bitmap

A 32-bit bitmap (`registerMap`) tracks which registers are in use. `getFreeReg()` allocates the lowest free register; `freeReg()` releases it.

Registers x0, x1, x2 are reserved at codegen start (used for syscall arguments and string constant addressing).

---

## Token Handlers

### Literals

**`lit_number`**: Allocate a register, emit `MOVZ` with the inline value (u16 from `arg0`), push register.

**`lit_string`**: Push the string length register and emit `MOVZ` for the length. Emit `ADRP` + placeholder for the constant pool address. Record the `parsedQ` index for later fixup (see Constant Pool Fixup). The placeholder and fixup metadata are threaded through `parsedQ` token fields as a linked list.

### Identifiers

**Declaration** (`flags.declaration = true`):
- If `splice=true` (inline expansion binding): pop the operand register from the stack (operand was already pushed by caller)
- Otherwise: allocate a new register
- Write the assigned register ID back into the `parsedQ` token at this index so future references can look it up
- Push register

**Reference** (not a declaration):
- Follow `arg1` offset to the declaration token
- Read the register ID stored there
- Push that register

**`call_identifier`** (non-declaration):
- Pop argument registers, move them into x0-x2
- Emit the `write` syscall sequence (`MOVZ x16, #4; SVC #0x80`)

### Operators

**`op_assign_eq`**: Pop value and identifier registers, emit `MOV`, push identifier register.

**`op_add`**: Pop two registers, emit `ADD`, push result register.

**`op_mul`**: Pop two registers, emit `MUL`, push result register.

**`op_gt`**: Pop two registers, emit `CMP`. Append a pending branch with the inverse condition (`LE`) to the unknown branch list.

### Functions

**`kw_fn`**: Set `skip_count = bodyLength` (from `arg0`). The next `bodyLength` tokens are skipped — function bodies are inlined by the parser at call sites, not executed in place.

### Conditionals

**`kw_if`**: Set `ctx_current_block_kind = kw_if`. The condition's comparison and branch instructions have already been emitted (postfix order — condition precedes `kw_if`).

**`op_colon_assoc`**: Transfer the unknown branch list to the fail branch list. This marks the boundary between condition evaluation and the branch body — any pending conditional branches now target the fail path (skip the body if condition is false).

**`grp_indent`**: No-op (branch pass-through target).

**`grp_dedent`**: If inside a conditional block (`kw_if` or `kw_else`):
1. Resolve all fail branches to the current instruction index
2. If the next token is `kw_else`: emit an unconditional branch (`AL`) to the end list (jump over the else body)
3. Otherwise: resolve all end branches to the current index (final exit point)

**`kw_else`**: Sets `ctx_current_block_kind = kw_else`. The subsequent `op_colon_assoc` and body follow the same pattern.

---

## Branch Fixup

Conditional branches cannot know their target address at emission time. The codegen uses **linked-list fixup** to resolve them later.

### Branch Label

```
┌──────────────┬────────────────────┐
│ cond (4 bits)│  offset (28 bits)  │
└──────────────┴────────────────────┘
```

Each pending branch is stored in `objCode` as a `BranchLabel` — a packed u32 containing the branch condition and a relative offset to the previous pending branch in the same list. This forms a singly-linked list threaded through the instruction array itself.

### Branch Lists

Four tail pointers track pending branches:

| List | Purpose |
|------|---------|
| `br_unknown_tail_idx` | Freshly emitted comparison branches, not yet classified |
| `br_fail_tail_idx` | Branches that jump to the else/end if condition fails |
| `br_end_tail_idx` | Unconditional jumps from then-body to end (skip else) |
| `br_pass_tail_idx` | Reserved for short-circuit OR (branch to success) |

### Resolution Flow

1. Comparison (`op_gt`) emits a pending branch → appended to **unknown** list
2. `op_colon_assoc` moves unknown → **fail** list
3. `grp_dedent` resolves **fail** branches to current index, optionally emits an unconditional jump to **end** list
4. Final `grp_dedent` (no else follows) resolves **end** branches to current index

Resolution walks the linked list backwards, replacing each `BranchLabel` with the actual `b.cond` instruction targeting the resolved address.

---

## Constant Pool Fixup

String constants are placed after the code section. Their addresses are unknown during emission, so the codegen uses a deferred fixup:

1. During emission: emit the constant ID as a placeholder instruction and record a `(objCode index, offset to previous)` pair in the `parsedQ` token at the current index
2. After all code is emitted: compute the constant pool base address from code size and alignment
3. Walk the fixup linked list (threaded through `parsedQ` tokens via `strConstRefTail`): replace each placeholder with the actual `ADDI` instruction using the computed address

The constant pool base is page-aligned within a single 16KB page (`0x4000`). Constants are packed sequentially without padding.

---

## Syscall ABI

Targets macOS/Darwin AArch64 conventions:

| Register | Purpose |
|----------|---------|
| x0 | First argument (fd for write, exit code for exit) |
| x1 | Second argument (buffer address for write) |
| x2 | Third argument (length for write) |
| x16 | Syscall number |

Syscalls: `exit` (#1), `write` (#4). Invoked via `SVC #0x80`.

The final value left on the register stack is used as the exit code for the program's `exit` syscall.

---

## Current Limitations

| Area | Status |
|------|--------|
| Register allocation | Linear allocator, no spilling, no lifetime tracking |
| Arithmetic | Only `add`, `mul`, `gt` implemented |
| Comparisons | Only `gt` with inverse `LE`; no other comparison operators wired |
| String constants | Single-page addressing only; fixed to x1 register |
| Nested conditionals | `ctx_block_start` tracking incomplete for nested if/else |
| Loops (`for`) | Not implemented |
| Function calls | Only hardcoded `write` syscall; no user-defined call convention |
| Multi-page programs | Constant pool assumes everything fits in one 16KB page |
