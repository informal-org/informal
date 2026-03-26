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
```
 63       48 47                    16 15        8 7         0
┌───────────┬────────────────────────┬───────────┬──────────┐
│prev_tk(16)│   aux queue index (32) │sep_newline│ flags    │
└───────────┴────────────────────────┴───────────┴──────────┘
  prev_tk = tokens since last newline in syntaxQ (u16 offset)
  aux queue index = position of corresponding aux_newline
```

**Aux Queue Newline:**
```
 63       48 47                    16 15        8 7         0
┌───────────┬────────────────────────┬───────────┬──────────┐
│line_no(16)│    char index (32)     │aux_newline│ flags    │
└───────────┴────────────────────────┴───────────┴──────────┘
  line_no = absolute line number within chunk
  char index = byte position of \n in buffer
```


This allows:
- Parser: fast syntax token traversal with line metadata access
- Formatter: character-precise positioning
- Error reporting: both token-level and character-level locations

---

## Token Structure

### 64-bit Token Encoding

Tokens are encoded in one of three formats, which vary by kind.
```
[16-bit aux][32-bit value    ][8-bit kind][8-bit flags]
[22-bit aux  ][22-bit value  ][8-bit kind][8-bit flags]
[16-bit A][16-bit B][16-bit C][8-bit kind][8-bit flags]
```

**Fields:**
- `kind`: Token type enum (TK.identifier, TK.lit_number, etc.)
- `value`: Varies by kind (literal value, interned index, queue cross-ref)
- `aux`: Secondary data (length, offset, line number, etc.)
- `flags`: Contains `alt` bit for queue switching


**Flags byte** (bits 7:0):
```
  7  6  5  4  3  2  1  0
┌──────────────────┬──┬──┐
│   reserved (6)   │dc│al│
└──────────────────┴──┴──┘
  al = alt bit (next token is in other queue)
  dc = declaration (identifier is a declaration site)
```


### Token Categories

#### Identifiers
```
┌───────────┬────────────────────────┬───────────┬──────────┐
│length (16)│   symbol index (32)    │ kind (8)  │ flags    │
└───────────┴────────────────────────┴───────────┴──────────┘
length in bytes
Interned symbol index
```


| Kind               | Pattern                      | Notes                                                      | Examples                                      |
|--------------------|-----------------------------|------------------------------------------------------------|-----------------------------------------------|
| `identifier`       | `[a-z_][a-zA-Z0-9_ ]*`      | Lowercase start. Single spaces allowed inside.             | `thing`, `do_a_thing`, `fooBar`, `foo bar`    |
| `call_identifier`  | identifier + `(`            | Avoids lookahead in parser for function calls              | `sum(`, `parse_one(`, `my_func(`              |
| `type_identifier`  | `[A-Z][a-zA-Z0-9_]*`        | Uppercase start, at least one lowercase.                   | `Int`, `String`, `MyType`, `HttpRequest`      |
| `const_identifier` | `[A-Z_]+`                   | All uppercase, no spaces.                                  | `MAX_SIZE`, `PI`, `DEFAULT_TIMEOUT`           |
| `op_identifier`    | identifier + `[A-Z_]+`  | User-defined infix operator. Contextually after identifier. | `value TRANSFORM result`, `items FILTER predicate` |

#### Literals

**Numbers (`lit_number`):**
- Syntax: `[0-9]+` or `\.[0-9]+`  
- Small numbers are stored directly in the token if value ≤ MAX_LITERAL_NUMBER. 
(value ≤ 65536, stored inline)
```
 63       48 47                    16 15        8 7         0
┌───────────┬────────────────────────┬───────────┬──────────┐
│digits (16)│   numeric value (32)   │lit_number │ flags    │
└───────────┴────────────────────────┴───────────┴──────────┘
  digits = source character count    value = parsed integer
```

- Large numbers are interned into a constant pool if value > MAX_LITERAL_NUMBER:

```
 63       48 47                    16 15        8 7         0
┌───────────┬────────────────────────┬───────────┬──────────┐
│  0x0000   │  const pool index (32) │lit_number │ flags    │
└───────────┴────────────────────────┴───────────┴──────────┘
  arg1 (digit length) == 0 is the flag distinguishing pool lookup from inline
```


**Strings (`lit_string`):**
- Syntax: `"[^"]*"` with escape sequences
- Escape sequences: `\n \t \r \\ \"`
- Processing: **in-place** replacement in source buffer
```
 63       48 47                    16 15        8 7         0
┌───────────┬────────────────────────┬───────────┬──────────┐
│length (16)│  interned str idx (32) │lit_string │ flags    │
└───────────┴────────────────────────┴───────────┴──────────┘
  length = processed length after escape substitution
  Escapes: \n \t \r \\ \"   — replaced in-place in source buffer
```

#### Operators and Symbols

```
 63       48 47                    16 15        8 7         0
┌───────────┬────────────────────────┬───────────┬──────────┐
│  0x0000   │       0x00000000       │ kind (8)  │ flags    │
└───────────┴────────────────────────┴───────────┴──────────┘
  No payload. Token kind alone encodes the operation.
```


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
The first character maps to the kind via `MULTICHAR_BITSET` popcount index.


**Word Operators (Built-in):**

```
 63       48 47                    16 15        8 7         0
┌───────────┬────────────────────────┬───────────┬──────────┐
│  0x0000   │       0x00000000       │ kind (8)  │ flags    │
└───────────┴────────────────────────┴───────────┴──────────┘
```

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

```
 63       48 47                    16 15        8 7         0
┌───────────┬────────────────────────┬───────────┬──────────┐
│  0x0000   │       0x00000000       │ kind (8)  │ flags    │
└───────────┴────────────────────────┴───────────┴──────────┘
  No payload. Kind alone identifies the grouping type.
```

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

```
 63       48 47                    16 15        8 7         0
┌───────────┬────────────────────────┬───────────┬──────────┐
│length (16)│  start char index (32) │aux_wspace │ flags    │
└───────────┴────────────────────────┴───────────┴──────────┘
  Spaces between tokens (not at line start, not inside identifiers)
```
  
- **aux_indentation**: Tab character (error diagnostic)
```
 63       48 47                    16 15        8 7         0
┌───────────┬────────────────────────┬───────────┬──────────┐
│  0x0001   │    char index (32)     │aux_indent │ flags    │
└───────────┴────────────────────────┴───────────┴──────────┘
  Emitted when a tab character is encountered (always an error)
```
  
- **aux_newline**: Newline metadata (see cross-indexing above)

- **aux_stream_start** / **aux_stream_end**: Stream boundaries
```
 63       48 47                    16 15        8 7         0
┌───────────┬────────────────────────┬───────────┬──────────┐
│  0x0000   │       0x00000000       │ kind (8)  │ flags    │
└───────────┴────────────────────────┴───────────┴──────────┘
  aux_stream_end kind = 255 (sentinel for queue termination)
```

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
