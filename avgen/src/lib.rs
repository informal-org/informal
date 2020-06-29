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


extern "C" {
    fn __aa_add(a: u64, b: u64) -> u64;
}

#[no_mangle]
#[export_name = "userrun"]
pub extern "C" fn userrun() -> u32 {
    unsafe {
        return __aa_add(12, 40) as u32
    }
}

