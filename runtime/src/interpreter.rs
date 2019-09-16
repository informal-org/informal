/*
This module parallels the implementation in generator. 
It's meant for a highly responsive equivalent of the compiled code when editing.
There may be more of a hybrid version in the future, 
with interop with separately compiled modules.
*/

use avs::runtime::RESERVED_SYMBOLS;
use avs::runtime::ID_SYMBOL_MAP;
use avs::functions::NativeFn;
use super::parser;
use super::lexer::*;
use super::structs::*;
use super::format::*;
use super::ast::*;
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

pub fn call_function(mut env: &mut Runtime, stack: &mut Vec<u64>) -> u64 {
    // TODO: Stack bounds checks
    let func_symbol = stack.pop().unwrap();
    if let Some(func_atom) = env.get_atom(func_symbol) {
        match func_atom {
            Atom::FunctionValue(fval) => {
                match fval {
                    NativeFn::Fn2(f2) => {
                        // TODO: Verify stack size
                        // Pop in reverse order since stack is in postfix
                        let b = stack.pop().unwrap();
                        let a = stack.pop().unwrap();
                        let fn_result = (f2.func)(&mut env, a, b);
                        return fn_result
                    }
                    NativeFn::Fn1(f1) => {
                        let a = stack.pop().unwrap();
                        let fn_result = (f1.func)(&mut env, a);
                        return fn_result
                    },
                    _ => {
                        return RUNTIME_ERR_FN_UNK
                    }
                }
            }
            _ => {
                return RUNTIME_ERR_FN_EXPECTED
            }
        }
    } else {
        return RUNTIME_ERR_FN_UNK
    }
}

pub fn apply_operator(mut env: &mut Runtime, operator: u64, mut stack: &mut Vec<u64>) -> u64 {
    // println!("Operator: {}", repr(&env, operator));
    // print_stacktrace(env, &stack);

    let symbol_index = operator & PAYLOAD_MASK;
    if symbol_index < (RESERVED_SYMBOLS.len() as u64) {
        let symbol = RESERVED_SYMBOLS[symbol_index as usize];
        if symbol.operation.is_some() {
            let op_func = symbol.operation.unwrap();
            let b = stack.pop().unwrap();
            let a = stack.pop().unwrap();
            return (op_func)(&mut env, a, b)
        } else {
            // Handle unary functions and other special cases
            if *symbol == SYMBOL_CALL_FN {
                return call_function(&mut env, &mut stack)
            }
            else if *symbol == SYMBOL_NOT {
                return __av_not(&mut env, stack.pop().unwrap())
            } else {
                // Emit as value. Ex. True, None, etc.
                return operator
            }
        }
    } else {
        // Symbol not found in operators. Emit as-is as a symbol.
        println!("Unknown symbol {:X}", operator);
        return operator
    };
    // print_stacktrace(env, &stack);
    // println!("Next");
}

fn is_keyword(symbol: u64) -> bool {
    return (symbol & PAYLOAD_MASK) < 255;
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
                if is_keyword(*kw) {
                    let result = apply_operator(&mut env, *kw, &mut expr_stack);
                    expr_stack.push(result);
                } else {
                    // println!("Looking up symbol {:X}", kw);
                    // Lookup result of symbol
                    // TODO: Pointer vs symbols
                    // TODO: Scoping rules
                    if let Some(atom) = env.resolve_symbol(*kw) {
                        // println!("Resolved to {:?}", atom);
                        match atom {
                            Atom::NumericValue(num) => {
                                expr_stack.push(num.to_bits());
                            },
                            Atom::SymbolValue(sym) => {
                                expr_stack.push(*sym);
                            }, 
                            _ => {
                                expr_stack.push(*kw);
                            }
                        }
                    } else {
                        // println!("Unresolved {:X}", kw);
                        expr_stack.push(*kw);
                    }
                }
            }, 
            Atom::NumericValue(num) => {
                // f64 -> u64
                expr_stack.push(num.to_bits());
            },
            Atom::StringValue(val) => {
                // Save object to heap and return pointer
                // TODO: Non-copying version
                let symbol_id = env.save_string(Atom::StringValue(val.to_string()));
                expr_stack.push(symbol_id);
            },
            _ => {
                println!("Unexpected Object/hashmap Atom found?");
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
    let parsed = parser::apply_operator_precedence(&ast, 0, ast.next_symbol_id, &mut lexed).parsed;
    println!("parsed: {:?}", parsed);
    // TODO: A base, shared global namespace.
    
    let mut node = Expression::new(0);
    node.parsed = parsed;
    let mut env = Runtime::new(ast.next_symbol_id);
    return interpret_expr(&mut env, &node, &ast);
}

pub fn init_runtime_input(runtime: &mut Runtime, input: &Option<AvHttpRequest>) {
    if let Some(request) = input {
        runtime.set_atom(AV_HTTP_PATH, Atom::StringValue(request.path.to_string()));
    }
}


pub fn interpret_all(request: EvalRequest) -> EvalResponse {
    let mut results: Vec<CellResponse> = Vec::with_capacity(request.body.len());
    // External Global ID -> Internal ID
    let mut ast = construct_ast(&request);
    let mut global_env = Runtime::new(ast.next_symbol_id);

    init_runtime_input(&mut global_env, &request.input);

    // println!("AST: {:?}", ast);

    for node in ast.body.iter() {
        let result = interpret_expr(&mut global_env, &node, &ast);
        // println!("Got result {:?}", repr(&global_env, &ast, result));
        
        // Don't double-encode symbols
        // let symbol_id = ast.cell_symbols.as_ref().unwrap().get(&node.id).unwrap();
        let symbol_id = node.cell_symbol;
        global_env.set_value(symbol_id, result);

        let mut output = String::from("");
        let mut err = String::from("");
        
        match __av_typeof(result){
            ValueType::NumericType | ValueType::StringType | ValueType::SymbolType => {
                output = repr(&global_env, &ast, result);
            },
            ValueType::ObjectType => {
                if is_error(result) {
                    // Errors returned in different field.
                    err = repr_error(result);
                } else {
                    output = repr(&global_env, &ast, result);
                }
            },
            ValueType::HashMapType => {}
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
