use avs::error;
use avs::{__av_typeof, ValueType, VALUE_TRUE, VALUE_FALSE, VALUE_NONE};

pub fn repr(result: u64) -> String {
    let result_type = __av_typeof(result);
    match result_type {
        ValueType::NumericType => {
            let f_val: f64 = f64::from_bits(result);
            // Print integers without the trailing zeroes
            if f_val.fract() == 0.0 {
                format!("{:?}", f_val.trunc() as i64)
            } else {
                format!("{:?}", f_val)
            }
        },
        ValueType::BooleanType => {
            if result == VALUE_TRUE {
                format!("TRUE")
            } else {
                format!("FALSE")
            }
        },
        ValueType::ErrorType => {
            // TODO: Return this as Error rather than Ok?
            // TODO: Log most common errors
            println!("{:X}", result);
            
            // Guidelines:
            // Write errors for humans, not computers. No ParseError 0013: Err at line 2 col 4.
            // Sympathize with the user. Don't blame them (avoid 'your'). This may be their first exposure to programming.
            // Help them recover if possible. (Largely a TODO once we have error pointers)
            // https://uxplanet.org/how-to-write-good-error-messages-858e4551cd4
            // Alas - match doesn't work for this. These sholud be ordered by expected frequency.
            if result == error::RUNTIME_ERR {
                String::from("There was a mysterious error while running this code.")
            } else if result == error::PARSE_ERR {
                String::from("Arevel couldn't understand this expression.")
            } else if result == error::INTERPRETER_ERR {
                String::from("There was an unknown error while interpreting this code.")
            } else if result == error::PARSE_ERR_UNTERM_STR {
                String::from("Arevel couldn't find where this string ends. Make sure the text has matching quotation marks.")
            } else if result == error::PARSE_ERR_INVALID_FLOAT {
                String::from("This decimal number is in a weird format.")
            } else if result == error::PARSE_ERR_UNKNOWN_TOKEN {
                String::from("There's an unknown token in this expression.")
            } else if result == error::PARSE_ERR_UNEXPECTED_TOKEN {
                String::from("There's a token in an unexpected location in this expression.")
            } else if result == error::PARSE_ERR_UNMATCHED_PARENS {
                String::from("Arevel couldn't find where the brackets end. Check whether all opened brackets are closed.")
            } else if result == error::RUNTIME_ERR_INVALID_TYPE {
                String::from("That data type doesn't work with this operation.")
            } else if result == error::RUNTIME_ERR_TYPE_NAN {
                String::from("This operation doesn't work with not-a-number (NaN) values.")
            } else if result == error::RUNTIME_ERR_EXPECTED_NUM {
                String::from("Hmmm... Arevel expects a number here.")
            } else if result == error::RUNTIME_ERR_EXPECTED_BOOL {
                String::from("Arevel expects a true/false boolean here.")
            } else if result == error::RUNTIME_ERR_DIV_Z {
                String::from("Dividing by zero is undefined. Make sure the denominator is not a zero before dividing.")
            } else {
                format!("Sorry, Arevel encountered a completely unknown error: {:?}", result)
            }
        },
        _ => {
            format!("{:?}: {:?}", result_type, result)
        }
    }
}
