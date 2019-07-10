// Denotes types of errors. 
// There's an error type when expressions fail. 
// The payload is a pointer to a memory region which will contain additional metadata
// Like function, stack trace, etc.

#[derive(Debug,PartialEq)]
pub enum ArevelError {
    ParseError,
    InvalidFloatFmt,
    UnterminatedString,
    UnknownToken,
    UnmatchedParens,
    ArithmeticError,
    TypeError
}