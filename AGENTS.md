# Repository Guidelines

## Project Layout

- `Code/Compiler/` contains the Zig compiler executable, build file, and unit tests.
- `Code/Compiler/src/main.zig` is the CLI entry point.
- `Code/Compiler/src/all_tests.zig` imports the Zig test modules under `Code/Compiler/src/test/`.
- `Tests/FileTests/` contains `.ifi` source files used by file/integration-style tests.
- `Docs/` contains language design notes, posts, and reference material.

## Build And Test Commands

- From the repository root, use `just build` to build the compiler.
- From the repository root, use `just test` to run the Zig test suite.
- From the repository root, use `just basic-test` to build and run the compiler on `Tests/FileTests/add.ifi`.
- From `Code/Compiler/`, use `zig build` and `zig build test --summary all` directly when the wrapper is not needed.

## Change Style

- Prefer small, incremental changes that are easy to review.
- Keep edits scoped to the requested behavior and the nearby implementation.
- When a small type or API cleanup removes casts, adapter locals, or redundant conversions, prefer that over preserving incidental indirection.
- Follow existing Zig style in the touched file before introducing new conventions.
- Do not churn generated or local artifacts such as `.DS_Store`, `out.bin`, `test.bin`, or Zig build/cache output.

## Performance And Memory

- Ask for feedback before introducing operations or abstractions with performance implications, including additional passes over data, super-linear behavior, or new persistent allocations.
- Prefer small, fixed-memory designs and cache-efficient data structures.
- Be explicit about complexity changes when parser, lexer, IR, resolution, or codegen paths are touched.

## Verification

- Run the narrowest relevant test first.
- For compiler behavior changes, add or update focused Zig tests or `Tests/FileTests/*.ifi` cases as appropriate.
- When the touched area is shared or uncertain, run `just test` before handing off.
