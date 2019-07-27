/* 
Values in Arevel are nan-boxed. 
Floating point representation of NaN leaves a lot of bits unused. 
We pack a type and value into this space, for basic types and pointers.

0 00000001010 0000000000000000000000000000000000000000000000000000 = 64
1 11111111111 1000000000000000000000000000000000000000000000000000 = nan
Type (3 bits). Value 48 bits.
*/

// Data format

// 8 = 1000
pub const SIGNALING_NAN: u64 = 0xFFF8_0000_0000_0000;
pub const QUITE_NAN: u64 = 0xFFF0_0000_0000_0000;

// Not of signaling nan. 
pub const VALUE_TYPE_MASK: u64 = 0x000F_0000_0000_0000;
// Clear all type bits, preserve. 
// Mask with 0000 rather than 0007 for the nice letter codes.
pub const VALUE_MASK: u64 = 0x0000_FFFF_FFFF_FFFF;

// D,F Currenty unsed... 0-8 Invalid NaN (Do Not Use)
// Reserved space for built-in constant values
pub const VALUE_TYPE_CONSTANT_MASK: u64 = 0x0009_0000_0000_0000;

// Array. Payload = length (up to 2^16). 0 if greater (empty arr represented separately)
pub const VALUE_TYPE_ARR_MASK: u64 = 0x000A_0000_0000_0000;


// VALUE_TYPE_NONE_MASK
// pub const VALUE_TYPE_BOOL_MASK: u64 = 0x000B_0000_0000_0000;



pub const VALUE_TYPE_CLASS_MASK: u64 = 0x000C_0000_0000_0000;

// Don't stuff additional payload into pointer values to preserve full range for future.
pub const VALUE_TYPE_POINTER_MASK: u64 = 0x000D_0000_0000_0000;

// Payload = String length (up to 2^16). Empty string & strings of len < 5 represented as const.
pub const VALUE_TYPE_STR_MASK: u64 = 0x000E_0000_0000_0000;
pub const VALUE_TYPE_FUNC_MASK: u64 = 0x000F_0000_0000_0000;



// NaN-boxed constants. 0xFFF9 header. 16 Constant types. 44 bits of payload.
// value_true value_false, value_none

// 0-16 Empty value types (grouped together since they all evaluate to false, you can do a range check)
pub const CONST_NONE: u64 = 0xFFF9_0000_0000_0000;
pub const CONST_FALSE: u64 = 0xFFF9_1000_0000_0000;
pub const CONST_EMPTY_ARR: u64 = 0xFFF9_2000_0000_0000;



// ERRORS
// Private - temprorary error code.
// Future will contain payload of error region.
pub const VALUE_ERR: u64 = 0xFFF9_D000_0000_0000;


// Denotes types of errors. 
// There's an error type when expressions fail or fails to parse.
// The payload is a pointer to a memory region which will contain additional metadata
// Like function, stack trace, etc.
// Top order bits = error code. parsing stage -> execution stage. (left to right in bits)
// Ensure that constants are not re-used!
pub const PARSE_ERR: u64                    = 0xFFF9_D100_0000_0000;
pub const INTERPRETER_ERR: u64              = 0xFFF9_D010_0000_0000;
pub const RUNTIME_ERR: u64                  = 0xFFF9_D001_0000_0000;

// Parsing errors
pub const PARSE_ERR_UNTERM_STR: u64         = 0xFFF9_D200_0000_0000;
pub const PARSE_ERR_INVALID_FLOAT: u64      = 0xFFF9_D300_0000_0000;
pub const PARSE_ERR_UNKNOWN_TOKEN: u64      = 0xFFF9_D400_0000_0000;
pub const PARSE_ERR_UNEXPECTED_TOKEN: u64   = 0xFFF9_D500_0000_0000;
pub const PARSE_ERR_UNMATCHED_PARENS: u64   = 0xFFF9_D600_0000_0000;

// Type checking errors
pub const RUNTIME_ERR_INVALID_TYPE: u64     = 0xFFF9_D001_0000_0000;
// This operation is not allowed with NaN values
pub const RUNTIME_ERR_TYPE_NAN: u64         = 0xFFF9_D002_0000_0000;

// Expected number
pub const RUNTIME_ERR_EXPECTED_NUM: u64     = 0xFFF9_D003_0000_0000;
pub const RUNTIME_ERR_EXPECTED_BOOL: u64    = 0xFFF9_D004_0000_0000;
pub const RUNTIME_ERR_UNK_VAL: u64          = 0xFFF9_D005_0000_0000;
pub const RUNTIME_ERR_CIRCULAR_DEP: u64     = 0xFFF9_D006_0000_0000;
pub const RUNTIME_ERR_MEMORY_ACCESS: u64    = 0xFFF9_D007_0000_0000;

pub const RUNTIME_ERR_EXPECTED_STR: u64     = 0xFFF9_D008_0000_0000;

// Arithmetic errors - 0x00
pub const RUNTIME_ERR_DIV_Z: u64            = 0xFFF9_D009_0000_0000;


pub const CONST_EMPTY_STR: u64 = 0xFFF9_E000_0000_0000;
// All values after this are Truthy
// String constants from E1[00]_[00][00]_[00][00] -> Upto 5 characters inline!
pub const CONST_TRUE: u64 = 0xFFF9_F000_0000_0000;



// Pointer types
// 0xFFF9_0000_0000_0000
// 16 byte pointer header
//    > Pointer type. For fast type checking without deref.
//    > Small sized pointers?
//    > Direct obj field access pointers (for small index)
// 32 lower bits - Relative pointer location.


// Object class constants for built-in types.
pub const AV_CLASS_OBJECT: u32 = 0;
pub const AV_CLASS_CLASS: u32 = 1;
pub const AV_CLASS_FUNCTION: u32 = 2;
pub const AV_CLASS_ENVIRONMENT: u32 = 3;
pub const AV_CLASS_STRING: u32 = 4;

