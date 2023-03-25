(module
    (memory 1)
    (export "memory" (memory 0))

	(type $Tokens (array (mut i64)))		;; Stack of AST tokens as they're processed.
	(type $Lexer (struct 
		(field $buffer (mut i32))		;; Pointer to the input string base.
		(field $bufferLength (mut i32))
		(field $index (mut i32))		;; Current index into buffer.
	))

	(global $tokens (mut (ref $Tokens)) (array.new_default $Tokens (i32.const 0)))
	(global $lexer (mut (ref $Lexer)) (struct.new_default $Lexer))

	;; Initialize a new Lexer instance and run lexing.
	(func $init (export "init") (param $bufbase i32) (result i32)
		(global.set $lexer (struct.new $Lexer 
			(local.get $bufbase)
			(i32.load (local.get $bufbase)) ;; buffer.length
			(i32.const 0)
		))
		(global.set $tokens (array.new $Tokens (i64.const 0) (i32.const 0)))
		(call $lex)
	)

	;; Advance lexer index to the next position in the buffer.
	(func $next (result i32)
		;; index = index + 1
		(struct.set $Lexer $index (global.get $lexer) 
			(i32.add (i32.const 1) (struct.get $Lexer $index (global.get $lexer)))
		)
		;; Return whether we're at the end of the list.
		(i32.lt_s 
			(struct.get $Lexer $index (global.get $lexer))
			(struct.get $Lexer $bufferLength (global.get $lexer)))
	)

	(func $lex (export "lex") (result i32)
		(loop $buf_loop
			;; while self.index < buffer.length, loop
			(br_if $buf_loop (call $next))
		)
		(struct.get $Lexer $index (global.get $lexer))
	)


	(func $main (export "_start")
	)
)