use crate::bytecode::*;

pub mod bytecode;
pub mod leb128;


// use wasm_bindgen::prelude::*;

// // When the `wee_alloc` feature is enabled, use `wee_alloc` as the global
// // allocator.
// #[cfg(feature = "wee_alloc")]
// #[global_allocator]
// static ALLOC: wee_alloc::WeeAlloc = wee_alloc::WeeAlloc::INIT;

// #[wasm_bindgen]
// extern {
//     fn alert(s: &str);
// }

// #[wasm_bindgen]
// pub fn greet() {
//     alert("Hello, usercode!");
// }


#[no_mangle]
#[export_name = "aa_gen_wasm"]
pub extern "C" fn aa_gen_wasm() -> u32 {


    return 0
}

