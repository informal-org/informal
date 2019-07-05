use std::result;

#[derive(Debug,PartialEq)]
pub enum ArevelError {
    ParseError,
    InvalidFloatFmt,
    UnterminatedString,
    UnknownToken
}

pub type Result<T> = result::Result<T, ArevelError>;