#[macro_use]
use super::lexer::*;
use super::parser::*;

use std::fs;

/*
// Takes parsed tokens and generates wasm code from it.
*/

pub const AV_STD_ADD: &'static str  = "(call $__av_add)\n";
pub const AV_STD_SUB: &'static str  = "(call $__av_sub)\n";
pub const AV_STD_MUL: &'static str  = "(call $__av_mul)\n";
pub const AV_STD_DIV: &'static str  = "(call $__av_div)\n";

pub const WASM_IBIN_AND: &'static str  = "(i32.and)\n";
pub const WASM_IBIN_OR: &'static str   = "(i32.or)\n";

// Not = val xor(1)
pub const WASM_IBIN_NOT: &'static str   = "(i32.const 1)(i32.xor)\n";

// alternatively. Do .nearest first
pub const WASM_F64_AS_I32: &'static str  = "(i32.trunc_s/f64)\n";

pub const WASM_I32_AS_F64: &'static str  = "(f64.convert_s/i32)\n";


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
            WASM_IBIN_AND
        }
        KeywordType::KwOr => {
            WASM_IBIN_OR
        }
        KeywordType::KwNot => {
            WASM_IBIN_NOT
        }
        _ => {""}
    };
    return String::from(wasm_op);
}

pub fn ast_to_wat(node: ASTNode) -> String {
    match node.node_type {
        ASTNodeType::BinaryExpression => {
            let mut result: Vec<String> = vec![];
            // TODO: Validate order
            result.push(ast_to_wat(*node.left.unwrap()));
            result.push(ast_to_wat(*node.right.unwrap()));
            result.push(operator_to_wat(node.operator.unwrap()));

            return result.join("");
        }, 
        ASTNodeType::Literal => {
            match node.value.unwrap() {
                Value::Literal(LiteralValue::NumericValue(num)) => {
                    let lit_def = ["(f64.const ", &num.to_string(), ")"].concat();
                    
                    return lit_def;
                },
                Value::Literal(LiteralValue::BooleanValue(val)) => {    // val = 1 or 0
                    let lit_def = ["(i32.const ", &val.to_string(), ")"].concat();
                    return lit_def;
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


pub fn expr_to_wat(node: ASTNode) -> String {
    let header = fs::read_to_string("/Users/feni/code/avstd/header.wat")
        .expect("Error reading header");

    let footer = fs::read_to_string("/Users/feni/code/avstd/footer.wat")
        .expect("Error reading footer");

    let mut body: Vec<String> = vec![];
    body.push(ast_to_wat(node));

    // for token in postfix {
    //     match &token {
    //         TokenType::Keyword(kw) => {

    //         }
    //         TokenType::Literal(lit) => {
    //             // TODO: Push the literal value
    //             match &lit {
    //             }
    //         },
    //         _ => {}
    //         // TODO
    //         // TokenType::Identifier(_id) => postfix.push(token),
    //     }
    // }

  return header + (&body.join("")) + ")" + &footer;
    
}

