// Denotes types of errors. 
// There's an error type when expressions fail. 
// The payload is a pointer to a memory region which will contain additional metadata
// Like function, stack trace, etc.

// #[derive(Debug,PartialEq)]
// pub enum ArevelError {
//     ParseError(u64),
//     // InvalidFloatFmt,
//     // UnterminatedString,
//     // UnknownToken,
//     // UnmatchedParens,
//     // ArithmeticError,
//     // TypeError
// }


// Generic runtime error
// Top order bits = error code. parsing stage -> execution stage. 
// TODO: Bottom 32 bits may contain a pointer to more information (to be implemented)
// Validate that constants are not re-used!
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

// Arithmetic errors - 0x00
pub const RUNTIME_ERR_DIV_Z: u64 = 0xFFFE_0002_0000_0000;
