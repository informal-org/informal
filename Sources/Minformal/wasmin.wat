(module
    (memory 1)
    (export "memory" (memory 0))

	;; (type $Tokens (array (mut i64)))	;; Stack of AST tokens as they're processed.

	;; (global $tokens (mut (ref $Tokens)) (array.new_default $Tokens (i32.const 0)))
	(global $buffer (mut i32) (i32.const 0))	;; Pointer to input string base.
	(global $bufLen (mut i32) (i32.const 0))	;; Input length.
	(global $index (mut i32) (i32.const 0))		;; Current index.
	(global $ch (mut i32) (i32.const 0))		;; Current character.
	(global $heaptop (mut i32) (i32.const 0))	;; Next free space in heap.

	;; (func $alloc (export "alloc") (param $allocsize i32) (result i32)
	;; Return pointer to base+length. If heaptop + length > memory.size * page size, grow.
	;; Div by difference << page size.
	;; 	()
	;; )

	;; Array insert - u64 array pointer. u64 value.
		;; Check length < capacity. Else resize. Re-read cap and base.
		;; indirect pointer. Insert. Increment size. Return new pointer with updated length.
	;; Insert assuming cap (for static arrays).

	;; Get length - i32
	;; Get capacity - i32
	;; New Array (capacity)
		;; Capacity (default 8). Pointer.

	;; Resize
		;; Original array.
		;; Alloc new with double size.
		;; Update capacity, pointer.
		;; memory.copy from source to destination.


	;; Base class region.
	;; Create class. 
		;; Implicit ID by index.
		;; -> Fields. (List of Types. Future name.)
		;; Future -> name pointer.
		;; Next Object ID -> Pointer. Region ID + Object ID.

	;; Create object (class)
		;; Takes (+ bump up) next class object ID. 
	 		;; If > region size, create next page and link new page to old.
		;; Finds index. Fills in field data.
		;; Return ID.

	;; Create Pointer Slice. u64
	;; Byte aligned pointer. 
	;; Create inline value.
	;; Const - Symbol, Token. 
	;; Type string, object, function.

	;; String -> Integer. u64 float.
		;; Init 0.
		;; Check if digit.
		;; Digit -> number. ASCII subtract base digit number.
		;; value = (value * 10) + digit.
		;; If non-digit, return.

	;; Table functions
	;; Type functions 
	;; 		digit, whitespace, alpha, precedence gte, precedence gt.
	;; Create Each parser node. Need good utilities for these, since the rest of the code will all rely on it.
		;; Structure. -> Fields list (obj pointer or string pointer, etc.)
			;; Intersection -> Fields. Table pointer
		;; Createfn for dependent types. It'd pre-compute the dependent type values.
		;; And add in result.
		;; Init function for each object type.

		;; Closure type. Funcref, List of args. Check length, and invoke specilized apply fn by that.
		;; Or just treat "expr" as a special case. Store binding power and give options when invoked.

	;; Base match. Eval by Type. Bool and a ref to other Type. Or eval closure.
	;; additional cases to switch by type. If structure, join, many, choice.

	;; Match
	;; Literal. Value = current token. Increment.
	;;		New index. Literal token.
	;; Choice
		;; Loop. Recurse match. Return first match. Inc pointer. Else, return pointer = initial.
	;; Structure
		;; Match each elementwise. Store result.
	;; Join
		;; Match one element against all options. All must pass.
	;; Many
		;; Greedy match as long as things match.


	;; Lexer - restrucure it into a match-based lexer.
	;; TODO: Can we do indentation handling just with another recursive context var, like precedence?
	;; Ignore mixed indentation for simplicity. Just tabs.
	;; Start with {, } for the MVP version.
	;; String quotes, comments.
	;; Delimiters, whitespace
	;; Identifier, Digit -> Number.

	;; Parser
	;; Same process, but with the higher-level tokens.
	;; Builds an internal stack for each array-list. Recursion based now?
	;; This is what parses into the Form structure.
	;; So Structure = Object.
	;; List -> Many, Choice, Join = Type list.

	;; Interpreter
	;; Match. Transform. 
	;; Env of built-ins. Op -> Table ops.
	;; Constants. String name -> symbol.
	;; User-defined identifiers.
	;; Evaluate. Return value.

	;; Initialize a new Lexer instance and run lexing.
	(func $init (export "init") (param $bufbase i32) (result i32)
		(global.set $buffer (local.get $bufbase))
		(global.set $bufLen (i32.load (local.get $bufbase))) ;; 32 bit length header.
		(global.set $index (i32.const 4))		;; Skip past 4 byte length header.
		(global.set $ch (i32.load8_u (global.get $index)))
		;; (global.set $tokens (array.new $Tokens (i64.const 0) (i32.const 0)))
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