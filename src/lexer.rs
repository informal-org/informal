extern crate lexical;

use std::iter::Peekable;

#[derive(Debug,PartialEq)]
pub enum TokenType {
    Literal(LiteralValue),
    Identifier(String),
    OpPlus,
    OpMinus,
    OpMultiply,
    OpDivide,
    OpOpenParen,
    OpCloseParen,
    OpEquals,
    OpGt,
    OpLt,
    OpGte,
    OpLte,
    OpAnd,
    OpOr,
    OpNot,
    OpIs,
}

#[derive(Debug,PartialEq)]
enum LiteralValue {
    NoneValue,
    BooleanValue(bool), 
    NumericValue(f64),    // Integers are represented within the floats.
    StringValue(String),  // TODO: String -> Obj. To c-string.
}


// These could both be sets, but honestly seems like array would be
// more performant here given how small it is. 
// Worth a micro-benchmark later. 
const UNARY_OPS: &[&str] = &["-", "NOT", "Not", "not"];

const BINARY_OPS: &[&str] =      &["OR", "Or", "or", "AND", "And", "and", "IS", "Is", "is", "<", ">", "<=", ">=", "+", "-", "*", "/"];
const BINARY_PRECEDENCE: &[i8] = &[ 1,    1,     1,   2,      2,    2,     6,    6,      6,  7,   7,   7,  7,    9,    9,   10,  10];

// This may be tricky since the result is of a mixed value type
const LITERAL: &[&str] = &["TRUE", "True", "true", "FALSE", "False", "false", "NONE", "None", "none"];
const LITERAL_VAL: &[LiteralValue] = &[LiteralValue::BooleanValue(true), LiteralValue::BooleanValue(true), LiteralValue::BooleanValue(true), LiteralValue::BooleanValue(false), LiteralValue::BooleanValue(false), LiteralValue::BooleanValue(false), LiteralValue::NoneValue, LiteralValue::NoneValue, LiteralValue::NoneValue];

fn throw_error(message: &str, index: i32) {
    // TODO: Throw an actual error, ey?
    println!("{} at character {}", message, index);
}

fn is_digit(ch: char) -> bool {
    return ch >= '0' && ch <= '9';
}

fn gobble_digits(token: &mut String, it: &mut Peekable<std::str::Chars<'_>>) {
    while let Some(&body) = it.peek() {
        if is_digit(body) {
            token.push(body);
            it.next();
        } else {
            break;
        }
    }
}

fn parse_number(it: &mut Peekable<std::str::Chars<'_>>) -> LiteralValue {
    // TODO: add a token type which will save some of the metadata
    // about it being a float vs int.
    // TODO: Group floating point numbers together into a single token.
    let mut token = String::from("");
    let mut is_float = false;

    // Leading decimal digits
    gobble_digits(&mut token, it);

    // (Optional) decimal
    if let Some(&decimal) = it.peek() {
        if decimal == '.' {
            is_float = true;
            token.push(decimal);
            it.next();

            // (Optional) decimal digits
            gobble_digits(&mut token, it);
        }
    }

    // (Optional) Exponent
    if let Some(&exp) = it.peek() {
        if exp == 'e' || exp == 'E' {
            is_float = true;
            token.push(exp);
            it.next();

            if let Some(&exp_sign) = it.peek() {
                if exp_sign == '+' || exp_sign == '-' {
                    token.push(exp_sign);
                    it.next();
                }
            }

            // Can't have a bare exponent without a value
            // Alternatively, treat this as e1
            if let Some(&exp_digit) = it.peek() {
                if !is_digit(exp_digit) {
                    // TODO: Error handling
                    println!("Invalid exponent.")
                }
            }
            gobble_digits(&mut token, it);
        }
    }
    // Parse should be sufficient since we've validated format already.
    let val: f64 = lexical::parse(token);
    return LiteralValue::NumericValue(val);
}

fn parse_string(it: &mut Peekable<std::str::Chars<'_>>) -> LiteralValue {
    let mut token = String::from("");
    
    // Don't include the quotes in the resulting string.
    // Starting quote is always present for this function to be called.
    let quote_start = it.next().unwrap();
    let mut terminated: bool = false;

    while let Some(&ch) = it.peek() {
        // Backslash escape sequences
        match ch {
            '\\' => {
                it.next(); // Skip over the slash
                // \\ \' \" \r \n
                if let Some(&escaped) = it.peek() {
                    match escaped {
                        '\\' | '\'' | '"' => token.push(escaped),
                        'n' => token.push('\n'),
                        'r' => token.push('\r'),
                        't' => token.push('\t'),
                        '0' => token.push('\0'),
                        _ => {
                            // Push other sequences as-is
                            token.push('\\');
                            token.push(escaped);
                        }
                    }
                    it.next();
                }
            }
            _ if ch == quote_start => {
                // End of string
                it.next();
                terminated = true;
                break;
            }
            _ => {
                token.push(ch);
                it.next();
            }
        }
    }
    // TODO: Throw error for non-terminated strings.
    return LiteralValue::StringValue(token);
}

fn parse_identifier(it: &mut Peekable<std::str::Chars<'_>>) -> String {
    let mut token = String::from("");
    // Assert - the caller checks if the first char is not a number
    while let Some(&ch) = it.peek() {
        match ch {
            // IDs are separate from names, so the character set could be more restrictive.
            'a'...'z' | 'A'...'Z' | '_' | '0'...'9' => {
                token.push(ch);
                it.next(); 
            }
            _ => {
                break;
            }
        }
    }
    return token;
}

// One-liner shorthand to advance the iterator and return the given value
macro_rules! lex_advance_return {
    ($it:expr, $e:expr) => ({
        $it.next();
        Some($e)
    });
}

// Shortcut for lte and gte - check next token and decide which form it is.
macro_rules! lex_comparison_eq {
    ($it:expr, $comp:expr, $comp_eq:expr) => ({
        $it.next();
        if let Some(&eq) = $it.peek() {
            if eq == '=' {
                $it.next();
                Some($comp_eq)
            } else {
                Some($comp)
            }
        } else {
            Some($comp)
        }
    });
}

pub fn lex(expr: &str) -> Vec<TokenType> {
    // Split into lexems based on some known operators
    let mut tokens: Vec<TokenType> = vec![];
    let mut it = expr.chars().peekable();

    while let Some(&ch) = it.peek() {
        // The match should have a case for each starting value of any valid token
        let token: Option<TokenType> = match ch {
            // Digit start
            '0'...'9' | '.' => Some(TokenType::Literal(parse_number(&mut it))),
            // Operators
            '+' => lex_advance_return!(it, TokenType::OpPlus),
            '-' => lex_advance_return!(it, TokenType::OpMinus),
            '*' => lex_advance_return!(it, TokenType::OpMultiply),
            '/' => lex_advance_return!(it, TokenType::OpDivide),
            '(' => lex_advance_return!(it, TokenType::OpOpenParen),
            ')' => lex_advance_return!(it, TokenType::OpCloseParen),
            '=' => lex_advance_return!(it, TokenType::OpEquals),
            '<' => lex_comparison_eq!(it, TokenType::OpLt, TokenType::OpLte),
            '>' => lex_comparison_eq!(it, TokenType::OpGt, TokenType::OpGte),
            // Interchangable single/double quoted strings grouped as single token.
            '"' | '\'' => Some(TokenType::Literal(parse_string(&mut it))),
            // Identifiers and reserved keywords
            'a'...'z' | 'A'...'Z' | '_' => {
                let tokenStr: String = parse_identifier(&mut it);
                Some(TokenType::Identifier(String::from(tokenStr) ))
                // TODO: Check if it's a reserved literal.
            },
            // Whitespace - ignore
            ' ' => {
                it.next();
                None
            }
            _ => {  // All other characters - TODO: error
                it.next();
                None
            }
        };
        // Add token to result if present
        match token {
            Some(t) => tokens.push(t),
            _ => {}
        };
    }
    return tokens;
}

// fn is_identifier_part(ch: char) -> bool {
//     // Any ascii character and can contain numbers within.
//     return is_identifier_start(ch) || is_digit(ch);
// }



// fn parse_literal(expr: &Vec<char>, start: usize) -> Option<LiteralNode> {
//     Option::None
// }


#[cfg(test)]
mod tests {
    // Note this useful idiom: importing names from outer (for mod tests) scope.
    use super::*;

    // #[test]
    // fn test_parse_int() {
    //     let expr: Vec<u8> = "42".().collect();
    //     let (v, i) = gobble_numeric_literal(&expr, 0);
    //     assert_eq!(v.value, LiteralValue::IntVal(42));
    // }

    // #[test]
    // fn test_parse_float() {
    //     let expr: Vec<char> = "27.9932".chars().collect();
    //     let (v, i) = gobble_numeric_literal(&expr, 0);
    //     assert_eq!(v.value, LiteralValue::FloatVal(27.9932));
    // }


    // #[test]
    // fn test_parse_exponential() {
    //     let expr: Vec<char> = "27.4e10".chars().collect();
    //     let (v, i) = gobble_numeric_literal(&expr, 0);
    //     assert_eq!(v.value, LiteralValue::FloatVal(27.4e10));
    // } 

    // #[test]
    // fn lex_float() {
    //     // Floating point numbers should be grouped together
    //     assert_eq!(lex("3.1415"), ["3.1415"]);
    //     assert_eq!(lex("9 .75 9"), ["9", ".75", "9"]);
    //     assert_eq!(lex("9 1e10"), ["9", "1e10"]);
    //     assert_eq!(lex("1e-10"), ["1e-10"]);
    //     assert_eq!(lex("123e+10"), ["123e+10"]);
    //     assert_eq!(lex("4.237e+101"), ["4.237e+101"]);

    //     assert_eq!(lex("-1"), ["-", "1"]);
    //     assert_eq!(lex("-.05"), ["-", ".05"]);
    //     assert_eq!(lex("5 -.05"), ["5", "-", ".05"]);

    //     // Unary minus is not combined with the number in the lexer
    //     // It's treated in the parser.
    //     assert_eq!(lex("5 + -.05"), ["5", "+", "-", ".05"]);
    // }


    // #[test]
    // fn factor_test() {
    //     assert_eq!(factor("3"), Ok(("", 3)));
    //     assert_eq!(factor(" 12"), Ok(("", 12)));
    //     assert_eq!(factor("537  "), Ok(("", 537)));
    //     assert_eq!(factor("  24   "), Ok(("", 24)));
    // }

    // #[test]
    // fn term_test() {
    // assert_eq!(term(" 12 *2 /  3"), Ok(("", 8)));
    // assert_eq!(
    //     term(" 2* 3  *2 *2 /  3"),
    //     Ok(("", 8))
    // );
    // assert_eq!(term(" 48 /  3/2"), Ok(("", 8)));
    // }

    // #[test]
    // fn expr_test() {
    // assert_eq!(expr(" 1 +  2 "), Ok(("", 3)));
    // assert_eq!(
    //     expr(" 12 + 6 - 4+  3"),
    //     Ok(("", 17))
    // );
    // assert_eq!(expr(" 1 + 2*3 + 4"), Ok(("", 11)));
    // }

    // #[test]
    // fn parens_test() {
    // assert_eq!(expr(" (  2 )"), Ok(("", 2)));
    // assert_eq!(
    //     expr(" 2* (  3 + 4 ) "),
    //     Ok(("", 14))
    // );
    // assert_eq!(
    //     expr("  2*2 / ( 5 - 1) + 3"),
    //     Ok(("", 4))
    // );
    // }


}