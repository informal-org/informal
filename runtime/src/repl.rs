use super::lexer;
use super::parser;
use super::generator;
use super::format;
use super::{decode_values};

use wasmer_runtime::{Func, imports, compile};
use wabt::wat2wasm;
use wasmer_runtime::memory::MemoryView;
use std::time::SystemTime;



// TODO: Environment
pub fn read(input: String) -> String {
    // Reads input expressions and returns WAT equivalent
    let mut lexed = lexer::lex(&input).unwrap();
    let mut parsed = parser::parse(&mut lexed).unwrap();
    // Retrieve shorter summary wat for display.
    let body = generator::expr_to_wat(&mut parsed, 0);
    
    // Evaluate full wat with std lib linked.
    let full_wat = generator::link_avs(body);
    return full_wat
}

pub fn read_multi(inputs: Vec<String>) -> String {
    let mut body = String::from("");
    let mut index = 0;
    for input in inputs {
        let mut lexed = lexer::lex(&input).unwrap();
        let mut parsed = parser::parse(&mut lexed).unwrap();

        body += &generator::expr_to_wat(&mut parsed, index);
        index += 1;
    }
    let full_wat = generator::link_avs(body);
    return full_wat
}

pub fn eval_compiled(wasm_binary: Vec<u8>) -> Vec<u64> {
    let cell_count = 2000;
    let module = compile(&wasm_binary).unwrap();
    
    println!("WASM Compile: {:?}", SystemTime::now());

    // // We're not importing anything, so make an empty import object.
    let import_object = imports! {};
    let instance = module.instantiate(&import_object).unwrap();

    println!("WASM instantiate: {:?}", SystemTime::now());

    let main: Func<(u32),u32> = instance.func("__av_run").unwrap();
    let value = main.call(cell_count).unwrap();

    println!("Arevel Run: {:?}", SystemTime::now());
    // let value = instance.call("_start", &[]);

    // println!("Return value {:?}", value);
    let memory = instance.context().memory(0);
    let memory_view: MemoryView<u64> = memory.view();
    let cell_results = decode_values!(memory_view, value, cell_count);

    let mut results: Vec<u64> = Vec::with_capacity(cell_count as usize);

    for cell in cell_results {
        results.push(cell.get());
    }

    println!("Result decode: {:?}", SystemTime::now());

    // println!("At value {:?}", results);
    return results;
}


pub fn eval(wat: String) -> Vec<u64> {
    let t0 = SystemTime::now();

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


fn print(result: u64) {
    println!("{:?}", format::repr(result));
}

pub fn read_eval_print(input: String) {
    let wat = read(input);
    let result = eval(wat)[0];
    print(result);
}

pub fn read_eval(input: String) -> String {
    let wat = read(input);
    let result = eval(wat)[0];
    return format::repr(result)
}

#[cfg(test)]
mod tests {
    use super::*;
    use avs::{VALUE_TRUE, VALUE_FALSE};
    use super::interpreter;

    macro_rules! read_eval {
        ($e:expr) => ({
            eval(read(String::from($e)))[0]
        });
    }

    macro_rules! read_eval_check {
        ($e:expr, $expected:expr) => ({
            // Execute both a compiled and interpreted version
            let i_result = interpreter::interpret_one(String::from($e));
            println!("Checking interpreted result {:?} expected {:?}", format::repr(i_result), format::repr($expected));
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


    #[test]
    fn test_identifiers() {
        // Can't just have single value inputs anymore, need cells as inputs
    }

}