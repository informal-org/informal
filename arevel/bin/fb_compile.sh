#!/bin/bash

# Compile the flatbuffer files used for interaction between runtime and the wasm sandbox
cd ../avs/src
flatc avfb.fbs --rust