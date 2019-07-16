use super::lexer::*;
use std::fs;

use avs::constants::*;
use super::constants::*;
use super::structs::*;


pub fn operator_to_wat(operator: KeywordType) -> String {
    let wasm_op: &str = match operator {
        KeywordType::KwPlus => AV_STD_ADD,
        KeywordType::KwMinus => AV_STD_SUB,
        KeywordType::KwMultiply => AV_STD_MUL,
        KeywordType::KwDivide => AV_STD_DIV,
        
        KeywordType::KwAnd => AV_STD_AND,
        KeywordType::KwOr => AV_STD_OR,
        KeywordType::KwNot => AV_STD_NOT,

        KeywordType::KwLt => AV_STD_LT,
        KeywordType::KwLte => AV_STD_LTE,
        KeywordType::KwGt => AV_STD_GT,
        KeywordType::KwGte => AV_STD_GTE,
        _ => {""}
    };
    return String::from(wasm_op);
}

pub fn expr_to_wat(postfix: &mut Vec<TokenType>, id: i32) -> String {
    let mut result = String::from("");
    // Prepare for result save call. 
    // This is kinda hacky right now and depends on the linked symbols & positional locals.

    result += "(local.get 0)";
    result += &["(i32.const ", &id.to_string(), ")"].concat();   // Location/ID of cell

    for token in postfix.drain(..) {
        match token {
            TokenType::Keyword(kw) => {
                result += &operator_to_wat(kw);
            }, 
            TokenType::Literal(lit) => {
                match lit {
                    LiteralValue::NumericValue(num) => {
                        let lit_def = ["(f64.const ", &num.to_string(), ")", WASM_F64_AS_I64].concat();
                        result += &lit_def;
                    },
                    LiteralValue::BooleanValue(val) => {    // val = 1 or 0
                        let lit_def = ["(i64.const ", &val.to_string(), ")"].concat();
                        result += &lit_def;
                    },
                    _ => {
                        // Identifier = get
                        //     local.get 0
                        //     i32.const 0
                        //     call $__av_get

                        return String::from("");
                        
                    } // TODO
                }
            },
            _ => {
                // TODO
                return String::from("")
            }
        }
    }

    result += "(call $__av_save)";
    // result += "(drop)";
    return result;
}

pub fn link_avs(body: String) -> String {
    let header = fs::read_to_string("/Users/feni/code/arevel/avs/header.wat")
       .expect("Error reading header");

    let footer = fs::read_to_string("/Users/feni/code/arevel/avs/footer.wat")
       .expect("Error reading footer");

    return header + &body + ")" + &footer;
}
