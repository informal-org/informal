/*
This module parallels the implementation in generator. 
It's meant for a highly responsive equivalent of the compiled code when editing.
There may be more of a hybrid version in the future, 
with interop with separately compiled modules.
*/

use std::collections::HashMap;
use super::parser;
use super::lexer::*;
use super::structs::*;
use super::format::*;
use avs::*;
use avs::constants::*;

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
        _ => {INTERPRETER_ERR}              // TODO
    };

    stack.push(result);
}


pub fn interpret_expr(postfix: &mut Vec<TokenType>, ast: &AST) -> u64 {
    println!("Interpreting {:?}", postfix);
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
            TokenType::Identifier(reference) => {
                // TODO: Lookup rules
                if let Some(val) = ast.namespace.values.get(&reference) {
                    expr_stack.push(val.clone());
                } else {
                    println!("Could not find identifier! {:?}", reference);
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
    let mut parsed = parser::apply_operator_precedence(&mut lexed).unwrap();
    // TODO: AST new.
    // TODO: A base, shared global namespace.
    let mut ast = AST {
        namespace: Namespace {
            parent: Box::new(None),
            values: HashMap::new()
        }
    };
    return interpret_expr(&mut parsed, &ast);
}

// pub fn build_ast(inputs: EvalRequest) {

// }

pub fn interpret_all(request: EvalRequest) -> EvalResponse {
    let mut results: Vec<CellResponse> = Vec::with_capacity(request.body.len());
    // External Global ID -> Internal ID
    let mut ast = AST {
        namespace: Namespace {
            parent: Box::new(None),
            values: HashMap::new()
        }
    };
    let mut index = 0;

    for cell in request.body {
        let mut lexed = lex(&cell.input).unwrap();
        // println!("Lex: {:?}", SystemTime::now().duration_since(t1));
        let mut parsed = parser::apply_operator_precedence(&mut lexed).unwrap();
        let result = interpret_expr(&mut parsed, &ast);

        // Attempt to parse ID of cell and save result
        if let Some(id64) = cell.id[1..].parse::<u64>().ok() {
            ast.namespace.values.insert(id64, result);
        }

        // TODO: Split up the format if there's a different use-case that doesn't need the string format.
        results.push(CellResponse {
            id: cell.id,
            output: repr(result),
            error: String::from("")
        });
        index += 1;
    }

    return EvalResponse {
        results: results
    }
}