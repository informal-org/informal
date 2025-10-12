# Lexer Spec
## Input

**Chunked Processing:**
- Input arrives as byte slices (chunks) of the source file
- Lines are NEVER split across chunks
- Lexer yields after each line (enabling incremental IDE processing)
- All positions (line numbers, character indices) are **chunk-relative**

**Processing Mode:**
- **IDE mode:** Process line-by-line for incremental updates
- **Batch mode:** Process entire file as single chunk

### Limits and Constants

```zig
MAX_IDENTIFIER_LENGTH    = 255      // Single-byte length encoding
MAX_STRING_LENGTH        = 65536    // u16 length field
MAX_LITERAL_NUMBER       = 65536    // Numbers ≤ this stored inline
MAX_TOKENS_PER_LINE      = 65535    // u16 offset to previous newline
MAX_INDENT_DEPTH         = 21       // 21 levels × 3 bits = 63 bits
MAX_INDENT_INCREMENT     = 7        // Fits in 3 bits (values 1-7). Max number of consecutive indent characters per-level.
RECOMMENDED_INDENT_SIZE  = 4        // User guidance
```

**Indentation Rules:**
- **Spaces only** - tabs produce error diagnostics
- Maximum 7 spaces per single indent level
- Maximum 21 nested indentation levels
- Indentation tracked via a "tiny stack" packed into a single u64 (3 bits per level)

### Ownership and Interning

**Current Behavior:**
- Lexer interns all identifiers, strings, numbers, floats
- Tokens carry interned indices (not raw text)
- Hash maps: `symbolTable`, `internedStrings`, `internedNumbers`, `internedFloats`

**Future Migration:**
- Consider moving interning to parser for better incrementality
- Would reduce lexer allocations, make it purely IO-bound

---

## Output: Dual Queues to separate semantic and formatting tokens

### Two Token Streams

**Syntax Queue (`syntaxQ`):**
- Semantically meaningful tokens
- Identifiers, operators, literals, grouping, indentation
- Used by parser for AST construction

**Auxiliary Queue (`auxQ`):**
- Formatting and metadata tokens  
- Whitespace, comments, documentation blocks
- Used by formatter, error reporting, IDE features

### Cross-Stream Synchronization

**Alt Bit Protocol:**
- Each token has 1-bit `alt` flag
- If set: next token is in the **other** queue
- Enables single-pass synchronized traversal of both streams


### Newline Cross-Indexing

Newlines appear in **both queues** with complementary data:

**Syntax Queue Newline:**
```zig
Token.lex(
    kind: sep_newline,
    value: auxQueueIndex,      // u32: points to aux newline
    aux: prevLineTokenOffset   // u16: tokens since last newline
)
```

**Aux Queue Newline:**
```zig
Token.lex(
    kind: aux_newline, 
    value: charIndex,          // u32: character position in buffer
    aux: absoluteLineNumber    // u16: line number in chunk
)
```

This allows:
- Parser: fast syntax token traversal with line metadata access
- Formatter: character-precise positioning
- Error reporting: both token-level and character-level locations

---

## Token Structure

### 64-bit Token Encoding

```
[8-bit kind][32-bit value][16-bit aux][8-bit flags]
```

**Fields:**
- `kind`: Token type enum (TK.identifier, TK.lit_number, etc.)
- `value`: Varies by kind (literal value, interned index, queue cross-ref)
- `aux`: Secondary data (length, offset, line number, etc.)
- `flags`: Contains `alt` bit for queue switching

### Token Categories

#### Identifiers
- **identifier**: `[a-z_][a-zA-Z0-9_ ]*` (lowercase start. Spaces are allowed in identifiers)
  - `value`: interned symbol index
  - `aux`: length in bytes
  
- **call_identifier**: identifier immediately followed by `(`
  - Enables lookahead-free parsing of function calls
  
- **type_identifier**: `[A-Z][a-zA-Z0-9_]*` Starts with uppercase with at least one lowercase
  - Examples: `Int`, `String`, `MyType`, `HttpRequest`
  
- **const_identifier**: `[A-Z_]+` (all uppercase. Cannot contain spaces). 
  - Examples: `MAX_SIZE`, `PI`, `DEFAULT_TIMEOUT`
  
- **op_identifier**: All uppercase, contextually after identifier
  - Examples: `value TRANSFORM result`, `items FILTER predicate`
  - Enables user-defined operators

#### Literals

**Numbers (`lit_number`):**
- Syntax: `[0-9]+` or `\.[0-9]+`  
- Small numbers are stored directly in the token if value ≤ MAX_LITERAL_NUMBER. 
  - `value`: numeric value (immediate)
  - `aux`: digit count
- Large numbers are interned into a constant pool if value > MAX_LITERAL_NUMBER:
  - `value`: interned constant pool index
  - `aux`: 0 (flag for pool lookup)

**Strings (`lit_string`):**
- Syntax: `"[^"]*"` with escape sequences
- Escape sequences: `\n \t \r \\ \"`
- Processing: **in-place** replacement in source buffer
- `value`: interned string index
- `aux`: processed length (after escape substitution)


#### Operators and Symbols

**Built-in Symbolic Operators:**
```
+  -  *  /  %  ^        // Arithmetic
<  >  <=  >=  ==  !=    // Comparison  
=                       // Assignment
.                       // Member access
:                       // Association
|                       // Choice/Union
```

**Multi-Character Operators:**
All use `=` as second character: `!=`, `*=`, `+=`, `-=`, `/=`, `<=`, `>=`, `==`

**Word Operators (Built-in):**
```
AND  OR  NOT            // Logical
AS   IN  IS             // Type/membership
```

**Range Operators (TODO):**
```
..   ...                // Inclusive/exclusive ranges
```
Note: Currently not implemented in `token_dot()`

#### Separators

- **sep_comma**: `,` 
- **sep_newline**: `\n` (dual-queue emission, see above)

#### Grouping

- **Parentheses**: `(` `)` 
- **Brackets**: `[` `]`
- **Braces**: `{` `}`

#### Indentation Structure

Indentation is semantically meningful and represented in the output queue with indent and dedent tokens where indentation begins and ends. 

- **grp_indent**: Increased indentation at line start
  - Emitted when `spaces > current_depth`
  - Updates tiny stack and depth
  
- **grp_dedent**: Decreased indentation at line start
  - Emitted when `spaces < current_depth`
  - May emit **multiple** dedents to match nested levels. A dedent token will be emitted for each scope/block being closed.
  - Must align with previous indent levels (else error).

#### Auxiliary Tokens

- **aux_whitespace**: Horizontal formatting whitespace (spaces, not at line start and not in identifiers)
  - `value`: start index
  - `aux`: length
  
- **aux_indentation**: Tab character (error diagnostic)
  
- **aux_newline**: Newline metadata (see cross-indexing above)

- **aux_stream_start** / **aux_stream_end**: Stream boundaries

#### Comments (TODO: Improve)

- Line comments: `//` to end of line
- Doc blocks: `///` (multi-line, indented)
- **Current:** Consumed but not emitted as tokens
- **Planned:** Emit to aux queue for formatter preservation

---

## Lexical Grammar and State Machine

### High-Level Dispatch

Main loop dispatches on first character:

```
switch (ch):
    ' ':  countIndentation() or emitAux(whitespace)
    '\t': emitAux(aux_indentation) + error
    '\n': emitNewLine() + token_indentation()
    '.':  token_dot()  // Member access OR number OR range
    '0'..'9': token_number()
    'A'..'Z': token_upperstart(prevIdentifier=false)
    'a'..'z', '_': token_identifier()
    '"': token_string()
    SYMBOLS: emit single/multi-char operator
    GROUPING: emit grouping token
```

---

## Chunk Boundaries and State

### Cross-Chunk State

When processing next chunk, carry over:

**Required State:**
- `indentStack`: u64 tiny stack
- `depth`: u16 current indentation level
- `lineNo`: u16 (continues from previous chunk)
- `lineQIndex`: u32 (reset or continue?)
- `prevToken`: Token (for alt-bit continuity)

**Reset Per Chunk:**
- `index`: 0
- `lineChStart`: 0  
- `QIdx`: depends on chunking strategy

**Critical:** Lines never split across chunks, so no mid-token state needed

### Yielding Protocol

Lexer yields after each line in IDE mode:
- Allows incremental update when user types
- Enables partial re-lex of changed lines
- Must maintain state consistency across yields



## Character Classification

```
Whitespace:       ' ' (space only, tabs are errors)
Newline:          '\n'
Digit:            '0'-'9'
Lowercase:        'a'-'z' or '_'
Uppercase:        'A'-'Z'
Identifier Start: Lowercase
Type Start:       Uppercase
Quote:            '"'
Escape:           '\\'
Symbol Chars:     %*+,-./:<=>^|
Grouping:         ()[]{}
Delimiters:       ()[]{}\"'.,:;\t\n%*+-/^<=>
```
