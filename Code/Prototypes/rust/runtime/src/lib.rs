#[macro_use]
extern crate serde_derive;

use std::result;

pub type Result<T> = result::Result<T, u64>;

pub mod lexer;
pub mod parser;
pub mod interpreter;
pub mod format;
pub mod dependency;
pub mod ast;
pub mod structs;
mod tests;


#[macro_use]
extern crate lazy_static;


