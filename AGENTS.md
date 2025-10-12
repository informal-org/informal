Informal is a statically typed, compiled programming language that is simple, efficient and productive. It targets ARM assembly and WebAssembly.
Informal is a homoiconic language where everything is a map, similar to how everything's a list in Lisp. Variables in informal are immutable, similar to Clojure, Erlang, Elixir and funcitonal languages. Mutation is isolated within actor-classes, which return new states as they process messages in-order in their mailbox. 
The backend for informal is written in Zig with the intention of being re-written in Informal. 

## Keep it simple
When writing code, value simplicity and correctness over everything else. Do not add extra features or nice-to-have fluff. Keep code to a bare minimum and ALWAYS look for opportunities to simplify. Simple code is readable and obviously correct without requiring excessive reasoning. 

## Test Driven Development for Correctness
When asked to plan, write a short spec for what is being built and the high-level approach. Check this into the Specs directory with a file named `<date>-<name>.md` with the current YMD date and a short descriptive name. The spec file should clearly specify each requirement or rule the final solution must follow. It should outline the high-level data flow and any new schemas when relevant. 

Use red-green test-driven development for every change. First, write failing unit-tests which follows the spec. Then, write the implementing code to get the tests to pass. Write assertions liberally to verify the assumptions in each function, as well as verify properties of the expected results. Add debug-logging everywhere to make it easier to trace execution and include any context you'd find necessary to understand the program state.
Use file-tests to test programs end-to-end through the informal compiler.

## Data Oriented Design for Performance
Performance is about using resources efficiently, avoiding unnecessary work and making systematic, algorithmic improvements to the core data structures and algorithms than making micro-optimizations. Think carefully about what data is necessary, how many bits are needed to represent it, the layout & padding of data in structures and what data structure to store it in to optimize access patterns. 


## Tooling
Run `just build` to compile the code.
Test individual files using `zig test Code/Compiler/src/parser.zig`
Run `just run <name>` to compile an informal program through Informal. Add the file to Tests/FileTests/<name>.ifi

