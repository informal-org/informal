use avs::environment::Environment;
use std::collections::HashMap;
use avs::runtime::ERR_MSG_MAP;
use avs::types::{__av_typeof, is_error};
use avs::structs::{ValueType, Atom};
use avs::constants::*;
use avs::runtime::{ID_SYMBOL_MAP};
use avs::format::{repr_atom, repr_number, repr_symbol};

// TODO: just move this to avs
pub fn repr(env: &Environment, result: u64) -> String {
    let result_type = __av_typeof(result);
    // println!("repr {:X} {:?}", result, result_type);

    match result_type {
        ValueType::NumericType => {
            return repr_number(result)
        },
        ValueType::SymbolType => {
            return repr_symbol(&result)
        },
        _ => {
            if let Some(identifier) = env.lookup(result) {
                println!("repr is identifier");
                if let Some(atom) = &identifier.value {
                    return repr_atom(&atom);
                }
            }
        }
    }



    // Unknown symbol
    return repr_symbol(&result);
}

// pub fn repr_known_symbol(env: &Runtime, context: &Context, symbol: u64) -> String {
//     return repr_symbol(&symbol);
// }

// pub fn print_stacktrace(env: &Runtime, stack: &Vec<u64>) {
//     println!("----------Stack----------");
//     for val in stack {
//         println!("{:?}", repr(env, *val));
//     }
//     println!("-------------------------");
// }

// pub fn repr_object(obj: &Runtime) -> String {
//     format!("(Object)")
// }

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
