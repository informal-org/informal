extern crate runtime;

use runtime::repl;

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
    repl_it();
    // eval_wat();
}
