use super::lexer;
use super::parser;
use super::generator;
use super::format;
use super::{decode_flatbuf};
use super::interpreter::*;
use super::constants::*;


pub use avs::avfb_generated::avfb::{get_root_as_av_fb_obj};
pub use avs::structs::{AvObject};

use wasmer_runtime::{Func, imports, compile};
use wabt::wat2wasm;
use wasmer_runtime::memory::MemoryView;
use std::time::SystemTime;



// TODO: Environment
pub fn read(input: String) -> String {
    // Reads input expressions and returns WAT equivalent
    let mut lexed = lexer::lex(&input).unwrap();
    let mut ast_node = parser::apply_operator_precedence(0, &mut lexed);
    // Retrieve shorter summary wat for display.
    let body = generator::expr_to_wat(&mut ast_node.parsed, 0);
    
    // Evaluate full wat with std lib linked.
    let full_wat = generator::link_avs(body);
    return full_wat
}

pub fn read_multi(inputs: Vec<String>) -> String {
    let mut body = String::from("");
    let mut index = 0;
    for input in inputs {
        let mut lexed = lexer::lex(&input).unwrap();
        let mut ast_node = parser::apply_operator_precedence(index, &mut lexed);

        body += &generator::expr_to_wat(&mut ast_node.parsed, index as i32 );
        index += 1;
    }
    let full_wat = generator::link_avs(body);
    return full_wat
}

pub fn eval_compiled(wasm_binary: Vec<u8>) -> Vec<u64> {
    let cell_count = 20;
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
    // let memory_view: MemoryView<u64> = memory.view();
    // let memory_view: MemoryView<u8> = memory.view();
    let results = decode_flatbuf!(memory, value, cell_count);

    // let cell_results = decode_values!(memory_view, value, cell_count);
    let mut results2: Vec<u64> = Vec::with_capacity(cell_count as usize);

    println!("Result : {:?} ", results);
    println!("Result decode: {:?}", SystemTime::now());

    // println!("At value {:?}", results);
    // return results;
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
    // TODO
    println!("{:?}", format::repr(&AvObject::new(), result));
}

pub fn read_eval_print(input: String) {
    let wat = read(input);
    let result = eval(wat)[0];
    print(result);
}

pub fn read_eval(input: String) -> String {
    let wat = read(input);
    let result = eval(wat)[0];
    return format::repr(&AvObject::new(), result)
}

#[cfg(test)]
mod tests {
    use super::*;
    use avs::constants::{SYMBOL_TRUE, SYMBOL_FALSE};
    use crate::interpreter;
    use crate::structs::*;
    use serde_json::json;

    macro_rules! read_eval {
        ($e:expr) => ({
            eval(read(String::from($e)))[0]
        });
    }

    macro_rules! read_eval_check {
        ($e:expr, $expected:expr) => ({
            // Execute both a compiled and interpreted version
            let i_result = interpreter::interpret_one(String::from($e));
            // TODO: correct avobject
            println!("Checking interpreted result {:?} expected {:?}", format::repr(&AvObject::new(), i_result), format::repr(&AvObject::new(), $expected));
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
            
            // let c_result = eval(read(String::from($e)))[0];
            // let c_result_f = f64::from_bits(c_result);
            // println!("Checking compiled result: {:?} {:?}", c_result, c_result_f);
            // assert_eq!(c_result_f, $expected);
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
        read_eval_check!("true", SYMBOL_TRUE);
        read_eval_check!("false", SYMBOL_FALSE);
        read_eval_check!("true or false", SYMBOL_TRUE);
        read_eval_check!("true and false", SYMBOL_FALSE);
    }

    #[test]
    fn test_reval_bool_not() {
        // Not is kind of a special case since it's a bit of a unary op
        read_eval_check!("true and not false", SYMBOL_TRUE);
        read_eval_check!("not true or false", SYMBOL_FALSE);
    }

    #[test]
    fn test_reval_comparison() {
        read_eval_check!("1 < 2", SYMBOL_TRUE);
        read_eval_check!("2 < 1", SYMBOL_FALSE);
        read_eval_check!("2 > 1", SYMBOL_TRUE);
        read_eval_check!("1 >= 0", SYMBOL_TRUE);
        read_eval_check!("-1 > 1", SYMBOL_FALSE);
    }


    #[test]
    fn test_program_eval() {
        let cell_a = CellRequest {id: String::from("@1"), input: String::from("1 + 1")};
        let cell_b = CellRequest {id: String::from("@2"), input: String::from("2 + 1")};

        // Can't just have single value inputs anymore, need cells as inputs
        let mut program = EvalRequest {
            body: Vec::new()
        };
        program.body.push(cell_a);
        program.body.push(cell_b);

        let i_result = interpreter::interpret_all(program);

        let expected_a = CellResponse {
            id: String::from("@1"), 
            output: String::from("2"),
            error: String::from("")
        };

        let expected_b = CellResponse {
            id: String::from("@2"), 
            output: String::from("3"),
            error: String::from("")
        };

        let mut expected_results = Vec::new();
        expected_results.push(expected_a);
        expected_results.push(expected_b);

        assert_eq!(i_result.results, expected_results);
    }


    #[test]
    fn test_identifiers() {
        let cell_a = CellRequest {id: String::from("@1"), input: String::from("1 + 1")};
        let cell_b = CellRequest {id: String::from("@2"), input: String::from("@1 + 3")};

        // Can't just have single value inputs anymore, need cells as inputs
        let mut program = EvalRequest {
            body: Vec::new()
        };
        program.body.push(cell_a);
        program.body.push(cell_b);

        let i_result = interpreter::interpret_all(program);


        let expected_a = CellResponse {
            id: String::from("@1"), 
            output: String::from("2"),
            error: String::from("")
        };

        let expected_b = CellResponse {
            id: String::from("@2"), 
            output: String::from("5"),
            error: String::from("")
        };

        let mut expected_results = Vec::new();
        expected_results.push(expected_a);
        expected_results.push(expected_b);

        assert_eq!(i_result.results, expected_results);    
    }


    #[test]
    fn test_reval_string_literals() {
        let cell_a = CellRequest {id: String::from("@1"), input: String::from("\"hello\"")};
        // Can't just have single value inputs anymore, need cells as inputs
        let mut program = EvalRequest {
            body: vec![cell_a]
        };
        let i_result = interpreter::interpret_all(program);
        println!("{:?}", i_result);
        // assert_eq!(true, false);

    }


}