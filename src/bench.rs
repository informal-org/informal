

use std::time::{SystemTime};


use wasmer_runtime::{imports, compile};
use wasmer_runtime::{Func};
use wabt::wat2wasm;

fn bench() {

    let wat = repl::read(String::from("1 + 1"));

    let wasm_binary = wat2wasm(wat).unwrap();
    let module = compile(&wasm_binary).unwrap();

    // // We're not importing anything, so make an empty import object.
    let import_object = imports! {};

    let instance = module.instantiate(&import_object).unwrap();
    let main: Func<(),u64> = instance.func("_start").unwrap();

    let start = SystemTime::now();

    for i in 0..500_000 {
        // print!("> ");
        // let _=stdout().flush();
        // let reader = stdin();
        // let mut input = String::new();
        // reader.read_line(&mut input).ok().expect("Failed to read line");

        // repl::read_eval_print(input);
        
        let value = main.call();
    }
    let end = SystemTime::now();
    println!("{:?}", end.duration_since(start));
}