// use std::fs;
// use super::constants::*;
// use avs::constants::*;
// use avs::structs::Atom;



// pub fn operator_to_wat(operator: u64) -> String {
//     let wasm_op: String = match operator {
//         SYMBOL_PLUS => String::from(AV_STD_ADD),
//         SYMBOL_MINUS => String::from(AV_STD_SUB),
//         SYMBOL_MULTIPLY => String::from(AV_STD_MUL),
//         SYMBOL_DIVIDE => String::from(AV_STD_DIV),
        
//         SYMBOL_AND => String::from(AV_STD_AND),
//         SYMBOL_OR => String::from(AV_STD_OR),
//         SYMBOL_NOT => String::from(AV_STD_NOT),

//         SYMBOL_LT => String::from(AV_STD_LT),
//         SYMBOL_LTE => String::from(AV_STD_LTE),
//         SYMBOL_GT => String::from(AV_STD_GT),
//         SYMBOL_GTE => String::from(AV_STD_GTE),
//         _ => {
//             // TODO! This works for true/false, what about other symbols?
//             let symbol_val = ["(i64.const ", &operator.to_string(), ")"].concat();
//             symbol_val
//         }
//     };
//     return wasm_op;
// }

// pub fn expr_to_wat(postfix: &mut Vec<Atom>, id: i32) -> String {
//     let mut result = String::from("");
//     // Prepare for result save call. 
//     // This is kinda hacky right now and depends on the linked symbols & positional locals.

//     result += "(local.get 0)";
//     result += &["(i32.const ", &id.to_string(), ")"].concat();   // Location/ID of cell

//     for token in postfix.drain(..) {
//         match token {
//             Atom::SymbolValue(kw) => {
//                 result += &operator_to_wat(kw);
//             }, 
//             Atom::NumericValue(num) => {
//                 let lit_def = ["(f64.const ", &num.to_string(), ")", WASM_F64_AS_I64].concat();
//                 result += &lit_def;
//             },
//             _ => {
//                 // TODO: Strings
//                 // Identifier = get
//                 //     local.get 0
//                 //     i32.const 0
//                 //     call $__av_get

//                 return String::from("");
                
//             } // TODO
//         }
//     }

//     result += "(call $__av_save)";
//     // result += "(drop)";
//     return result;
// }

// pub fn link_avs(body: String) -> String {
//     let header = fs::read_to_string("../avs/header.wat")
//        .expect("Error reading header");

//     let footer = fs::read_to_string("../avs/footer.wat")
//        .expect("Error reading footer");

//     // TODO: Have this remove all the internal export functions as well.

//     return header + &body + ")" + &footer;
// }
