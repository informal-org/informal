use super::lexer;
use super::lexer::{TRUE_REPR, FALSE_REPR};
use super::parser;
use super::generator;
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
    
    // Retrieve shorter summary wat for display.
    let mut body = generator::expr_to_wat(&mut parsed);
    println!("Wat: {}", body);
    
    // Evaluate full wat with std lib linked.
    let mut full_wat = generator::link_av_std(body);
    return full_wat
}

pub fn eval(wat: String) -> f64 {
    let wasm_binary = wat2wasm(wat).unwrap();
    let module = compile(&wasm_binary).unwrap();

    // // We're not importing anything, so make an empty import object.
    let import_object = imports! {};

    let instance = module.instantiate(&import_object).unwrap();
    let main: Func<(),u64> = instance.func("_start").unwrap();
    let value = main.call();

    return f64::from_bits(value.unwrap());
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


#[cfg(test)]
mod tests {
    use super::*;

    macro_rules! read_eval {
        ($e:expr) => ({
            eval(read(String::from($e)))
        });
    }

    #[test]
    fn test_reval_num_literals() {
        assert_eq!(read_eval!("9.0"), 9.0);
        assert_eq!(read_eval!("42"), 42.0);
        assert_eq!(read_eval!("3.14159"), 3.14159);
        assert_eq!(read_eval!("10e5"), 10e5);
    }

    #[test]
    fn test_reval_arithmetic() {
        assert_eq!(read_eval!("12 * 2 / 3"), 8.0);
        assert_eq!(read_eval!("48 / 3 / 2"), 8.0);
        assert_eq!(read_eval!("1 + 2"), 3.0);
        assert_eq!(read_eval!("1 + 2 * 3 + 4"), 11.0);
        assert_eq!(read_eval!("( 2 ) "), 2.0);
        assert_eq!(read_eval!("2 * (3 + 4) "), 14.0);
        assert_eq!(read_eval!("2 * 2 / (5 - 1) + 3"), 4.0);

    }

    #[test]
    fn test_unary_minus(){
        assert_eq!(read_eval!("2 + -1"), 1.0);
        assert_eq!(read_eval!("5 * -2"), -10.0);
        assert_eq!(read_eval!("5 * -(2)"), -10.0);
        assert_eq!(read_eval!("5 * -(1 + 1)"), -10.0);
        assert_eq!(read_eval!("-(4) + 2"), -2.0);
    }

    #[test]
    fn test_reval_bool() {
        assert_eq!(read_eval!("true").to_bits(), TRUE_REPR);
        assert_eq!(read_eval!("false").to_bits(), FALSE_REPR);
        assert_eq!(read_eval!("true or false").to_bits(), TRUE_REPR);
        assert_eq!(read_eval!("true and false").to_bits(), FALSE_REPR);
    }

    #[test]
    fn test_reval_bool_not() {
        // Not is kind of a special case since it's a bit of a unary op
        assert_eq!(read_eval!("true and not false").to_bits(), TRUE_REPR);
        assert_eq!(read_eval!("not true or false").to_bits(), FALSE_REPR);
    }
}