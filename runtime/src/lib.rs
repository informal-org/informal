#[macro_use]
extern crate serde_derive;

use std::result;

pub type Result<T> = result::Result<T, u64>;

pub mod lexer;
pub mod parser;
pub mod generator;
pub mod repl;
pub mod sharedmemory;
pub mod interpreter;
pub mod format;

pub mod constants;
pub mod structs;


