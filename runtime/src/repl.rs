use super::lexer;
use super::parser;
use super::generator;
extern crate wasmi;


use avs::{__av_typeof, ValueType, VALUE_TRUE, VALUE_FALSE, VALUE_NONE};

use wasmer_runtime::{error, func, Func, imports, compile, instantiate, Ctx, Value};
use wabt::wat2wasm;

use wasmi::{ModuleInstance, ImportsBuilder, NopExternals, RuntimeValue};


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
        let mut lexed = lexer::lex(&input).unwrap();
        let mut parsed = parser::parse(&mut lexed).unwrap();
        body += &generator::expr_to_wat(&mut parsed, index);
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


pub fn eval_interpreted(wasm_binary: Vec<u8>) -> Vec<u64> {
    let CELL_COUNT = 2000;
    // Load wasm binary and prepare it for instantiation.
    let module = wasmi::Module::from_buffer(&wasm_binary)
        .expect("failed to load wasm");

    // Instantiate a module with empty imports and
    // assert that there is no `start` function.
    let instance =
        ModuleInstance::new(
            &module,
            &ImportsBuilder::default()
        )
        .expect("failed to instantiate wasm module")
        .assert_no_start();

    // Finally, invoke the exported function "test" with no parameters
    // and empty external function executor.
    let runtime_result = instance.invoke_export(
            "__av_run",
            &[RuntimeValue::I32(CELL_COUNT)],
            &mut NopExternals,
        ).expect("failed to execute export");
    //    Some(RuntimeValue::I32(1337)),
    //);

    let mut results: Vec<u64> = Vec::with_capacity(CELL_COUNT as usize);
    results.push(0);
    return results;
}


pub fn eval(wat: String) -> Vec<u64> {
    let t0 = SystemTime::now();
    let compiled = false;

    let wasm_binary = wat2wasm(wat).unwrap();
    let t1 = SystemTime::now();
    
    println!("Wat2wasm: {:?}", t1.duration_since(t0));
    let t2 = SystemTime::now();

    // return eval_compiled(wasm_binary);
    let result =  eval_interpreted(wasm_binary);

    let t3 = SystemTime::now();
    println!("Full Evaluation: {:?}", t3.duration_since(t2));

    return result
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

    macro_rules! read_eval_f {
        ($e:expr) => ({
            f64::from_bits(eval(read(String::from($e)))[0])
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