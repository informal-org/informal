extern crate nom;

use std::iter::Peekable;
use std::num::ParseIntError;
use std::str::FromStr;
use nom::{
  IResult,
  bytes::complete::{tag, take_while_m_n},
  combinator::map_res,
  sequence::tuple,
  character::is_space,
  character::is_alphanumeric,
  character::complete::{digit1 as digit, space0 as space},
  sequence::{delimited, pair},
  branch::alt,
  character::complete::char,
  multi::fold_many0,
};

#[derive(Debug,PartialEq)]
enum AbstractNodeType {
    Identifier,
    Literal,
    CallExpression,
    UnaryExpression,
    BinaryExpression
}

#[derive(Debug)]
struct LiteralNode {
    node_type: AbstractNodeType,
    value: LiteralValue,
    raw: String
}

#[derive(Debug)]
enum AbstractNode {
    Literal(LiteralNode)
}

#[derive(Debug,PartialEq)]
enum LiteralValue {
    BoolVal(bool), 
    FloatVal(f64),
    IntVal(i64),
    StrVal(String),
    NoneVal,
}

const PERIOD_CODE: char = '.';
const COMMA_CODE: char = ',';
const SQUOTE_CODE: char = '\'';
const DQUOTE_CODE: char = '"';
const OPAREN_CODE: char = '(';
const CPAREN_CODE: char = ')';
// const OBRACK_CODE: char = '[';
// const CBRACK_CODE: char = ']';
const QUMARK_CODE: char = '?';
const SEMCOL_CODE: char = ';';
const COLON_CODE: char = ':';

// These could both be sets, but honestly seems like array would be
// more performant here given how small it is. 
// Worth a micro-benchmark later. 
const UNARY_OPS: &[&str] = &["-", "NOT", "Not", "not"];

const BINARY_OPS: &[&str] =      &["^", "OR", "Or", "or", "AND", "And", "and", "IS", "Is", "is", "<", ">", "<=", ">=", "+", "-", "*", "/"];
const BINARY_PRECEDENCE: &[i8] = &[1,   1,    1,     1,   2,      2,    2,     6,    6,      6,  7,   7,   7,  7,    9,    9,   10,  10];

// This should be updated any time a longer token is added.
const MAX_UNARY_LEN: i8 = 3;
const MAX_BINARY_LEN: i8 = 3;

// This may be tricky since the result is of a mixed value type
const LITERAL: &[&str] = &["TRUE", "True", "true", "FALSE", "False", "false", "NONE", "None", "none"];
const LITERAL_VAL: &[LiteralValue] = &[LiteralValue::BoolVal(true), LiteralValue::BoolVal(true), LiteralValue::BoolVal(true), LiteralValue::BoolVal(false), LiteralValue::BoolVal(false), LiteralValue::BoolVal(false), LiteralValue::NoneVal, LiteralValue::NoneVal, LiteralValue::NoneVal];

fn throw_error(message: &str, index: i32) {
    // TODO: Throw an actual error, ey?
    println!("{} at character {}", message, index);
}

fn add_token(token: String, result: &mut Vec<String>){
    if !token.is_empty() {
        result.push(token.clone());
    }
}

fn is_digit(ch: char) -> bool {
    return ch >= '0' && ch <= '9';
}

fn is_alphabetic(ch: char) -> bool {
    return (ch >= 'a' && ch <= 'z') || (ch >= 'A' && ch <= 'Z');
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

// TODO: Return a lex struct to indicate whether this is
// a float
fn parse_number(it: &mut Peekable<std::str::Chars<'_>>) -> String {
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

            if let(Some(&exp_sign)) = it.peek() {
                if exp_sign == '+' || exp_sign == '-' {
                    token.push(exp_sign);
                    it.next();
                }
            }

            // Can't have a bare exponent without a value
            // Alternatively, treat this as e1
            if let(Some(&exp_digit)) = it.peek() {
                if !is_digit(exp_digit) {
                    // TODO: Error handling
                    println!("Invalid exponent.")
                }
            }
            gobble_digits(&mut token, it);
        }
    }

    return token;
}

pub fn lex(expr: &str) -> Vec<String> {
    // Split into lexems based on some known operators
    let mut tokens: Vec<String> = vec![];
    let mut it = expr.chars().peekable();

    while let Some(&ch) = it.peek() {
        // The match should have a case for each starting value of any valid token
        let mut token = String::from("");
        match ch {
            // TODO: -12.3
            // Digit start
            '0'...'9' | '.' => {
                token = parse_number(&mut it);
                add_token(token, &mut tokens);
            }
            // Identifier start
            'a'...'z' | 'A'...'Z' | '$' | '_' => {

                // Check if literal
                it.next();
            }
            // Whitespace - ignore
            ' ' => {
                add_token(token, &mut tokens);
                token = String::from("");
                it.next();
            }
            _ => {
                token.push(ch);
                add_token(token, &mut tokens);
                it.next();
            }
        }
    }

    return tokens;

}

fn is_identifier_start(ch: char) -> bool {
    return ch == '$' || ch == '_' || 
    (ch >= 'a' && ch <= 'z') ||
    (ch >= 'A' && ch <= 'Z');
    // Jsep also supports any non-ascii char that's not an operator
    // We'll exclude that since names are separate from IDs
}

fn is_identifier_part(ch: char) -> bool {
    // Any ascii character and can contain numbers within.
    return is_identifier_start(ch) || is_digit(ch);
}



fn parse_literal(expr: &Vec<char>, start: usize) -> Option<LiteralNode> {
    Option::None
}

// Split
// +,-,/,^,<=,>=,<,>

// fn gobble_token(expr: &Vec<char>, start: usize) -> (&str, usize) {
//     let mut index = gobble_spaces(expr, start);
//     let ch: char = expr[index];
//     if is_decimal_digit(ch) || ch == PERIOD_CODE {
//         // TODO
//         println!("{:?}",gobble_numeric_literal(expr, index))
//     }
//     return ("", start); // TODO
// }


// fn gobble_digits_helper(expr: &Vec<char>, start: usize) -> (Vec<char>, usize) {
//     let mut index = start;
//     let mut number: Vec<char> = vec![];
//     let length = expr.len();
//     if index >= length {
//         return (number, length);
//     }
//     let mut ch = expr[index];
//     while is_decimal_digit(ch) {
//         number.push(ch);
//         index+=1;
//         if index >= length {
//             return (number, length);
//         }
//         ch = expr[index];
//     }
//     return (number, index);
// }

// // Kind of a very special-case char at, because it will return
// // Empty space if you go out of range. Which differs from jsep, which 
// // can return empty string. Use carefully (i.e. only in comparison against other non space values)
// fn char_at_helper(expr: &Vec<char>, index: usize) -> char {
//     if index < expr.len() {
//         return expr[index];
//     }
//     return ' ';
// }

// fn gobble_numeric_literal(expr: &Vec<char>, start: usize) -> (LiteralNode, usize) {
//     let mut number: Vec<char> = vec![];
//     let mut index = start;
//     let length = expr.len();
//     let mut is_float: bool = false;
    
//     let (digit, i) = gobble_digits_helper(expr, index);
//     number.extend(digit);
//     index = i;
//     let mut ch = char_at_helper(expr, index);

//     if ch == '.' {
//         number.push(ch);
//         index += 1;
//         is_float = true;
//         let (digit, i) = gobble_digits_helper(expr, index);
//         number.extend(digit);
//         index = i;
//         ch = char_at_helper(expr, index);
//     }

//     if(ch == 'e' || ch == 'E') { // Exponent marker
//         number.push(ch);
//         index += 1;
//         is_float = true;
//         ch = char_at_helper(expr, index);
//         if(ch == '+' || ch == '-') { // Exponent sign
//             number.push(ch);
//             index += 1;
//         }
//         // Exponent
//         let (digit, i) = gobble_digits_helper(expr, index);
//         number.extend(digit);
//         index = i;
//         if(!is_decimal_digit(char_at_helper(expr, index-1))){
//             // TODO validate
//             // throw_error( &["Expected exponent (", number.iter().collect(), char_at_helper(expr, index), ")"].concat(), index)
//             let num: String = number.iter().collect();
//             println!("Expected exponent ({}{}) at {}", num, char_at_helper(expr, index), index);
//             // TODO - raise error in this case?
//         }
//     }

//     let num: String = number.iter().collect();
//     ch = char_at_helper(expr, index);
//     if(is_identifier_start(ch)){
//         println!("Variable names cannot start with a number ({}{}) at {}", num, ch, index)
//     } else if(ch == PERIOD_CODE) {
//         println!("Unexpected period at {}", index)
//     }

//     let value: LiteralValue;

//     if is_float {
//         let v: f64 = num.parse().unwrap();
//         value = LiteralValue::FloatVal(v);
//     } else {
//         let v: i64 = num.parse().unwrap();
//         value = LiteralValue::IntVal(v);
//     }

//     let node: LiteralNode = LiteralNode { 
//         node_type: AbstractNodeType::Literal, 
//         value: value, 
//         raw: num
//     };

//     return (node, index); // TODO
// }

// pub fn parse(expr: &str) {
//     let mut index = 0;
//     // Char-at isn't constant time due to utf, so do an upfront conversion
//     let expr_vector: Vec<char> = expr.chars().collect();
//     let index = gobble_spaces(&expr_vector, 0);
//     println!("Result index {}", index);
//     gobble_token(&expr_vector, index);
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

    #[test]
    fn lex_float() {
        // Floating point numbers should be grouped together
        assert_eq!(lex("3.1415"), ["3.1415"]);
        assert_eq!(lex("9 .75 9"), ["9", ".75", "9"]);
        assert_eq!(lex("9 1e10"), ["9", "1e10"]);
        assert_eq!(lex("1e-10"), ["1e-10"]);
        assert_eq!(lex("123e+10"), ["123e+10"]);
        assert_eq!(lex("4.237e+101"), ["4.237e+101"]);
    }


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