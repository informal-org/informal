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