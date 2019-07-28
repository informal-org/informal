/* 
Values in Arevel are either a primitive u64 value or an object.
Primitive values are interpreted as doubles for fast math.
If the number is a NaN, we-re-use the unused bits to pack pointers and compact values into it. 

0 00000001010 0000000000000000000000000000000000000000000000000000 = 64
1 11111111111 1000000000000000000000000000000000000000000000000000 = nan
Type (3 bits). Payload 48 bits.
The header type bits are used for:
Type: [False(0)/True(1)] [Pointer(0)/Symbol(1)] [String(0), Object(1)]
This allows fast boolean checks and type checks for strings.

Small strings up to 6 bytes are stored directly as constant symbols without object overhead.
Further optimization - huffman coding of common bytes. Could get us another 50% (Future)

String pointer payloads additionally store length (up to 65k) for fast length access and
inequality check without dereferencing.
Pointer types can have payloads for ranged pointers or direct access into an object's field.

There's a large Symbol space used to store all keywords, functions & user-defined symbols.
Symbols generally evaluate to themselves.
Function symbols encode their arity in their payload (max 64 parameters).
Symbols 0-256 reserved for keywords.
*/

// Data format

// 8 = 1000 in binary
pub const SIGNALING_NAN: u64 = 0xFFF8_0000_0000_0000;
pub const QUITE_NAN: u64 = 0xFFF0_0000_0000_0000;

pub const LOW32_MASK: u64 = 0x0000_0000_FFFF_FFFF;
pub const HIGH32_MASK: u64 = 0xFFFF_FFFF_0000_0000;

// Clear all type bits. Preserve value bits.
pub const PAYLOAD_MASK: u64 = 0x0000_FFFF_FFFF_FFFF;

// 0 False. 1 True.
pub const VALHEAD_TRUTHY_MASK: u64 = 0x0004_0000_0000_0000;
// 0 = Pointer. 1 = Symbol.
pub const VALHEAD_REFTYPE_MASK: u64 = 0x0002_0000_0000_0000;
// 0 = String. 1 = Object.
pub const VALHEAD_OBJTYPE_MASK: u64 = 0x0001_0000_0000_0000;


// 0-8 Invalid NaN (Do Not Use). 7 valid values total.
// These constant values are based on the bit masks above

// Pointer to error values
pub const VALUE_F_PTR_OBJ: u64 = 0xFFF9_0000_0000_0000;
// Reserved symbol for empty string for bool & str type checking.
pub const VALUE_F_SYM_STR: u64 = 0xFFFA_0000_0000_0000;
// Symbol space for empty values and other "Falsey" symbols.
pub const VALUE_F_SYM_OBJ: u64 = 0xFFFB_0000_0000_0000;
// Pointer to full string objects. 16 bit payload of short length. 
pub const VALUE_T_PTR_STR: u64 = 0xFFFC_0000_0000_0000;
// Pointer to object references. 4 bit payload.
pub const VALUE_T_PTR_OBJ: u64 = 0xFFFD_0000_0000_0000;
// Small strings (up to 6 bytes) encoded directly as payload.
pub const VALUE_T_SYM_STR: u64 = 0xFFFE_0000_0000_0000;
// Symbol space (Functions, keywords, user-defined symbols, etc.)
pub const VALUE_T_SYM_OBJ: u64 = 0xFFFF_0000_0000_0000;


// Falsey/empty value symbols 
// (00-FF reserved for internal symbols for indexing into precedence lookup table)
pub const SYMBOL_FALSE: u64             = 0xFFFB_0000_0000_0040;     // 64
pub const SYMBOL_NONE: u64              = 0xFFFB_0000_0000_0041;
pub const SYMBOL_EMPTY_ARR: u64         = 0xFFFB_0000_0000_0042;


// Empty string - Different header because of the string type bits.
// Set to a value outside the reserved precedence range.
pub const SYMBOL_EMPTY_STR: u64         = 0xFFFA_0000_0000_FFFF;


// Internal sentinal nodes for hash tables.
pub const SYMBOL_SENTINEL_EMPTY: u64    = 0xFFFB_0000_0000_004A;
pub const SYMBOL_SENTINEL_DELETED: u64  = 0xFFFB_0000_0000_004B;
pub const SYMBOL_SENTINEL_SENTINEL: u64 = 0xFFFB_0000_0000_004C;


// Truthy value symbols
// Like above, 00-FF reserved for precedence lookup. 
// Note: The reserved keyword numbers should be unique (regardless of truthy/falsey).
pub const SYMBOL_TRUE: u64              = 0xFFFF_0000_0000_0080;    // 128


// For built in classes (Use to_symbol to encode these as symbols)
// Object class constants for built-in types.
pub const AV_CLASS_OBJECT: u32 = 1025;
pub const AV_CLASS_CLASS: u32 = 1026;
pub const AV_CLASS_FUNCTION: u32 = 1027;
pub const AV_CLASS_ENVIRONMENT: u32 = 1028;
pub const AV_CLASS_STRING: u32 = 1029;





//////////////////////////////////////////////////////////////
//                      Error Objects                       //
//////////////////////////////////////////////////////////////
// Top 16 bits = Error code. Bottom 16 = Pointer to obj with metadata.

pub const VALUE_ERR: u64 = 0xFFF9_0000_0000_0000;


// Convention: Higher bits for earlier stages. parsing stage -> execution stage.
// Important! Ensure that constants are not re-used!
pub const PARSE_ERR: u64                    = 0xFFF9_0100_0000_0000;
pub const INTERPRETER_ERR: u64              = 0xFFF9_0010_0000_0000;
pub const RUNTIME_ERR: u64                  = 0xFFF9_0001_0000_0000;

// Parsing errors
pub const PARSE_ERR_UNTERM_STR: u64         = 0xFFF9_0200_0000_0000;
pub const PARSE_ERR_INVALID_FLOAT: u64      = 0xFFF9_0300_0000_0000;
pub const PARSE_ERR_UNKNOWN_TOKEN: u64      = 0xFFF9_0400_0000_0000;
pub const PARSE_ERR_UNEXPECTED_TOKEN: u64   = 0xFFF9_0500_0000_0000;
pub const PARSE_ERR_UNMATCHED_PARENS: u64   = 0xFFF9_0600_0000_0000;

// Type checking errors
pub const RUNTIME_ERR_INVALID_TYPE: u64     = 0xFFF9_0001_0000_0000;
// This operation is not allowed with NaN values
pub const RUNTIME_ERR_TYPE_NAN: u64         = 0xFFF9_0002_0000_0000;

// Expected number
pub const RUNTIME_ERR_EXPECTED_NUM: u64     = 0xFFF9_0003_0000_0000;
pub const RUNTIME_ERR_EXPECTED_BOOL: u64    = 0xFFF9_0004_0000_0000;
pub const RUNTIME_ERR_UNK_VAL: u64          = 0xFFF9_0005_0000_0000;
pub const RUNTIME_ERR_CIRCULAR_DEP: u64     = 0xFFF9_0006_0000_0000;
pub const RUNTIME_ERR_MEMORY_ACCESS: u64    = 0xFFF9_0007_0000_0000;

pub const RUNTIME_ERR_EXPECTED_STR: u64     = 0xFFF9_0008_0000_0000;

// Arithmetic errors - 0x00
pub const RUNTIME_ERR_DIV_Z: u64            = 0xFFF9_0009_0000_0000;



