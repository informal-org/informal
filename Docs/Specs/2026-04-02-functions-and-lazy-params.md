# Functions and Lazy Parameters

Date: 2026-04-02

## Goal

Users can define named functions with `fn` and call them. A subset of functions — those with one eager parameter and one lazy (ALL_CAPS) parameter — can be invoked as infix operators using `op_identifier` syntax, causing their body to be inlined at the call site with lazy argument evaluation.

This is built in two phases: general function definition/call first, then lazy parameter inlining on top.

---

## Phase 1: General Function Definition and Call

### What is being built

A user writes `fn name(param1, param2): body` and later calls `name(arg1, arg2)`. The function body is parsed once at definition time into postfix tokens. Calls use a standard call convention (not inlining).

### Data flow: Function definition

```
Source:  fn add(a, b): a + b

Lexer produces syntaxQ:
  kw_fn, identifier("add"), l_paren, identifier("a"), comma,
  identifier("b"), r_paren, colon, grp_indent,
  identifier("a"), op_identifier("+"), identifier("b"), grp_dedent

Parser sees kw_fn:
  1. Consume the function name (identifier "add"). Register it in the current scope.
  2. Consume l_paren. Parse parameter list: register "a" and "b" as local symbols
     in a new child scope. Store parameter count (2).
  3. Consume r_paren, colon.
  4. Parse the indented body as a normal expression within the child scope.
     Body tokens are emitted into parsedQ in postfix order.
     Parameter references within the body resolve to their local positions
     via signed i16 offsets (standard symbol resolution).
  5. Emit a function-definition boundary token into parsedQ that marks:
     - the function name (interned identifier)
     - the parameter count
     - the length of the body in parsedQ tokens (so codegen knows the extent)
  6. Pop the child scope.
```

Key constraint: The function body is fully parsed at definition time. It sits in parsedQ as postfix tokens. The definition boundary token tells codegen where the body starts and ends.

### Data flow: Normal function call

```
Source:  add(x, y)

Lexer produces syntaxQ:
  call_identifier("add"), identifier("x"), comma, identifier("y"), r_paren

Parser sees call_identifier("add"):
  1. Look up "add" in the symbol table. Confirm it resolves to a defined function.
  2. Parse arguments: evaluate each argument expression, emitting their
     postfix tokens into parsedQ.
  3. Emit a call token referencing the function, with argument count.
```

Codegen for normal calls: Standard call convention. Push arguments, branch-and-link to the function body, return value on the register stack. The function body in parsedQ is emitted as a callable block (not inlined).

### Required artifacts for Phase 1

1. **kw_fn prefix handler in the parser grammar table.** Currently `kw_fn` has no handler (TODO). This handler parses the definition syntax.

2. **Function entry in the symbol table.** A function definition must be registered so that call sites can resolve the name. The symbol entry must store:
   - Parameter count
   - Location of the body in parsedQ (start index, length)
   - Which parameters are lazy (ALL_CAPS) vs eager (needed for Phase 2)

3. **Function body boundary tokens in parsedQ.** Codegen needs to know where the function body starts and ends. This could be a pair of tokens (fn_begin/fn_end) or a single token with a length field.

4. **call_identifier handler update.** Currently call_identifier only handles syscalls in codegen. It must be extended to handle user-defined function calls by looking up the function in the symbol table.

5. **Codegen: function body emission.** The codegen walker must recognize function bodies in parsedQ and emit them as callable blocks (label + instruction sequence + return).

6. **Codegen: call emission.** When codegen encounters a call token, it emits argument-passing instructions and a branch-and-link to the function label.

### Constraints for Phase 1

- Single-pass parsing. The function must be defined before it is called (no forward references).
- Function body tokens sit in parsedQ. Codegen must skip over them during linear walking (they are jumped to, not fallen through).
- Parameter symbols are scoped to the function body. They must not leak into the enclosing scope.
- Symbol resolution within the body uses the same signed i16 offset mechanism as all other symbols.

---

## Phase 2: Lazy Parameters and Inline Expansion

### What is being built

A function with exactly two parameters — one eager (lowercase) and one lazy (ALL_CAPS) — can be invoked as an infix operator. When the parser sees `a OR b`, it inlines the body of `OR` at the call site, substituting parameter references with the actual argument tokens.

### Identification

A lazy function is identified by its parameter signature during definition:
- Exactly 2 parameters
- One lowercase (eager), one ALL_CAPS / const_identifier (lazy)
- The eager parameter is always the first (left operand), the lazy parameter is always the second (right operand)

The parser records this in the symbol table entry at definition time.

### Lazy vs eager parameter semantics

**Eager parameter:** The left operand is fully evaluated before inline expansion begins. Its result is the top of the evaluation stack. During inline expansion, the parser emits a local variable declaration that binds this stack-top value to the eager parameter's name. All references to the eager parameter in the body are normal identifier references to this local binding, resolved via standard i16 offsets. The eager parameter may be referenced multiple times in the body — each reference reads the same already-computed value.

**Lazy parameter:** The right operand is NOT evaluated before inline expansion. The tokens comprising the lazy argument's expression are held in syntaxQ unconsumed. During body splice, when the lazy parameter is referenced, the parser parses the right operand from syntaxQ at that moment, emitting the resulting postfix tokens directly into parsedQ at the splice position. The lazy parameter must appear exactly once in the body — this is a linear splice (no duplication, no dropping). If control flow never reaches the splice point, the lazy argument is never evaluated.

### Data flow: Lazy function inline expansion

```
Source:  x OR y

Where OR was defined as:
  fn OR(first, SECOND):
      if bool(first):
          first
      else:
          SECOND

Lexer produces syntaxQ for the call site:
  identifier("x"), op_identifier("OR"), identifier("y")

Parser processing:
  1. The left operand "x" is parsed first by the Pratt parser as a normal
     expression. Its postfix tokens are already emitted into parsedQ.
     The left operand is the eager argument — it is fully evaluated.
     At this point, the result of "x" is conceptually on top of the
     evaluation stack in parsedQ.

  2. Parser encounters op_identifier("OR") as an infix operator
     (binding power: Comparison / 60).

  3. Parser looks up "OR" in the symbol table. Finds it is a lazy function.

  4. Parser begins inline expansion:

     a. Emit a local variable declaration for the eager parameter "first".
        This binds the top-of-stack value (the already-evaluated left operand)
        to the name "first" in a new inline scope. In parsedQ, this is an
        identifier token with flags.declaration = 1.

     b. Walk the stored body tokens of OR and emit them into parsedQ:
        - Eager param references ("first"): Emit as normal identifier tokens.
          These resolve to the local declaration from step (a) via standard
          i16 offset resolution. Can appear multiple times.
        - Lazy param references ("SECOND"): At this point, parse the right
          operand expression from syntaxQ (consuming "y"), emitting the
          resulting postfix tokens into parsedQ at this position. Appears
          exactly once.
        - All other tokens: Copy directly into parsedQ.

  5. Pop the inline scope.

  6. The result is that parsedQ contains the full inlined body with the
     eager argument bound to a local and the lazy argument spliced in place.
```

### Detailed expansion: Eager parameter binding

When inline expansion begins, the eager argument's result is already on top of the evaluation stack (its tokens were emitted to parsedQ before the operator was encountered). The expansion emits a declaration token that binds this value to the eager parameter name, creating a local variable in an inline scope.

This works identically regardless of whether the left operand is simple or complex:

**Simple case:** `x OR y` — identifier(x) is in parsedQ, then declaration of "first" binds that value.

**Complex case:** `foo(x) + 1 OR y` — the postfix tokens for `foo(x) + 1` are in parsedQ, their result is on the stack, then declaration of "first" binds that result.

In both cases, subsequent references to "first" in the body are normal identifier lookups that resolve to the declaration via i16 offsets.

### Detailed expansion: Lazy parameter splice

The lazy parameter uses a different mechanism. Its argument tokens have NOT been parsed from syntaxQ yet. When the body walk encounters the lazy parameter reference, the parser:

1. Parses the right operand expression from syntaxQ using the op_identifier's binding power
2. Emits the resulting postfix tokens directly into parsedQ at the current position
3. Continues walking the remaining body tokens

This is a linear splice — the lazy parameter reference in the body is replaced by the parsed argument tokens. Since the lazy parameter appears exactly once in the body, the right operand is parsed exactly once.

### Example: Full expansion trace

```
Source:  x OR y + 1

Where OR is:
  fn OR(first, SECOND):
      if bool(first):
          first
      else:
          SECOND

Parsing with Pratt (OR has Comparison/60 binding power):
  1. Parse "x" -> emit identifier(x) to parsedQ

  2. See op_identifier("OR"), binding power 60

  3. Look up OR -> lazy function, begin inline expansion

  4. Emit declaration of "first" -> binds top-of-stack (value of x)

  5. Walk body tokens, emitting into parsedQ:
     - "if" -> emit if
     - "bool(" -> emit call to bool
     - "first" -> emit identifier(first), resolves to declaration at step 4
     - ")" -> close call
     - ":" -> then branch
     - "first" -> emit identifier(first), resolves to same declaration (second use, fine)
     - "else:" -> else branch
     - "SECOND" -> SPLICE: parse right operand from syntaxQ with binding power 60
       -> consumes "y", "+", "1" -> emits identifier(y), int(1), op_add
     - end of body

  Result in parsedQ (conceptually):
    identifier(x), decl(first),
    if, call_bool, identifier(first), ...,
    then: identifier(first),
    else: identifier(y), int(1), op_add
```

The eager parameter "first" appears twice in the body (once in `bool(first)`, once as the then-branch value). Both references resolve to the same local declaration. The lazy parameter "SECOND" appears once and is replaced by the parsed right operand.

### Body token storage

The stored body tokens for a lazy function distinguish between two kinds of parameter references:

- **Eager parameter references**: Stored as normal identifier tokens. During expansion, they are copied into parsedQ and resolve to the local declaration emitted at the start of expansion. No special marking needed — they are just identifiers.

- **Lazy parameter references**: Stored with a marker indicating they are splice points. During expansion, these are NOT copied into parsedQ. Instead, they trigger parsing of the lazy argument from syntaxQ. The splice marker must be distinguishable from a normal identifier reference.

Only lazy parameter positions need to be specially marked in the stored body. Eager parameter references look like ordinary identifier tokens.

### op_identifier exclusivity

`op_identifier` is exclusively for lazy function calls. When the parser encounters an op_identifier in infix position, it always attempts to look up the name as a lazy function and perform inline expansion. If the lookup fails (no such function defined), this is a parse error.

This means built-in operators (+, -, *, /, etc.) are NOT op_identifiers. They have their own token types. op_identifier is reserved for user-defined infix operators that are backed by lazy functions.

### Required artifacts for Phase 2

1. **Lazy function detection at definition time.** When parsing `fn`, check if the parameter signature matches the lazy pattern (2 params, one ALL_CAPS). Store a flag in the symbol table entry.

2. **op_identifier infix handler in the parser.** Currently op_identifier has Comparison binding power but presumably uses a default/generic infix handler. It needs a specialized handler that:
   - Looks up the operator name in the symbol table
   - Pushes an inline scope and emits a declaration token for the eager parameter (binding the stack-top value)
   - Walks the stored body tokens, copying them into parsedQ
   - At lazy parameter splice points, parses the right operand from syntaxQ
   - Pops the inline scope

3. **Body token storage with lazy parameter positions marked.** The stored body tokens must clearly mark lazy parameter splice points. Eager parameter references need no special marking — they are ordinary identifiers that will resolve to the inline scope's local declaration.

4. **Inline scope management.** The expansion creates a scope containing the eager parameter declaration. This scope must be pushed before body tokens are walked and popped after. References to the eager param within the walked body resolve via standard i16 offsets against this scope.

5. **No codegen changes for the inlined body.** Since the body is spliced directly into parsedQ as normal postfix tokens with standard identifier resolution, codegen processes them like any other expression. The `if`/`else` handling must already work for this to function.

### Constraints for Phase 2

- Lazy functions must be defined before they are used as operators (single-pass, no forward references).
- **Eager parameters** may be referenced multiple times in the body. They are bound to a local variable during expansion and each reference reads the same pre-computed value.
- **Lazy parameters** must appear exactly once in the body. This is a linear splice — the argument is parsed once and emitted once. Referencing a lazy parameter zero times means the right operand is never parsed from syntaxQ (leaving unconsumed tokens — an error). Referencing it more than once would require parsing the right operand multiple times from syntaxQ (the tokens are already consumed after the first parse — also an error).
- The right operand is parsed with the binding power of the op_identifier (Comparison/60), so `a OR b + c` parses as `a OR (b + c)` only if `+` has lower precedence than OR. Since `+` typically has higher precedence (Additive/80) than Comparison/60, `b + c` binds tighter, so this parses as `a OR (b + c)`.
- Body tokens in parsedQ for the function definition itself become dead code if the function is only ever called via op_identifier (inline expansion). Dead code elimination is deferred — these tokens remain in parsedQ but codegen must skip them (same as Phase 1's skip-over for function bodies).
- No recursion: a lazy function's body must not contain an op_identifier call to itself. This would cause infinite expansion during parsing. A recursion guard is deferred but worth noting.

---

## Changes by component

### Lexer

No changes needed. The lexer already produces:
- `kw_fn` for the `fn` keyword
- `identifier` for lowercase names
- `const_identifier` for ALL_CAPS names
- `call_identifier` for `name(`
- `op_identifier` for infix operator names (uppercase word between expressions)

### Parser

1. **Add kw_fn prefix handler.** Parses function definition syntax: name, parameter list (with scope), body. Emits body tokens and boundary marker into parsedQ. Registers function in symbol table.

2. **Update op_identifier infix handler.** Look up the operator name. If it resolves to a lazy function, push an inline scope, emit eager parameter declaration, walk body tokens (splicing lazy param), pop scope. If not found, emit a parse error.

3. **Update call_identifier handler.** Currently only handles syscalls. Must also handle calls to user-defined functions by emitting a call token with argument references.

4. **Scope management for function bodies.** Push a child scope when entering a function body, register parameters as locals, pop when exiting. For inline expansion, push a lightweight inline scope for the eager parameter binding.

### Symbol resolution

No fundamental changes. Functions are registered as named symbols in scope. Parameter references within bodies resolve via existing i16 offset mechanism. The key addition is that function symbol entries carry metadata (param count, body location, lazy flag). During inline expansion, the eager parameter declaration is a normal declaration in the inline scope, and all references resolve via standard i16 offsets.

### Codegen

1. **Skip function bodies during linear walk.** When codegen encounters a function-definition boundary token, it must skip the body tokens (they are jumped to via calls, not executed sequentially).

2. **Emit function bodies as callable blocks.** Each function body becomes a labeled block with a return sequence.

3. **Emit call instructions.** When encountering a call token, emit argument setup and branch-and-link.

4. **No special handling for inlined lazy bodies.** The splice already produced normal postfix tokens in parsedQ with standard identifier resolution, so codegen processes them like any other expression. The `if`/`else` handling must already work for this to function.

---

## Edge cases

1. **Nested lazy calls.** `a OR b AND c` — the right operand of OR is `b AND c`, which is itself a lazy call. The splice for OR reaches the SECOND parameter, at which point the parser parses `b AND c`, which triggers inline expansion of AND. This should work naturally since the parser handles it recursively, but the interaction with binding powers needs to be correct.

2. **Left operand is a complex expression.** `foo(x) + 1 OR bar(y)` — the eager (left) argument to OR is the result of `foo(x) + 1`, which is multiple tokens in parsedQ. The eager parameter declaration binds the stack-top result. No special handling needed — the declaration binds whatever value is on top of the stack.

3. **Lazy argument is a complex expression.** `a OR if cond: x else: y` — the lazy argument includes control flow. When the splice reaches the lazy param, the parser must parse this entire expression from syntaxQ. This should work if the Pratt parser handles it, but the binding power interaction matters.

4. **Operator precedence.** `a OR b AND c` with both OR and AND as lazy functions both having Comparison binding power (60). Same-precedence infix operators need defined associativity. Left-associative: `(a OR b) AND c`. Right-associative: `a OR (b AND c)`. Which is it?

5. **Function defined but never called.** Its body tokens sit in parsedQ. Codegen must recognize and skip them. This is dead code — deferred, but the skip mechanism is essential from day one.

6. **Calling a lazy function with normal call syntax.** `OR(a, b)` — is this valid? The function exists in the symbol table. If call_identifier resolves it, does it use normal call convention (evaluating both arguments eagerly)? Or is it an error? Decision: this needs clarification, but given "op_identifier is exclusively for lazy function calls," the reverse question is whether lazy functions can also be called normally.

7. **Shadowing.** A local variable named the same as a function. Standard scope resolution should handle this, but worth testing.

8. **Empty function body.** `fn noop(): ...` — what does this mean? Probably not relevant for the initial implementation but worth noting.

9. **Function with only lazy params or only eager params but matching the 2-param shape.** `fn FOO(BAR, BAZ):` — both params are ALL_CAPS. Is this a lazy function? The rule says "one eager, one lazy." Two lazy params should not match. Similarly, `fn foo(a, b):` with two eager params is just a normal function.

10. **Eager parameter referenced zero times.** The eager parameter is bound to a local via declaration, but never referenced in the body. The declaration still consumes the stack-top value. This is valid but wasteful — the binding is unused. Not an error, just dead code within the inlined body.

---

## Observable truths (test criteria)

For the goal to be met, these things must all be true:

### Phase 1
1. `fn add(a, b): a + b` followed by `add(1, 2)` produces the value 3.
2. Functions can reference variables from their enclosing scope (closure over constants).
3. Function parameters do not leak into the enclosing scope.
4. Calling an undefined function produces a parse error.
5. Calling a function with wrong argument count produces a parse error.
6. Functions can call other previously-defined functions.

### Phase 2
7. `fn OR(first, SECOND): if bool(first): first else: SECOND` followed by `true OR expensive()` evaluates to `true` without calling `expensive()`.
8. `false OR fallback()` evaluates `fallback()` and returns its result.
9. `a OR b AND c` resolves correctly according to binding power and associativity.
10. The right operand of a lazy call is not evaluated if the body's control flow does not reach the lazy parameter's splice point.
11. Nested lazy calls work: the right operand of one lazy call can itself be a lazy call expression.
12. Eager parameters can be used multiple times in the body: `fn OR(first, SECOND): if bool(first): first else: SECOND` — `first` appears in `bool(first)` and as the then-branch return value, both reading the same pre-computed value.

---

## Sub-problems in dependency order

1. **Function scope management.** Push/pop child scopes for function bodies with parameter registration. This must exist before function bodies can be parsed.

2. **Function definition parsing (kw_fn handler).** Parse the `fn name(params): body` syntax, emit body tokens to parsedQ with boundary markers, register the function in the symbol table. Depends on (1).

3. **Normal function call (call_identifier for user functions).** Extend call_identifier handling to resolve user-defined functions and emit call tokens. Depends on (2) for having functions to call.

4. **Function codegen.** Emit function bodies as callable labeled blocks. Emit call instructions at call sites. Skip function bodies during linear parsedQ walk. Depends on (2) and (3) for the tokens being in parsedQ.

5. **Lazy function detection.** At definition time, flag functions matching the lazy signature (2 params, one ALL_CAPS). Store a flag in the symbol table entry. Depends on (2).

6. **Inline expansion via op_identifier.** Push inline scope, emit eager param declaration (binding stack-top), walk body tokens (copying eager param refs as normal identifiers, splicing lazy param by parsing right operand from syntaxQ), pop inline scope. Depends on (2) and (5).

---

## Assumptions still being made

- `if`/`else` parsing and codegen already work or will work before lazy functions need them. The OR example body uses if/else.
- `bool()` or truthiness testing exists or will exist. The OR example calls `bool(first)`.
- Binding power for op_identifier (Comparison/60) is correct for all intended lazy operators. Different lazy operators might want different precedences.
- Left-to-right associativity for same-precedence op_identifiers.

## Deferred items

- Dead code elimination for uncalled function bodies in parsedQ.
- Recursion guard for self-referencing lazy function bodies.
- Variable binding power per lazy function (all share Comparison/60 for now).
- Forward references / mutual recursion.
