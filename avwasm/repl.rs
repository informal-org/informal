use super::lexer;
use super::parser;
use super::generator;
use super::format;
// use super::{decode_flatbuf};

// pub use avs::avfb_generated::avfb::{get_root_as_av_fb_obj};
pub use avs::structs::{AvObject, Runtime};

// use wasmer_runtime::{Func, imports, compile};
// use wabt::wat2wasm;
// use wasmer_runtime::memory::MemoryView;
// use std::time::SystemTime;


// // TODO: Environment
// pub fn read(input: String) -> String {
//     // Reads input expressions and returns WAT equivalent
//     let mut lexed = lexer::lex(&input).unwrap();
//     let mut ast_node = parser::apply_operator_precedence(0, &mut lexed);
//     // Retrieve shorter summary wat for display.
//     let body = generator::expr_to_wat(&mut ast_node.parsed, 0);
    
//     // Evaluate full wat with std lib linked.
//     let full_wat = generator::link_avs(body);
//     return full_wat
// }

// pub fn read_multi(inputs: Vec<String>) -> String {
//     let mut body = String::from("");
//     let mut index = 0;
//     for input in inputs {
//         let mut lexed = lexer::lex(&input).unwrap();
//         let mut ast_node = parser::apply_operator_precedence(index, &mut lexed);

//         body += &generator::expr_to_wat(&mut ast_node.parsed, index as i32 );
//         index += 1;
//     }
//     let full_wat = generator::link_avs(body);
//     return full_wat
// }

// pub fn eval_compiled(wasm_binary: Vec<u8>) -> Vec<u64> {
//     let cell_count = 20;
//     let module = compile(&wasm_binary).unwrap();
    
//     println!("WASM Compile: {:?}", SystemTime::now());

//     // // We're not importing anything, so make an empty import object.
//     let import_object = imports! {};
//     let instance = module.instantiate(&import_object).unwrap();

//     println!("WASM instantiate: {:?}", SystemTime::now());

//     let main: Func<(u32),u32> = instance.func("__av_run").unwrap();
//     let value = main.call(cell_count).unwrap();

//     println!("Arevel Run: {:?}", SystemTime::now());
//     // let value = instance.call("_start", &[]);

//     // println!("Return value {:?}", value);
//     let memory = instance.context().memory(0);
//     // let memory_view: MemoryView<u64> = memory.view();
//     // let memory_view: MemoryView<u8> = memory.view();
//     let results = decode_flatbuf!(memory, value, cell_count);

//     // let cell_results = decode_values!(memory_view, value, cell_count);
//     let mut results2: Vec<u64> = Vec::with_capacity(cell_count as usize);

//     println!("Result : {:?} ", results);
//     println!("Result decode: {:?}", SystemTime::now());

//     // println!("At value {:?}", results);
//     // return results;
//     return results;
// }


// pub fn eval(wat: String) -> Vec<u64> {
//     let t0 = SystemTime::now();

//     let wasm_binary = wat2wasm(wat).unwrap();
//     let t1 = SystemTime::now();
    
//     println!("Wat2wasm: {:?}", t1.duration_since(t0));
//     let t2 = SystemTime::now();

//     let result = eval_compiled(wasm_binary);
//     // let result =  eval_interpreted(wasm_binary);

//     let t3 = SystemTime::now();
//     println!("Full Evaluation: {:?}", t3.duration_since(t2));

//     return result
// }

// fn print(result: u64) {
//     // TODO
//     println!("{:?}", format::repr(&AvObject::new(), result));
// }

// pub fn read_eval_print(input: String) {
//     let wat = read(input);
//     let result = eval(wat)[0];
//     print(result);
// }

// pub fn read_eval(input: String) -> String {
//     let wat = read(input);
//     let result = eval(wat)[0];
//     return format::repr(&AvObject::new(), result)
// }
