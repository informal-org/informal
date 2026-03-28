set working-directory := 'Code/Compiler'


build:
    zig build

build-wasi:
	zig build -Dtarget=wasm32-wasi

build-wasm:
	zig build -Dtarget=wasm32-freestanding

basic-test:
    zig build && ./zig-out/bin/Former ../../Tests/FileTests/add.ifi

test:
	zig test src/filetest.zig --test-filter "filetest"

release:
    zig build -Doptimize=ReleaseFast

bench-build NAME='run': release
    hyperfine "./zig-out/bin/Former ../../Tests/FileTests/{{NAME}}.ifi"

run NAME='run':
	#!/usr/bin/env sh
	rm out.bin || true
	# zig run src/macho.zig
	zig build && ./zig-out/bin/Former ../../Tests/FileTests/{{NAME}}.ifi
	chmod +x out.bin
	./out.bin
	echo "\nRan with code: $?"
	[ $? -eq 42 ] || true
	# echo $?

informal NAME='run':
	./zig-out/bin/Former ../../Tests/FileTests/{{NAME}}.ifi
	chmod +x out.bin
	./out.bin
	echo "\nRan with code: $?"
	[ $? -eq 13 ] || true


generate:
	python3 ../../Tests/generate.py 10000 bench_10k.ifi

pratt:
	zig build -Dbenchmark=true -Dparser=pratt -Doptimize=ReleaseFast
	cp zig-out/bin/Former zig-out/bin/Former-pratt
	zig build -Dbenchmark=true -Dparser=default -Doptimize=ReleaseFast
	cp zig-out/bin/Former zig-out/bin/Former-default


bench-parser:
	hyperfine --warmup 10 -N './zig-out/bin/Former-default bench_10k.ifi' './zig-out/bin/Former-pratt bench_10k.ifi' './zig-out/bin/Former-claude_pratt bench_10k.ifi' 2>&1