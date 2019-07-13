use super::lexer;
use super::parser;
use super::generator;


use avs::{__av_typeof, ValueType, VALUE_TRUE, VALUE_FALSE, VALUE_NONE};

use wasmer_runtime::{error, func, Func, imports, compile, instantiate, Ctx, Value};
use wabt::wat2wasm;

use wasmer_runtime::memory::MemoryView;
use wasmer_runtime::{Instance};
#[macro_use]
use super::{decode_values, decode_deref};


// TODO: Environment
pub fn read(input: String) -> String {
    // Reads input expressions and returns WAT equivalent

    let mut lexed = lexer::lex(&input).unwrap();
    let mut parsed = parser::parse(&mut lexed).unwrap();
    // Retrieve shorter summary wat for display.
    let body = generator::expr_to_wat(&mut parsed);
    // println!("Wat: {}", body);
    
    // Evaluate full wat with std lib linked.
    // todo: rename this. Confusion with link_as_std.
    let full_wat = generator::link_av_std(body);
    return full_wat
}

pub fn eval(wat: String) -> u64 {
    let wasm_binary = wat2wasm(wat).unwrap();
    let module = compile(&wasm_binary).unwrap();

    // // We're not importing anything, so make an empty import object.
    let import_object = imports! {};

    let instance = module.instantiate(&import_object).unwrap();

    // let result = instance.call(
    //     "_start",
    //     &[Value::I32(0)],
    // );


    let main: Func<(),u32> = instance.func("_start").unwrap();
    let value = main.call().unwrap();
    // let value = instance.call("_start", &[]);

    println!("Return value {:?}", value);
    let memory = instance.context().memory(0);
    // let memory_view: MemoryView<u64> = memory.view();
    let memory_view: MemoryView<u64> = memory.view();

    let result = decode_values!(memory_view, value, 32);

    println!("At value {:?}", result);
    return 0
}

pub fn format(result: u64) -> String {
    let result_type = __av_typeof(result);
    match result_type {
        ValueType::NumericType => {
            format!("{:?}", f64::from_bits(result))
        },
        ValueType::BooleanType => {
            if result == VALUE_TRUE {
                format!("TRUE")
            } else {
                format!("FALSE")
            }
        },
        _ => {
            format!("{:?}: {:?}", result_type, result)
        }
    }
}

fn print(result: u64) {
    println!("{:?}", format(result));
}

pub fn read_eval_print(input: String) {
    let wat = read(input);
    let result = eval(wat);
    print(result);
}

pub fn read_eval(input: String) -> String {
    let wat = read(input);
    let result = eval(wat);
    return format(result)
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

    #[test]
    fn test_reval_comparison() {
        assert_eq!(read_eval!("1 < 2"), VALUE_TRUE);
        assert_eq!(read_eval!("2 < 1"), VALUE_FALSE);
        assert_eq!(read_eval!("2 > 1"), VALUE_TRUE);
        assert_eq!(read_eval!("1 >= 0"), VALUE_TRUE);
        assert_eq!(read_eval!("-1 > 1"), VALUE_FALSE);
    }
}