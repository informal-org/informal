/*
This module parallels the implementation in generator. 
It's meant for a highly responsive equivalent of the compiled code when editing.
There may be more of a hybrid version in the future, 
with interop with separately compiled modules.
*/

use avs::runtime::ID_SYMBOL_MAP;
use super::parser;
use super::lexer::*;
use super::structs::*;
use super::format::*;
use super::ast::*;
use super::constants::*;
use avs::operators::*;
use avs::types::*;
use avs::constants::*;
use avs::structs::{ValueType, AvObject, Atom, Runtime};


macro_rules! apply_bin_op {
    ($env:expr, $op:expr, $stack:expr) => ({
        // Pop b first since it's in postfix
        let b = $stack.pop().unwrap();
        let a = $stack.pop().unwrap();
        $op(&mut $env, a, b)
    });
}


pub fn apply_operator(mut env: &mut Runtime, operator: u64, stack: &mut Vec<u64>) {
    // println!("Operator: {}", repr(&env, operator));
    // print_stacktrace(env, &stack);
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
            operator
        }
    };
    stack.push(result);
    // print_stacktrace(env, &stack);
    // println!("Next");
}


pub fn interpret_expr(mut env: &mut Runtime, expression: &Expression, context: &Context) -> u64 {
    // Propagate prior errors up.
    if expression.result.is_some() {
        return expression.result.unwrap();
    }

    // TODO: Faster stack version of this without heap alloc.
    let mut expr_stack: Vec<u64> = Vec::with_capacity(expression.parsed.len());

    for token in expression.parsed.iter() {
        match token {
            Atom::SymbolValue(kw) => {
                // TODO: Check if built in operator or an identifier
                if ID_SYMBOL_MAP.contains_key(kw) {
                    println!("Detected symbol as a built-in operator");
                    apply_operator(&mut env, *kw, &mut expr_stack);
                } else {
                    expr_stack.push(*kw);
                    // TODO: Scoping rules
                }
            }, 
            Atom::NumericValue(num) => {
                // f64 -> u64
                expr_stack.push(num.to_bits());
            },
            Atom::StringValue(val) => {
                // Save object to heap and return pointer
                // TODO: Non-copying version
                let symbol_id = env.save_atom(Atom::StringValue(val.to_string()));
                expr_stack.push(symbol_id);
            },
            Atom::ObjectValue(val) => {
                println!("Unexpected Object Atom found?");
            }
        }
    }
    // Assert - only one value on expr stack
    return expr_stack.pop().unwrap();
}

pub fn interpret_one(input: String) -> u64 {
    let mut ast = Context::new(APP_SYMBOL_START);
    println!("Input: {:?}", input);
    let mut lexed = lex(&mut ast, &input).unwrap();
    println!("Lexed: {:?}", lexed);
    let parsed = parser::apply_operator_precedence(0, &mut lexed).parsed;
    println!("parsed: {:?}", parsed);
    // TODO: A base, shared global namespace.
    
    let mut node = Expression::new(0);
    node.parsed = parsed;
    let mut env = Runtime::new(ast.next_symbol_id);
    return interpret_expr(&mut env, &node, &ast);
}


pub fn interpret_all(request: EvalRequest) -> EvalResponse {
    let mut results: Vec<CellResponse> = Vec::with_capacity(request.body.len());
    // External Global ID -> Internal ID
    let mut ast = construct_ast(request);
    let mut global_env = Runtime::new(ast.next_symbol_id);

    println!("AST: {:?}", ast);

    for node in ast.body.iter() {
        let result = interpret_expr(&mut global_env, &node, &ast);
        println!("Got result {:?}", repr(&global_env, result));
        
        // Don't double-encode symbols
        let symbol_id = ast.cell_symbols.as_ref().unwrap().get(&node.id).unwrap();
        global_env.set_value(*symbol_id, result);

        let mut output = String::from("");
        let mut err = String::from("");
        
        match __av_typeof(result){
            ValueType::NumericType | ValueType::StringType | ValueType::SymbolType => {
                output = repr(&global_env, result);
            },
            ValueType::ObjectType => {
                if is_error(result) {
                    // Errors returned in different field.
                    err = repr_error(result);
                } else {
                    output = repr(&global_env, result);
                }
            }
        }

        let result_symbol_id = ast.cell_symbols.as_ref().unwrap().get(&node.id).unwrap();

        results.push(CellResponse {
            // id: ["@", &node.id.to_string()].concat(),
            id: node.id,
            output: output,
            error: err
        });
    }

    return EvalResponse {
        results: results
    }
}