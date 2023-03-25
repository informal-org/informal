(module
    (memory 1)
    (export "memory" (memory 0))




	(type $Tokens (array (mut i64)))		;; Stack of AST tokens as they're processed.
	(type $Lexer (struct 
		(field $buffer (mut i32))		;; Pointer to the input string base.
		(field $index (mut i32))		;; Current index into buffer.
		(field $tokens (ref $Tokens))
	))

	;; (export "WasmTokens" (type $Tokens))

	;; Initialize a new Lexer instance.
	(func $init (export "init") (param $bufbase i32) (result externref)
		(local $newLex (ref $Lexer))
		(local.set $newLex (struct.new $Lexer 
			(local.get $bufbase)
			(i32.const 0)
			;; Element, length
			(array.new $Tokens (i64.const 0) (i32.const 0))
		))
		(extern.externalize (local.get $newLex))
		;; (local.get $newLex)
		;; (i32.const 0)
	)

	(func $next (param $self (ref $Lexer)) (result i32)
		;; Increment Lexer indexer.
		;; index = index + 1
		(struct.set $Lexer $index (local.get $self) 
		
			(i32.add (i32.const 1) (struct.get $Lexer $index (local.get $self)))
		)
		;; (local.get $idxPlus1)
		(struct.get $Lexer $index (local.get $self))
	)

	(func $getBufferLength (param $self (ref $Lexer)) (result i32)
		;; Read length header from string buffer.
		;; Buffer = [i32 length, ...u8 contents]. 
		(i32.load (struct.get $Lexer $buffer (local.get $self)))
	)

	(func $lex (export "lex") (param $self (ref $Lexer)) (result (ref $Lexer))
		(loop $buf_loop
			;; while self.index < buffer.length, loop
			;; (struct.get $Lexer $index (local.get $self))
			(br_if $buf_loop 			
				
				(i32.lt_s 
					(call $next (local.get $self))
					(call $getBufferLength (local.get $self))
				))

		)
		(local.get $self)
	)


	(func $main (export "_start")
	)
)