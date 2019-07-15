use super::lexer;
use super::parser;
use super::generator;
use super::interpreter;


use avs::{__av_typeof, ValueType, VALUE_TRUE, VALUE_FALSE, VALUE_NONE};
use avs::error;
use wasmer_runtime::{func, Func, imports, compile, instantiate, Ctx, Value};
use wabt::wat2wasm;


use wasmer_runtime::memory::MemoryView;
use wasmer_runtime::{Instance};
#[macro_use]
use super::{decode_values, decode_deref};

use std::time::SystemTime;


// TODO: Environment
pub fn read(input: String) -> String {
    // Reads input expressions and returns WAT equivalent
    let mut lexed = lexer::lex(&input).unwrap();
    let mut parsed = parser::parse(&mut lexed).unwrap();
    // Retrieve shorter summary wat for display.
    let body = generator::expr_to_wat(&mut parsed, 0);
    // println!("Wat: {}", body);
    
    // Evaluate full wat with std lib linked.
    // todo: rename this. Confusion with link_as_std.
    let full_wat = generator::link_av_std(body);
    return full_wat
}

pub fn read_multi(inputs: Vec<String>) -> String {
    let start = SystemTime::now();
    let mut body = String::from("");
    let mut index = 0;
    for input in inputs {
        let t1 = SystemTime::now();
        let mut lexed = lexer::lex(&input).unwrap();
        // println!("Lex: {:?}", SystemTime::now().duration_since(t1));

        let t2 = SystemTime::now();
        let mut parsed = parser::parse(&mut lexed).unwrap();
        //println!("Parse: {:?}", SystemTime::now().duration_since(t2));

        // let t3 = SystemTime::now();
        body += &generator::expr_to_wat(&mut parsed, index);
        // println!("Gen: {:?}", SystemTime::now().duration_since(t3));
        index += 1;
    }
    let full_wat = generator::link_av_std(body);

    let end = SystemTime::now();
    println!("ReadMulti: {:?}", end.duration_since(start));
    return full_wat
}

pub fn eval_compiled(wasm_binary: Vec<u8>) -> Vec<u64> {
    let CELL_COUNT = 2000;
    let module = compile(&wasm_binary).unwrap();
    
    println!("WASM Compile: {:?}", SystemTime::now());

    // // We're not importing anything, so make an empty import object.
    let import_object = imports! {};
    let instance = module.instantiate(&import_object).unwrap();

    println!("WASM instantiate: {:?}", SystemTime::now());

    let main: Func<(u32),u32> = instance.func("__av_run").unwrap();
    let value = main.call(CELL_COUNT).unwrap();

    println!("Arevel Run: {:?}", SystemTime::now());
    // let value = instance.call("_start", &[]);

    // println!("Return value {:?}", value);
    let memory = instance.context().memory(0);
    let memory_view: MemoryView<u64> = memory.view();
    let cell_results = decode_values!(memory_view, value, CELL_COUNT);

    let mut results: Vec<u64> = Vec::with_capacity(CELL_COUNT as usize);

    for cell in cell_results {
        results.push(cell.get());
    }

    println!("Result decode: {:?}", SystemTime::now());

    // println!("At value {:?}", results);
    return results;
}


pub fn eval(wat: String) -> Vec<u64> {
    let t0 = SystemTime::now();
    let compiled = false;

    let wasm_binary = wat2wasm(wat).unwrap();
    let t1 = SystemTime::now();
    
    println!("Wat2wasm: {:?}", t1.duration_since(t0));
    let t2 = SystemTime::now();

    let result = eval_compiled(wasm_binary);
    // let result =  eval_interpreted(wasm_binary);

    let t3 = SystemTime::now();
    println!("Full Evaluation: {:?}", t3.duration_since(t2));

    return result
}

pub fn format(result: u64) -> String {
    let result_type = __av_typeof(result);
    match result_type {
        ValueType::NumericType => {
            let f_val: f64 = f64::from_bits(result);
            // Print integers without the trailing zeroes
            if f_val.fract() == 0.0 {
                format!("{:?}", f_val.trunc() as i64)
            } else {
                format!("{:?}", f_val)
            }
        },
        ValueType::BooleanType => {
            if result == VALUE_TRUE {
                format!("TRUE")
            } else {
                format!("FALSE")
            }
        },
        ValueType::ErrorType => {
            // TODO: Return this as Error rather than Ok?
            // TODO: Log most common errors
            println!("{:X}", result);
            
            // Guidelines:
            // Write errors for humans, not computers. No ParseError 0013: Err at line 2 col 4.
            // Sympathize with the user. Don't blame them (avoid 'your'). This may be their first exposure to programming.
            // Help them recover if possible. (Largely a TODO once we have error pointers)
            // https://uxplanet.org/how-to-write-good-error-messages-858e4551cd4
            // Alas - match doesn't work for this. These sholud be ordered by expected frequency.
            if result == error::RUNTIME_ERR {
                String::from("There was a mysterious error while running this code.")
            } else if result == error::PARSE_ERR {
                String::from("Arevel couldn't understand this expression.")
            } else if result == error::INTERPRETER_ERR {
                String::from("There was an unknown error while interpreting this code.")
            } else if result == error::PARSE_ERR_UNTERM_STR {
                String::from("Arevel couldn't find where this string ends. Make sure the text has matching quotation marks.")
            } else if result == error::PARSE_ERR_INVALID_FLOAT {
                String::from("This decimal number is in a weird format.")
            } else if result == error::PARSE_ERR_UNKNOWN_TOKEN {
                String::from("There's an unexpected token in this expression.")
            } else if result == error::PARSE_ERR_UNMATCHED_PARENS {
                String::from("Arevel couldn't find where the brackets end. Check whether all opened brackets are closed.")
            } else if result == error::RUNTIME_ERR_INVALID_TYPE {
                String::from("That data type doesn't work with this operation.")
            } else if result == error::RUNTIME_ERR_TYPE_NAN {
                String::from("This operation doesn't work with not-a-number (NaN) values.")
            } else if result == error::RUNTIME_ERR_EXPECTED_NUM {
                String::from("Hmmm... Arevel expects a number here.")
            } else if result == error::RUNTIME_ERR_EXPECTED_BOOL {
                String::from("Arevel expects a true/false boolean here.")
            } else if result == error::RUNTIME_ERR_DIV_Z {
                String::from("Dividing by zero is undefined. Make sure the denominator is not a zero before dividing.")
            } else {
                format!("Sorry, Arevel encountered a completely unknown error: {:?}", result)
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
    let result = eval(wat)[0];
    print(result);
}

pub fn read_eval(input: String) -> String {
    let wat = read(input);
    let result = eval(wat)[0];
    return format(result)
}

#[cfg(test)]
mod tests {
    use super::*;
    use avs::{VALUE_TRUE, VALUE_FALSE};

    macro_rules! read_eval {
        ($e:expr) => ({
            eval(read(String::from($e)))[0]
        });
    }

    macro_rules! read_eval_check {
        ($e:expr, $expected:expr) => ({
            // Execute both a compiled and interpreted version
            let i_result = interpreter::interpret_one(String::from($e));
            println!("Checking interpreted result {:?} expected {:?}", format(i_result), format($expected));
            assert_eq!(i_result, $expected);
            

            // let c_result = eval(read(String::from($e)))[0];
            // println!("Checking compiled result");
            // assert_eq!(c_result, $expected);
        });
    }

    macro_rules! read_eval_check_f {
        ($e:expr, $expected:expr) => ({
            // Execute both a compiled and interpreted version
            let i_result = interpreter::interpret_one(String::from($e));
            let i_result_f = f64::from_bits(i_result);
            println!("Checking interpreted result: {:?} {:?}", i_result, i_result_f);
            assert_eq!(i_result_f, $expected);
            
            let c_result = eval(read(String::from($e)))[0];
            let c_result_f = f64::from_bits(c_result);
            println!("Checking compiled result: {:?} {:?}", c_result, c_result_f);
            assert_eq!(c_result_f, $expected);
        });
    }

    #[test]
    fn test_reval_num_literals() {
        read_eval_check_f!("9.0", 9.0);
        read_eval_check_f!("42", 42.0);
        read_eval_check_f!("3.14159", 3.14159);
        read_eval_check_f!("10e5", 10e5);
    }

    #[test]
    fn test_reval_arithmetic() {
        read_eval_check_f!("( 2 ) ", 2.0);
        read_eval_check_f!("1 + 2", 3.0);
        read_eval_check_f!("3 * 2", 6.0);
        read_eval_check_f!("12 * 2 / 3", 8.0);
        read_eval_check_f!("48 / 3 / 2", 8.0);
        read_eval_check_f!("1 + 2 * 3 + 4", 11.0);
        read_eval_check_f!("2 * (3 + 4) ", 14.0);
        read_eval_check_f!("2 * 2 / (5 - 1) + 3", 4.0);
    }

    #[test]
    fn test_unary_minus(){
        read_eval_check_f!("2 + -1", 1.0);
        read_eval_check_f!("5 * -2", -10.0);
        read_eval_check_f!("5 * -(2)", -10.0);
        read_eval_check_f!("5 * -(1 + 1)", -10.0);
        read_eval_check_f!("-(4) + 2", -2.0);
    }

    #[test]
    fn test_reval_bool() {
        read_eval_check!("true", VALUE_TRUE);
        read_eval_check!("false", VALUE_FALSE);
        read_eval_check!("true or false", VALUE_TRUE);
        read_eval_check!("true and false", VALUE_FALSE);
    }

    #[test]
    fn test_reval_bool_not() {
        // Not is kind of a special case since it's a bit of a unary op
        read_eval_check!("true and not false", VALUE_TRUE);
        read_eval_check!("not true or false", VALUE_FALSE);
    }

    #[test]
    fn test_reval_comparison() {
        read_eval_check!("1 < 2", VALUE_TRUE);
        read_eval_check!("2 < 1", VALUE_FALSE);
        read_eval_check!("2 > 1", VALUE_TRUE);
        read_eval_check!("1 >= 0", VALUE_TRUE);
        read_eval_check!("-1 > 1", VALUE_FALSE);
    }
}