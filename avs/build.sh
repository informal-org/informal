#!/bin/bash
# Builds the Arevel Standard Library

cd avs
wasm-pack build -t no-modules --release

# TODO: Portable path version of this
~/code/wabt/bin/wasm2wat ../target/wasm32-unknown-unknown/release/avs.wasm --generate-names -o avs.wat

# Find injection point. f2 - line number. delimeter :
export line=$(grep -rne "func \$__av_run (" avs.wat | cut -f2 -d:)

rm header.wat
rm footer.wat
# Split into header.wat and footer.wat
awk "NR <= $line { print >> \"header.wat\"; next } { print >> \"foot_tmp.wat\"}" avs.wat

# Remove main content from footer (+2 to skip 1 lines, because obviously). 
# Can probably combine this into the awk step. Meh.
tail -n +2 foot_tmp.wat > footer.wat
rm foot_tmp.wat
