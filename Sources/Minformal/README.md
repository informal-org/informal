# Minformal
Minformal is a minimal subset of Informal used to bootstrap the compiler.

The core is written in WASM, on top of the draft GC proposal. 
Much of the standard WASM tooling (like wat2wasm) doesn't support this extension yet, so you'll need to install the interpreter from https://github.com/WebAssembly/gc/tree/main to compile this WAT into WASM and rely on v8/node for running it.

## Stages

The compiler is split up into several stages:

win.wat: A handwritten, WebAssembly compiler for Min -> WAT.
min.if: A Min compiler of Min -> WAT.
minformal.if: A Min compiler of Minformal, a larger subset of Informal.
Successive versions will be developed in the general informal directory.

## Min
Integers: List(Digit).
Strings: '"' (Any | '\"') '""
Literal: String | Number
Comment: '//' Any '/n'
Identifier: Alpha List(AlphaNumeric)
Atom: Literal | IdentifierExpr
CommaSep: (Atom ',' CommaSep) | Atom
Call: IdentifierExpr '(' CommaSep ')'
primitive types: u64


No pattern matching or Macros.
No floats.
No math operators or precedence (use functions)
No array declaration syntax or indexing syntax (use functions)
No structs - use arrays.
No type checking.
No out-of-order definitions.
No error handling.
NO modules.


## Minformal

Everything in Min syntax, plus

pattern matching
macros
arrays
floats
operator precedence
conditions, loops.
Imports

IdentifierExpr: Identifier '.' (IdentifierExpr | Identifier)
