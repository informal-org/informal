use std::result;

#[derive(Debug,PartialEq)]
pub enum ArevelError {
    ParseError,
    InvalidFloatFmt,
    UnterminatedString,
    UnknownToken,
    UnmatchedParens,
}

pub type Result<T> = result::Result<T, ArevelError>;