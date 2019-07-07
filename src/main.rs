extern crate arevel;


pub mod lexer;
pub mod parser;
pub mod error;
pub mod repl;


// use std::str;
use std::io::{stdin,stdout,Write};


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


fn main() {
    // println!("{:?}", lexer::lex("1232 + 23.32/459.4 + 312 - hello"))
    loop {
        print!("> ");
        let _=stdout().flush();
        let mut reader = stdin();
        let mut input = String::new();
        reader.read_line(&mut input).ok().expect("Failed to read line");

        repl::read_eval_print(input);
    }



    // // assert_eq!(value, 42);
     
    // // Ok(())

    // println!("Done");
}
