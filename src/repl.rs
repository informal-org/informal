use super::lexer;
use super::parser;
use super::error;

use wasmer_runtime::{func, imports, Ctx, Value, compile};
use wasmer_runtime::{Func, Instance, error::ResolveResult};
use wabt::wat2wasm;

// TODO: Environment
fn read(input: String) -> String {
    // Reads input expressions and returns WAT equivalent

    let mut lexed = lexer::lex(&input).unwrap();
    println!("Lexed: {:?}", lexed);

    let mut parsed = parser::parse(&mut lexed).unwrap();
    println!("Parsed: {:?}", parsed);
    
    let mut wat = parser::expr_to_wat(parsed);
    println!("Wat: {}", wat);
    return wat
}

fn eval(wat: String) -> f64 {
    let wasm_binary = wat2wasm(wat).unwrap();
    let module = compile(&wasm_binary).unwrap();

    // // We're not importing anything, so make an empty import object.
    let import_object = imports! {};

    let instance = module.instantiate(&import_object).unwrap();
    let main: Func<(),f64> = instance.func("main").unwrap();
    let value = main.call();
    return value.unwrap();
}

fn print(result: f64) {
    // TODO: Unwrap result type
    println!("{:?}", result);
}

pub fn read_eval_print(input: String) {
    let wat = read(input);
    let result = eval(wat);
    print(result);

}