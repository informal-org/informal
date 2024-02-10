use crate::bytecode::*;
use crate::encoding::*;
use crate::leb128::*;

pub mod bytecode;
pub mod leb128;
pub mod encoding;


use wasm_bindgen::prelude::*;

// // When the `wee_alloc` feature is enabled, use `wee_alloc` as the global
// // allocator.
#[cfg(feature = "wee_alloc")]
#[global_allocator]
static ALLOC: wee_alloc::WeeAlloc = wee_alloc::WeeAlloc::INIT;

// #[wasm_bindgen]
// extern {
//     fn alert(s: &str);
// }

// #[wasm_bindgen]
// pub fn greet() {
//     alert("Hello, usercode!");
// }

#[wasm_bindgen]
pub struct GenWasm {
    code: Vec<u8>
}

// #[export_name = "aa_gen_wasm"]
// #[no_mangle]
#[wasm_bindgen]
pub extern "C" fn aa_gen_wasm() -> Vec<u8> {
    let mut add_func_type: Vec<u8> = vec![FUNC_TYPE];
    let params: Vec<u8> = vec![VAL_F32, VAL_F32];
    let ret_type: Vec<u8> = vec![VAL_F32];
    add_func_type.append(&mut encode_vector(params));
    add_func_type.append(&mut encode_vector(ret_type));

    let types = vec![add_func_type];

    let mut type_section = encode_section(SECTION_TYPE, encode_nested_vector(types));

    // println!("Type section: {:02x?}", type_section);

    let func_index_vec: Vec<u8> = vec![0x00];
    let mut func_section = encode_section(SECTION_FUNCTION, encode_vector(func_index_vec));

    // println!("Func section: {:02x?}", func_section);

    let mut export_fn0: Vec<u8> = vec![];
    export_fn0.append(&mut encode_string("run".to_string()));
    export_fn0.push(EXPORT_FUNC);
    export_fn0.push(0x00);   // function index


    let all_exports = vec![export_fn0];
    let mut export_section = encode_section(SECTION_EXPORT, encode_nested_vector(all_exports));
    // println!("Export section: {:02x?}", export_section);

    let mut code: Vec<u8> = vec![];
    code.push(OP_LOCAL_GET);
    code.append(&mut encode_unsigned(0));
    code.push(OP_LOCAL_GET);
    code.append(&mut encode_unsigned(1));
    code.push(OP_F32_ADD);

    let mut func0: Vec<u8> = vec![];
    func0.push(0x00);
    func0.append(&mut code);
    func0.push(OP_END);

    let all_functions = vec![encode_vector(func0)];
    let mut code_section = encode_section(SECTION_CODE, encode_nested_vector(all_functions));

    // println!("Code section: {:02x?}", code_section);

    let mut full_code: Vec<u8> = vec![];
    full_code.append(&mut MODULE_MAGIC.to_vec());
    full_code.append(&mut MODULE_VERSION.to_vec());

    full_code.append(&mut type_section);
    full_code.append(&mut func_section);
    full_code.append(&mut export_section);
    full_code.append(&mut code_section);

    return full_code
}

#[cfg(test)]
mod tests {
    use super::*;
    // extern crate test;


    #[test]
    fn test_gen_add_fn() {
        let result_code = aa_gen_wasm();
        let expected_code = vec![
            0x00, 0x61, 0x73, 0x6d, 0x01, 0x00, 0x00, 0x00, 
            0x01, 0x07, 0x01, 0x60, 0x02, 0x7d, 0x7d, 0x01, 
            0x7d, 0x03, 0x02, 0x01, 0x00, 0x07, 0x07, 0x01, 
            0x03, 0x72, 0x75, 0x6e, 0x00, 0x00, 0x0a, 0x09, 
            0x01, 0x07, 0x00, 0x20, 0x00, 0x20, 0x01, 0x92, 
            0x0b
        ];

        assert_eq!(expected_code, result_code);
    }
}