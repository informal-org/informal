set working-directory := 'Code/Compiler'


build:
    zig build

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

