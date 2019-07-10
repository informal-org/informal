use super::lexer::*;
use std::fs;

/*
// Takes parsed tokens and generates wasm code from it.
*/
pub const AV_STD_ADD: &'static str  = "(call $__av_add)\n";
pub const AV_STD_SUB: &'static str  = "(call $__av_sub)\n";
pub const AV_STD_MUL: &'static str  = "(call $__av_mul)\n";
pub const AV_STD_DIV: &'static str  = "(call $__av_div)\n";

pub const AV_STD_AND: &'static str  = "(call $__av_and)\n";
pub const AV_STD_OR: &'static str   = "(call $__av_or)\n";
pub const AV_STD_NOT: &'static str   = "(call $__av_not)\n";

// alternatively. Do .nearest first
pub const WASM_F64_AS_I32: &'static str  = "(i32.trunc_s/f64)\n";
pub const WASM_I32_AS_F64: &'static str  = "(f64.convert_s/i32)\n";
pub const WASM_F64_AS_I64: &'static str = "(i64.reinterpret_f64)\n";

pub fn operator_to_wat(operator: KeywordType) -> String {
    let wasm_op: &str = match operator {
        KeywordType::KwPlus => {
            AV_STD_ADD
        }
        KeywordType::KwMinus => {
            AV_STD_SUB
        }
        KeywordType::KwMultiply => {
            AV_STD_MUL
        }
        KeywordType::KwDivide => {
            AV_STD_DIV
        }
        
        // TODO: Type checking of values?
        KeywordType::KwAnd => {
            AV_STD_AND
        }
        KeywordType::KwOr => {
            AV_STD_OR
        }
        KeywordType::KwNot => {
            AV_STD_NOT
        }
        _ => {""}
    };
    return String::from(wasm_op);
}

pub fn expr_to_wat(postfix: &mut Vec<TokenType>) -> String {
    let mut result = String::from("");
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
                    _ => {return String::from("");} // TODO
                }
            },
            _ => {
                // TODO
                return String::from("")
            }
        }
    }
    return result;

}


pub fn link_av_std(body: String) -> String {
    let header = fs::read_to_string("/Users/feni/code/arevel/avs/header.wat")
        .expect("Error reading header");

    let footer = fs::read_to_string("/Users/feni/code/arevel/avs/footer.wat")
        .expect("Error reading footer");

    return header + &body + ")" + &footer;
}

