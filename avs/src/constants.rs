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
pub const VALUE_TYPE_POINTER_MASK: u64 = 0x0009_0000_0000_0000;
pub const VALUE_TYPE_NONE_MASK: u64 = 0x000A_0000_0000_0000;
pub const VALUE_TYPE_BOOL_MASK: u64 = 0x000B_0000_0000_0000;
pub const VALUE_TYPE_STR_MASK: u64 = 0x000C_0000_0000_0000;
pub const VALUE_TYPE_ERR_MASK: u64 = 0x000E_0000_0000_0000;

// NaN-boxed boolean. 0xFFFB = Boolean type header.
pub const VALUE_TRUE: u64 = 0xFFFB_0000_0000_0001;
pub const VALUE_FALSE: u64 = 0xFFFB_0000_0000_0000;
pub const VALUE_NONE: u64 = 0xFFFA_0000_0000_0000;

// Private - temprorary error code.
// Future will contain payload of error region.
pub const VALUE_ERR: u64 = 0xFFFE_0000_0000_0000;


// ERRORS

// Denotes types of errors. 
// There's an error type when expressions fail or fails to parse.
// The payload is a pointer to a memory region which will contain additional metadata
// Like function, stack trace, etc.
// Top order bits = error code. parsing stage -> execution stage. (left to right in bits)
// Ensure that constants are not re-used!
pub const RUNTIME_ERR: u64 = 0xFFFE_0001_0000_0000;
pub const PARSE_ERR: u64 = 0xFFFE_1000_0000_0000;
pub const INTERPRETER_ERR: u64 = 0xFFFE_0010_0000_0000;

// Parsing errors
pub const PARSE_ERR_UNTERM_STR: u64 = 0xFFFE_2000_0000_0000;
pub const PARSE_ERR_INVALID_FLOAT: u64 = 0xFFFE_3000_0000_0000;
pub const PARSE_ERR_UNKNOWN_TOKEN: u64 = 0xFFFE_4000_0000_0000;
pub const PARSE_ERR_UNEXPECTED_TOKEN: u64 = 0xFFFE_5000_0000_0000;
pub const PARSE_ERR_UNMATCHED_PARENS: u64 = 0xFFFE_6000_0000_0000;

// Type checking errors
pub const RUNTIME_ERR_INVALID_TYPE: u64 = 0xFFFE_0100_0000_0000;
// This operation is not allowed with NaN values
pub const RUNTIME_ERR_TYPE_NAN: u64 = 0xFFFE_0200_0000_0000;

// Expected number
pub const RUNTIME_ERR_EXPECTED_NUM: u64 = 0xFFFE_0300_0000_0000;
pub const RUNTIME_ERR_EXPECTED_BOOL: u64 = 0xFFFE_0400_0000_0000;
pub const RUNTIME_ERR_UNK_VAL: u64 = 0xFFFE_0500_0000_0000;

pub const RUNTIME_ERR_CIRCULAR_DEP: u64 = 0xFFFE_0600_0000_0000;

// Arithmetic errors - 0x00
pub const RUNTIME_ERR_DIV_Z: u64 = 0xFFFE_0002_0000_0000;


