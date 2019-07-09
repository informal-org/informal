pub mod error;
pub mod lexer;
pub mod parser;
pub mod generator;
pub mod repl;


// use std::str;
use std::io::{stdin,stdout,Write};

use wasmer_runtime::{func, imports, Ctx, Value, compile};
use wasmer_runtime::{Func, Instance, error::ResolveResult};
use wabt::wat2wasm;


// static WAT: &'static str = r#"
// (module
//   (type $t0 (func (param i32 i32) (result i32)))
//   (type $t1 (func))
//   (func $add (type $t0) (param $p0 i32) (param $p1 i32) (result i32)
//     get_local $p0
//     get_local $p1
//     i32.add)
//   (func $f1 (type $t1))
//   (table $T0 1 anyfunc)
//   (memory $memory 0)
//   (export "memory" (memory 0))
//   (export "add" (func $add))
//   (elem (i32.const 0) $f1))
// "#;


// (module
//   (func $add (param $lhs i32) (param $rhs i32) (result i32)
//     get_local $lhs
//     get_local $rhs
//     i32.add)
//   (export "add" (func $add))
// )


static WAT: &'static str = r#"
(module
  (type $t0 (func (result f64)))
  (type $t1 (func (param f64) (result i32)))
  (func $main (type $t0) (result f64)
    (f64.const 1)
    (f64.const 2)
    f64.add)
  (table $T0 1 anyfunc)
  (memory $memory 0)
  (export "memory" (memory 0))
  (export "main" (func $main))
  )
"#;


// static WAT1: &'static str = r#"
// (module
//   (type $t0 (func (param i32) (result i32)))
//   (type $t1 (func))
//   (func $add (type $t0) (param $p0 i32) (result i32)
//     get_local $p0
//     i32.const 1
//     i32.add)
//   (func $f1 (type $t1))
//   (table $T0 1 anyfunc)
//   (memory $memory 0)
//   (export "memory" (memory 0))
//   (export "add" (func $add))
//   (elem (i32.const 0) $f1))
// "#;


// use std::time::{Duration, SystemTime};

// fn bench32() {

// }

fn eval_wat(){
    // Helper function for debugging various hard-coded wat routines

    let wasm_binary = wat2wasm(WAT).unwrap();
    let module = compile(&wasm_binary).unwrap();

    // // We're not importing anything, so make an empty import object.
    let import_object = imports! {};

    let instance = module.instantiate(&import_object).unwrap();
    let main: Func<(),f64> = instance.func("main").unwrap();
    // let value = main.call(32.0);
    let value = main.call(); //std::f64::NAN
    println!("{:?}",value);
}

fn repl_it() {
    loop {
        print!("> ");
        let _=stdout().flush();
        let mut reader = stdin();
        let mut input = String::new();
        reader.read_line(&mut input).ok().expect("Failed to read line");

        repl::read_eval_print(input);
    }
}


fn main() {
    println!("Arevel - Version - 1.0");

    const TAG_SHIFT: u64 = 48;
    const DOUBLE_MAX_TAG: u32 = 0b11111_11111_11000_0;
    const SHIFTED_DOUBLE_MAX_TAG: u64 = ((DOUBLE_MAX_TAG as u64) << TAG_SHIFT) | 0xFFFFFFFF;


    println!("shift {:b}", SHIFTED_DOUBLE_MAX_TAG);


    repl_it();
    // eval_wat();
}
