use super::lexer;
use super::parser;
use super::generator;

use avs::{__av_typeof, ValueType, VALUE_TRUE, VALUE_FALSE, VALUE_NONE};

use wasmer_runtime::{imports, compile};
use wasmer_runtime::{Func};
use wabt::wat2wasm;

// TODO: Environment
fn read(input: String) -> String {
    // Reads input expressions and returns WAT equivalent

    let mut lexed = lexer::lex(&input).unwrap();
    let mut parsed = parser::parse(&mut lexed).unwrap();
    // Retrieve shorter summary wat for display.
    let body = generator::expr_to_wat(&mut parsed);
    println!("Wat: {}", body);
    
    // Evaluate full wat with std lib linked.
    let full_wat = generator::link_av_std(body);
    return full_wat
}

pub fn eval(wat: String) -> u64 {
    let wasm_binary = wat2wasm(wat).unwrap();
    let module = compile(&wasm_binary).unwrap();

    // // We're not importing anything, so make an empty import object.
    let import_object = imports! {};

    let instance = module.instantiate(&import_object).unwrap();
    let main: Func<(),u64> = instance.func("_start").unwrap();
    let value = main.call();

    return value.unwrap();
}

fn print(result: u64) {
    let result_type = __av_typeof(result);
    match result_type {
        ValueType::NumericType => {
            println!("{:?}", f64::from_bits(result));
        },
        ValueType::BooleanType => {
            if result == VALUE_TRUE {
                println!("TRUE");
            } else {
                println!("FALSE");
            }
        }
        _ => {
            println!("{:?}: {:?}", result_type, result);
        }
    }
    

    
}

pub fn read_eval_print(input: String) {
    let wat = read(input);
    let result = eval(wat);
    print(result);
}


#[cfg(test)]
mod tests {
    use super::*;
    use avs::{VALUE_TRUE, VALUE_FALSE};


    macro_rules! read_eval {
        ($e:expr) => ({
            eval(read(String::from($e)))
        });
    }

    macro_rules! read_eval_f {
        ($e:expr) => ({
            f64::from_bits(eval(read(String::from($e))))
        });
    }

    #[test]
    fn test_reval_num_literals() {
        assert_eq!(read_eval_f!("9.0"), 9.0);
        assert_eq!(read_eval_f!("42"), 42.0);
        assert_eq!(read_eval_f!("3.14159"), 3.14159);
        assert_eq!(read_eval_f!("10e5"), 10e5);
    }

    #[test]
    fn test_reval_arithmetic() {
        assert_eq!(read_eval_f!("12 * 2 / 3"), 8.0);
        assert_eq!(read_eval_f!("48 / 3 / 2"), 8.0);
        assert_eq!(read_eval_f!("1 + 2"), 3.0);
        assert_eq!(read_eval_f!("1 + 2 * 3 + 4"), 11.0);
        assert_eq!(read_eval_f!("( 2 ) "), 2.0);
        assert_eq!(read_eval_f!("2 * (3 + 4) "), 14.0);
        assert_eq!(read_eval_f!("2 * 2 / (5 - 1) + 3"), 4.0);

    }

    #[test]
    fn test_unary_minus(){
        assert_eq!(read_eval_f!("2 + -1"), 1.0);
        assert_eq!(read_eval_f!("5 * -2"), -10.0);
        assert_eq!(read_eval_f!("5 * -(2)"), -10.0);
        assert_eq!(read_eval_f!("5 * -(1 + 1)"), -10.0);
        assert_eq!(read_eval_f!("-(4) + 2"), -2.0);
    }

    #[test]
    fn test_reval_bool() {
        assert_eq!(read_eval!("true"), VALUE_TRUE);
        assert_eq!(read_eval!("false"), VALUE_FALSE);
        assert_eq!(read_eval!("true or false"), VALUE_TRUE);
        assert_eq!(read_eval!("true and false"), VALUE_FALSE);
    }

    #[test]
    fn test_reval_bool_not() {
        // Not is kind of a special case since it's a bit of a unary op
        assert_eq!(read_eval!("true and not false"), VALUE_TRUE);
        assert_eq!(read_eval!("not true or false"), VALUE_FALSE);
    }
}