/*
This module parallels the implementation in generator. 
It's meant for a highly responsive equivalent of the compiled code when editing.
There may be more of a hybrid version in the future, 
with interop with separately compiled modules.
*/

// use std::collections::HashMap;
use super::parser;
use super::lexer::*;
use super::structs::*;
use super::format::*;
use super::ast::*;
use super::constants::*;
use avs::operators::*;
use avs::types::*;
use avs::constants::*;
use avs::structs::{ValueType, AvObject, Atom};

macro_rules! apply_bin_op {
    ($env:expr, $op:expr, $stack:expr) => ({
        // Pop b first since it's in postfix
        let b = $stack.pop().unwrap();
        let a = $stack.pop().unwrap();
        $op(&mut $env, a, b)
    });
}


pub fn apply_operator(mut env: &mut AvObject, operator: u64, stack: &mut Vec<u64>) {
    let result = match operator {
        SYMBOL_PLUS => apply_bin_op!(env, __av_add, stack),
        SYMBOL_MINUS => apply_bin_op!(env, __av_sub, stack),
        SYMBOL_MULTIPLY => apply_bin_op!(env, __av_mul, stack),
        SYMBOL_DIVIDE => apply_bin_op!(env, __av_div, stack),
        
        SYMBOL_AND => apply_bin_op!(env, __av_and, stack),
        SYMBOL_OR => apply_bin_op!(env, __av_or, stack),
        SYMBOL_NOT => {
            __av_not(&mut env, stack.pop().unwrap())
        },

        SYMBOL_LT => apply_bin_op!(env, __av_lt, stack),
        SYMBOL_LTE => apply_bin_op!(env, __av_lte, stack),
        SYMBOL_GT => apply_bin_op!(env, __av_gt, stack),
        SYMBOL_GTE => apply_bin_op!(env, __av_gte, stack),
        _ => {
            // TODO: Is this correct? Or should it be INTERPRETER_ERR?
            // Unknown symbols are emitted as-is. 
            // They should be turned into functions?
            // INTERPRETER_ERR
            operator
        }
    };

    stack.push(result);
}


pub fn interpret_expr(mut env: &mut AvObject, node: &ASTNode, ast: &AST) -> u64 {
    // Propagate prior errors up.
    // TODO: Implement this in the compiler
    if node.result.is_some() {
        return node.result.unwrap();
    }

    // TODO: Faster stack version of this without heap alloc.
    let mut expr_stack: Vec<u64> = Vec::with_capacity(node.parsed.len());

    for token in node.parsed.iter() {
        match token {
            Atom::SymbolValue(kw) => {
                apply_operator(&mut env, *kw, &mut expr_stack);
            }, 
            Atom::NumericValue(num) => {
                // f64 -> u64
                expr_stack.push(num.to_bits());
            },
            Atom::StringValue(val) => {
                // Save object to heap and return pointer
                // Note: String copy likely occurs here
                let str_obj = AvObject::new_string(val.to_string());
                let heap_ptr = env.save_object(str_obj);
                expr_stack.push(heap_ptr);
            }
            //,
            //TokenType::Identifier(reference) => {
                // TODO: Lookup scoping rules
                // if let Some(&symbol_index) = ast.scope.symbols.get(&reference) {
                //     let deref_value = *ast.scope.values.get(symbol_index).unwrap();
                //     expr_stack.push(deref_value);
                // } else {
                //     println!("Could not find identifier! {:?}", reference);
                // }
            //}
            // _ => {
            //     // TODO
            //     // return String::from("")
            // }
        }
    }
    // Assert - only one value on expr stack
    return expr_stack.pop().unwrap();
}

pub fn interpret_one(input: String) -> u64 {
    let mut lexed = lex(&input).unwrap();
    let parsed = parser::apply_operator_precedence(0, &mut lexed).parsed;
    // TODO: A base, shared global namespace.
    let ast = AST::new();
    let mut node = ASTNode::new(0);
    node.parsed = parsed;
    let mut env = AvObject::new_env();
    return interpret_expr(&mut env, &node, &ast);
}

// pub fn build_ast(inputs: EvalRequest) {

// }

pub fn interpret_all(request: EvalRequest) -> EvalResponse {
    let mut results: Vec<CellResponse> = Vec::with_capacity(request.body.len());
    // External Global ID -> Internal ID
    let mut ast = construct_ast(request);
    let mut global_env = AvObject::new_env();

    for node in ast.body.iter() {
        let result = interpret_expr(&mut global_env, &node, &ast);
        
        let symbol_id = ast.scope.symbols.get(&node.id).unwrap();
        ast.scope.values[*symbol_id] = result; //.insert(symbol_id, result);

        // TODO: Split up the format if there's a different use-case that doesn't need the string format.
        let mut output = String::from("");
        let mut err = String::from("");
        
        match __av_typeof(result){
            ValueType::NumericType | ValueType::StringType | ValueType::SymbolType => {
                output = repr(&global_env, result);
            },
            ValueType::ObjectType => {
                if is_error(result) {
                    println!("Interpreter return returned true");
                    println!("{:X}, {:X}", result, result & VALUE_F_PTR_OBJ);
                    // Errors returned in different field.
                    err = repr_error(result);
                } else {
                    output = repr(&global_env, result);
                }
            }
        }

        results.push(CellResponse {
            id: ["@", &node.id.to_string()].concat(),
            output: output,
            error: err
        });
    }

    return EvalResponse {
        results: results
    }
}