(module
    (memory 1)
    (export "memory" (memory 0))

	(type $Tokens (array (mut i64)))		;; Stack of AST tokens as they're processed.
	(type $Lexer (struct 
		(field $buffer (mut i32))		;; Pointer to the input string base.
		(field $index (mut i32))		;; Current index into buffer.
		(field $tokens (ref $Tokens))
	))

	;; Initialize a new Lexer instance.
	(func $init (export "init") (param $bufbase i32) (result (ref $Lexer))
		(struct.new_canon $Lexer 
			(local.get $bufbase)
			(i32.const 0)
			;; Element, length
			(array.new_canon $Tokens (i64.const 0) (i32.const 0))
		)
	)

	(func $next (export "next") (param $self (ref $Lexer)) (result i32)
		;; Increment Lexer indexer.
		(local $idxPlus1 i32)
		(struct.get $Lexer $index (local.get $self))
		i32.const 1
		i32.add 
		local.tee $idxPlus1
		;; index = index + 1
		(struct.set $Lexer $index (local.get $self) (local.get $idxPlus1))
	)

	(func $getBufferLength (export "getBufferLength") (param $self (ref $Lexer)) (result i32)
		;; Buffer = [i32 length, ...u8 contents]
		(struct.get $Lexer $buffer (local.get $self))
		i32.load
	)

	(func $lex (export "lex") (param $self (ref $Lexer)) (result (ref $Lexer))
		loop $buf_loop
			;; while self.index < buffer.length, loop
			(call $next (local.get $self))
			(call $getBufferLength (local.get $self))
			i32.lt_s
			;; (struct.get $Lexer $index (local.get $self))
			br_if $buf_loop
		end
		(local.get $self)
	)


	(func $main (export "_start")
	)
)