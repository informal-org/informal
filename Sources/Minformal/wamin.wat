(module
    (memory 1)
    (export "memory" (memory 0))

	(type $Tokens (array (mut i64)))	;; Stack of AST tokens as they're processed.

	(global $tokens (mut (ref $Tokens)) (array.new_default $Tokens (i32.const 0)))
	(global $buffer (mut i32) (i32.const 0))	;; Pointer to input string base.
	(global $bufLen (mut i32) (i32.const 0))	;; Input length.
	(global $index (mut i32) (i32.const 0))		;; Current index.
	(global $ch (mut i32) (i32.const 0))		;; Current character.
	(global $heaptop (mut i32) (i32.const 0))	;; Next free space in heap.

	(func $alloc (export "alloc") (param $allocsize i32) (result i32)
		()
	)

	;; Initialize a new Lexer instance and run lexing.
	(func $init (export "init") (param $bufbase i32) (result i32)
		(global.set $buffer (local.get $bufbase))
		(global.set $bufLen (i32.load (local.get $bufbase))) ;; 32 bit length header.
		(global.set $index (i32.const 4))		;; Skip past 4 byte length header.
		(global.set $ch (i32.load8_u (global.get $index)))
		(global.set $tokens (array.new $Tokens (i64.const 0) (i32.const 0)))
		(call $lex)
	)

	;; Advance lexer index to the next position in the buffer. Update current character.
	(func $next
		(global.set $ch (call $peek))
		(global.set $index (i32.add (i32.const 1) (global.get $index))))
	
	;; Peek at the next character without consuming it.
	(func $peek (result i32) (i32.load8_u (global.get $index)))

	;; Return whether we're at the end of the list.
	(func $endOfBuffer (result i32) 
		(i32.lt_s (global.get $index) (global.get $bufLen)))

	(func $lex (export "lex") (result i32)
		(loop $buf_loop
			;; while self.index < buffer.length, loop
			(call $next)
			(br_if $buf_loop (call $endOfBuffer))
		)
		;; (struct.get $Lexer $index (global.get $lexer))
		(global.get $index)
	)

	(func $main (export "_start"))
)