mod parser;
use std::str;

use wasmer_runtime::{error, func, imports, Ctx, Value, compile};
use wasmer_runtime::{Func, Instance, error::ResolveResult};


use wabt::wat2wasm;

static WAT: &'static str = r#"
(module
  (type $t0 (func (param i32 i32) (result i32)))
  (type $t1 (func))
  (func $add (type $t0) (param $p0 i32) (param $p1 i32) (result i32)
    get_local $p0
    get_local $p1
    i32.add)
  (func $f1 (type $t1))
  (table $T0 1 anyfunc)
  (memory $memory 0)
  (export "memory" (memory 0))
  (export "add" (func $add))
  (elem (i32.const 0) $f1))
"#;

static WAT1: &'static str = r#"
(module
  (type $t0 (func (param i32) (result i32)))
  (type $t1 (func))
  (func $add (type $t0) (param $p0 i32) (result i32)
    get_local $p0
    i32.const 1
    i32.add)
  (func $f1 (type $t1))
  (table $T0 1 anyfunc)
  (memory $memory 0)
  (export "memory" (memory 0))
  (export "add" (func $add))
  (elem (i32.const 0) $f1))
"#;


use std::time::{Duration, SystemTime};

fn bench32() {

}


fn main() {
    println!("hey");
    println!("{:?}", parser::lex("1232 + 23.32/459.4 + 312 - hello"))

    // let wasm_binary = wat2wasm(WAT).unwrap();
    
    // let module = compile(&wasm_binary).unwrap();

    // // We're not importing anything, so make an empty import object.
    // let import_object = imports! {};
    

    // let instance = module.instantiate(&import_object).unwrap();

    // let add_one: Func<(i32, i32), i32> = instance.func("add").unwrap();

    // let param: i32 = 41;
    // let value = add_one.call(param, 1);
    // println!("{:?}", value);

    // // assert_eq!(value, 42);
     
    // // Ok(())

    // println!("Done");
}
