use wasmer_runtime::{func, imports, Ctx, Value, compile};
use wasmer_runtime::{Func, Instance, error::ResolveResult};
use wabt::wat2wasm;

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
