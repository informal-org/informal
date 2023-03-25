# Minformal
Minformal is a minimal subset of Informal used to bootstrap the compiler.

The core is written in WASM, on top of the draft GC proposal. 
Much of the standard WASM tooling (like wat2wasm) doesn't support this extension yet, so you'll need to install the interpreter from https://github.com/WebAssembly/gc/tree/main to compile this WAT into WASM and rely on v8/node for running it.

## Stages

The compiler is split up into several stages:

wamin.wat: A handwritten, WebAssembly compiler for Min -> WAT.
minform.if: A Min compiler of Min -> WAT.
minformal.if: A Min compiler of Minformal, a larger subset of Informal.
informal.if: Full informal, with optimizations and continual evolution.


## Minform
Integers: List(Digit).
Strings: '"' (Any | '\"') '""
Literal: String | Number
Comment: '//' Any '/n'
Identifier: Alpha List(AlphaNumeric)
Atom: Literal | IdentifierExpr
CommaSep: (Atom ',' CommaSep) | Atom
Call: IdentifierExpr '(' CommaSep ')'
primitive types: u64

---------
Int a = 0
Int b = 1
Int add(Int x, Int y): __primitive_add(x, y)
add(a, b)



## Minformal

Everything in Min syntax, plus

macros
pattern matching
dynamic types
arrays
floats
operator precedence
conditions, loops.
Imports
type checking
structs

IdentifierExpr: Identifier '.' (IdentifierExpr | Identifier)

## Informal
The full, evolving language specification.