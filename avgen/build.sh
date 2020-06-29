#!/bin/bash
# wasm-pack build
# cargo build --target wasm32-unknown-unknown --release
# wasm-gc ../target/wasm32-unknown-unknown/release/avgen.wasm -o ~/code/appy/appy/static/wasm/avgen.wasm
wasm-pack build --release
