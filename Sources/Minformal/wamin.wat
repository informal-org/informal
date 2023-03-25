(module
    (memory 1)
    (export "memory" (memory 0))

	(type $Tokens (array (mut i64)))		;; Stack of AST tokens as they're processed.
	(type $Lexer (struct 
		(field $buffer i32)		;; Pointer to the input string base.
		(field $index i32)		;; Current index into buffer.
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

	(func $lex (export "lex") (param $self (ref $Lexer)) (result (ref $Lexer))
		(local.get $self)
	)


	(func $main (export "_start")
	)
)