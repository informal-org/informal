/*
This module parallels the implementation in generator. 
It's meant for a highly responsive equivalent of the compiled code when editing.
There may be more of a hybrid version in the future, 
with interop with separately compiled modules.
*/

use super::parser;
use super::generator;
use super::lexer::*;
use std::fs;
use avs::*;


macro_rules! apply_bin_op {
    ($op:expr, $stack:expr) => ({
        // Pop b first since it's in postfix
        let b = $stack.pop().unwrap();
        let a = $stack.pop().unwrap();
        $op(a, b)
    });
}


pub fn apply_operator(operator: KeywordType, stack: &mut Vec<u64>) {
    let result = match operator {
        KeywordType::KwPlus => apply_bin_op!(__av_add, stack),
        KeywordType::KwMinus => apply_bin_op!(__av_sub, stack),
        KeywordType::KwMultiply => apply_bin_op!(__av_mul, stack),
        KeywordType::KwDivide => apply_bin_op!(__av_div, stack),
        
        KeywordType::KwAnd => apply_bin_op!(__av_and, stack),
        KeywordType::KwOr => apply_bin_op!(__av_or, stack),
        KeywordType::KwNot => {
            __av_not(stack.pop().unwrap())
        },

        KeywordType::KwLt => apply_bin_op!(__av_lt, stack),
        KeywordType::KwLte => apply_bin_op!(__av_lte, stack),
        KeywordType::KwGt => apply_bin_op!(__av_gt, stack),
        KeywordType::KwGte => apply_bin_op!(__av_gte, stack),
        _ => {0} // TODO
    };

    stack.push(result);
}


pub fn interpret_expr(postfix: &mut Vec<TokenType>, id: i32) -> u64 {
    println!("{:?}", postfix);
    // TODO: Faster stack version of this without heap alloc.
    let mut expr_stack: Vec<u64> = Vec::with_capacity(postfix.len());

    for token in postfix.drain(..) {
        match token {
            TokenType::Keyword(kw) => {
                apply_operator(kw, &mut expr_stack);
            }, 
            TokenType::Literal(lit) => {
                match lit {
                    LiteralValue::NumericValue(num) => {
                        println!("Pushing {:?} bits {:?}", num, num.to_bits());
                        // f64 -> u64
                        expr_stack.push(num.to_bits());
                    },
                    LiteralValue::BooleanValue(val) => {    // val = 1 or 0
                        expr_stack.push(val);
                    },
                    _ => {
                        // TODO
                    } 
                }
            },
            _ => {
                // TODO
                // return String::from("")
            }
        }
    }
    // Assert - only one value on expr stack
    return expr_stack.pop().unwrap();
}

pub fn interpret_one(input: String) -> u64 {
    let mut lexed = lex(&input).unwrap();
    let mut parsed = parser::parse(&mut lexed).unwrap();
    return interpret_expr(&mut parsed, 0);
}

pub fn interpret_all(inputs: Vec<String>) -> Vec<u64> {
    let mut results: Vec<u64> = Vec::with_capacity(inputs.len());
    let mut index = 0;

    for input in inputs {
        let mut lexed = lex(&input).unwrap();
        // println!("Lex: {:?}", SystemTime::now().duration_since(t1));
        let mut parsed = parser::parse(&mut lexed).unwrap();
        results.push(interpret_expr(&mut parsed, index));
        index += 1;
    }
    return results;
}