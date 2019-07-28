#!/bin/bash
# Builds the Arevel Standard Library

######
# One-time pre-setup (manual)
# rustup target add wasm32-unknown-emscripten
# cargo instal wasm-gc
##########

cd avs
wasm-pack build -t no-modules --release -m force
# cargo build --target wasm32-unknown-emscripten --release


# TODO: Portable path version of this
# DO NOT use --generate-names, it has some bugs inserting invalid tokens for tables
~/code/wabt/bin/wasm2wat ../target/wasm32-unknown-unknown/release/avs.wasm -o avs.wat

# Find injection point for extern. f2 - line number. delimeter :
# Note: Use f2 for grep on mac. f1 for grep on ubuntu.
export header_line=$(grep -rne "func \$__av_inject_placeholder (" avs.wat | cut -f1 -d:)

rm header.wat
rm foot_tmp1.wat
rm foot_tmp2.wat
rm foot_tmp3.wat
rm footer.wat
# Split into header.wat and footer.wat
awk "NR < $header_line { print >> \"header.wat\"; next } { print >> \"foot_tmp1.wat\"}" avs.wat
# Remove first line
tail -n +2 foot_tmp1.wat > foot_tmp2.wat

# Find injection point where it's called in start
export call_line=$(grep -rne "call \$__av_inject_placeholder" foot_tmp2.wat | cut -f1 -d:)
awk "NR < $call_line { print >> \"header.wat\"; next } { print >> \"foot_tmp3.wat\"}" foot_tmp2.wat

# Remove main content from footer (+2 to skip 1 lines, because obviously). 
# Can probably combine this into the awk step. Meh.
tail -n +2 foot_tmp3.wat > footer.wat

rm foot_tmp1.wat
rm foot_tmp2.wat
rm foot_tmp3.wat
