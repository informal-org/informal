pub mod error;
pub mod lexer;
pub mod parser;
pub mod generator;
pub mod repl;

// use std::str;
use std::io::{stdin,stdout,Write};




fn repl_it() {
    loop {
        print!("> ");
        let _=stdout().flush();
        let reader = stdin();
        let mut input = String::new();
        reader.read_line(&mut input).ok().expect("Failed to read line");

        repl::read_eval_print(input);
    }
}


fn main() {
    println!("Arevel - Version - 1.0");

    const TAG_SHIFT: u64 = 48;
    const DOUBLE_MAX_TAG: u32 = 0b11111_11111_11000_0;
    const SHIFTED_DOUBLE_MAX_TAG: u64 = ((DOUBLE_MAX_TAG as u64) << TAG_SHIFT) | 0xFFFFFFFF;


    println!("shift {:b}", SHIFTED_DOUBLE_MAX_TAG);


    repl_it();
    // eval_wat();
}
