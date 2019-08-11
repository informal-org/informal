use crate::structs::Context;
use avs::types::{__av_typeof, is_error};
use avs::structs::{ValueType, Runtime, Atom};
use avs::constants::*;
use avs::runtime::{ID_SYMBOL_MAP};
use avs::format::{repr_atom, repr_number, repr_symbol};

pub fn repr(env: &Runtime, context: &Context, result: u64) -> String {
    let result_type = __av_typeof(result);
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
                // TODO: Handle
                format!("(Object)")
            }
        }
        _ => {
            // Should not happen
            format!("{:?}: {:?}", result_type, result)
        }
    }
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


    // Guidelines:
    // Write errors for humans, not computers. No ParseError 0013: Err at line 2 col 4.
    // Sympathize with the user. Don't blame them (avoid 'your'). This may be their first exposure to programming.
    // Help them recover if possible. (Largely a TODO once we have error pointers)
    // https://uxplanet.org/how-to-write-good-error-messages-858e4551cd4
    // Alas - match doesn't work for this. These sholud be ordered by expected frequency.
    println!("{:X}", result);
    if result == RUNTIME_ERR {
        String::from("There was a mysterious error while running this code.")
    } else if result == PARSE_ERR {
        String::from("Arevel couldn't understand this expression.")
    } else if result == INTERPRETER_ERR {
        String::from("There was an unknown error while interpreting this code.")
    } else if result == PARSE_ERR_UNTERM_STR {
        String::from("Arevel couldn't find where this string ends. Make sure the text has matching quotation marks.")
    } else if result == PARSE_ERR_INVALID_FLOAT {
        String::from("This decimal number is in a weird format.")
    } else if result == PARSE_ERR_UNKNOWN_TOKEN {
        String::from("There's an unknown token in this expression.")
    } else if result == PARSE_ERR_UNEXPECTED_TOKEN {
        String::from("There's a token in an unexpected location in this expression.")
    } else if result == PARSE_ERR_UNMATCHED_PARENS {
        String::from("Arevel couldn't find where the brackets end. Check whether all opened brackets are closed.")
    } else if result == PARSE_ERR_UNK_SYMBOL {
        String::from("Arevel didn't recognize the symbol.")
    } else if result == RUNTIME_ERR_INVALID_TYPE {
        String::from("That data type doesn't work with this operation.")
    } else if result == RUNTIME_ERR_TYPE_NAN {
        String::from("This operation doesn't work with not-a-number (NaN) values.")
    } else if result == RUNTIME_ERR_EXPECTED_NUM {
        String::from("Arevel expects a number here.")
    } else if result == RUNTIME_ERR_EXPECTED_BOOL {
        String::from("Arevel expects a true/false boolean here.")
    } else if result == RUNTIME_ERR_UNK_VAL {
        String::from("The code tried to read from an unknown value.")
    } else if result == RUNTIME_ERR_CIRCULAR_DEP {
        // TODO: Specify which cells?
        String::from("There's a circular reference between these cells.")
    } else if result == RUNTIME_ERR_EXPECTED_STR {
        String::from("Arevel expects some text value here.")
    } else if result == RUNTIME_ERR_DIV_Z {
        String::from("Dividing by zero is undefined. Make sure the denominator is not a zero before dividing.")
    } else {
        format!("Sorry, Arevel encountered a completely unknown error: {:X}", result)
    }
}
