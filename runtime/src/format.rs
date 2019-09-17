use std::collections::HashMap;
use avs::runtime::ERR_MSG_MAP;
use crate::structs::Context;
use avs::types::{__av_typeof, is_error};
use avs::structs::{ValueType, Runtime, Atom};
use avs::constants::*;
use avs::runtime::{ID_SYMBOL_MAP};
use avs::format::{repr_atom, repr_number, repr_symbol};

pub fn repr(env: &Runtime, context: &Context, result: u64) -> String {
    let result_type = __av_typeof(result);
    // println!("repr {:X} {:?}", result, result_type);
    match result_type {
        ValueType::NumericType => {
            repr_number(result)
        },
        ValueType::SymbolType | ValueType::StringType => {
            if let Some(atom) = env.resolve_symbol(result) {
                repr_atom(atom)
            } else {
                repr_symbol(&result)
            }
        },
        ValueType::ObjectType => {
            if is_error(result) {
                repr_error(result)
            } else {
                if let Some(atom) = env.resolve_symbol(result) {
                    repr_atom(atom)
                } else {
                    repr_symbol(&result)
                }
            }
        }
        _ => {
            // Should not happen
            format!("{:?}: {:?}", result_type, result)
        }
    }
}

pub fn repr_known_symbol(env: &Runtime, context: &Context, symbol: u64) -> String {
    
    
    return repr_symbol(&symbol);
}

// pub fn print_stacktrace(env: &Runtime, stack: &Vec<u64>) {
//     println!("----------Stack----------");
//     for val in stack {
//         println!("{:?}", repr(env, *val));
//     }
//     println!("-------------------------");
// }

pub fn repr_object(obj: &Runtime) -> String {
    format!("(Object)")
}

pub fn repr_error(result: u64) -> String {
    // TODO: Return this as Error rather than Ok?
    // TODO: Log most common errors


    println!("{:X}", result);

    if let Some(msg) = ERR_MSG_MAP.get(&result) {
        msg.to_string()
    } else {
        format!("Sorry, Arevel encountered a completely unknown error: {:X}", result)
    }
}
