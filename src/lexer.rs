extern crate lexical;

use super::error::{ArevelError, Result};
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
pub enum LiteralValue {
    NoneValue,
    BooleanValue(bool), 
    NumericValue(f64),    // Integers are represented within the floats.
    StringValue(String),  // TODO: String -> Obj. To c-string.
}

pub const TRUE_VALUE: LiteralValue = LiteralValue::BooleanValue(true);
pub const FALSE_VALUE: LiteralValue = LiteralValue::BooleanValue(false);
pub const NONE_VALUE: LiteralValue = LiteralValue::NoneValue;

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

fn parse_number(it: &mut Peekable<std::str::Chars<'_>>) -> Result<LiteralValue> {
    let mut token = String::from("");
    let mut _is_float = false;       // Unused. Could be used for dedicated int type later.

    // Leading decimal digits
    gobble_digits(&mut token, it);

    // (Optional) decimal
    if let Some(&decimal) = it.peek() {
        if decimal == '.' {
            _is_float = true;
            token.push(decimal);
            it.next();

            // (Optional) decimal digits
            gobble_digits(&mut token, it);
        }
    }

    // (Optional) Exponent
    if let Some(&exp) = it.peek() {
        if exp == 'e' || exp == 'E' {
            _is_float = true;
            token.push(exp);
            it.next();

            if let Some(&exp_sign) = it.peek() {
                if exp_sign == '+' || exp_sign == '-' {
                    token.push(exp_sign);
                    it.next();
                }
            }

            // Can't have a bare exponent without a value
            if let Some(&exp_digit) = it.peek() {
                if !is_digit(exp_digit) {
                    // TODO: Error handling
                    return Err(ArevelError::InvalidFloatFmt);
                }
            } else { // Premature end of string
                return Err(ArevelError::InvalidFloatFmt);
            }
            gobble_digits(&mut token, it);
        }
    }
    // Parse should be sufficient since we've validated format already.
    let val: f64 = lexical::parse(token);
    return Ok(LiteralValue::NumericValue(val));
}

fn parse_string(it: &mut Peekable<std::str::Chars<'_>>) -> Result<LiteralValue> {
    let mut token = String::from("");
    
    // Don't include the quotes in the resulting string.
    // Starting quote is always present for this function to be called.
    let quote_start = it.next().unwrap();
    let mut _terminated: bool = false;

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
                _terminated = true;
                break;
            }
            _ => {
                token.push(ch);
                it.next();
            }
        }
    }
    // Invalid if you reach end of input before closing quotes.
    if ! _terminated {
        return Err(ArevelError::UnterminatedString);
    }
    return Ok(LiteralValue::StringValue(token));
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

fn reserved_keyword(token: &str) -> Option<TokenType> {
    // Returns the token type if the token matches a reserved keyword.
    let token_upcase: &str = &token.to_ascii_uppercase();
    return match token_upcase {
        "IS" => Some(TokenType::OpIs),
        "NONE" => Some(TokenType::Literal(NONE_VALUE)),
        "TRUE" => Some(TokenType::Literal(TRUE_VALUE)),
        "FALSE" => Some(TokenType::Literal(FALSE_VALUE)),
        "NOT" => Some(TokenType::OpNot),
        "AND" => Some(TokenType::OpAnd),
        "OR" => Some(TokenType::OpOr),
        _ => None
    }
}

// One-liner shorthand to advance the iterator and return the given value
macro_rules! lex_advance_return {
    ($it:expr, $e:expr) => ({
        $it.next();
        Some($e)
    });
};

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
};

macro_rules! numeric_literal {
     ($val:expr) => ({
       TokenType::Literal(LiteralValue::NumericValue($val))
    });
};

pub fn lex(expr: &str) -> Result<Vec<TokenType>> {
    // Split into lexems based on some known operators
    let mut tokens: Vec<TokenType> = vec![];
    let mut it = expr.chars().peekable();

    while let Some(&ch) = it.peek() {
        // The match should have a case for each starting value of any valid token
        let token: Option<TokenType> = match ch {
            // Digit start
            '0'...'9' | '.' => Some(TokenType::Literal(parse_number(&mut it)? )),
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
            '"' | '\'' => Some(TokenType::Literal(parse_string(&mut it)?)),
            // Identifiers and reserved keywords
            'a'...'z' | 'A'...'Z' | '_' => {
                let token_str: String = parse_identifier(&mut it);
                let keyword = reserved_keyword(&token_str);
                if keyword != None { 
                    keyword
                }
                else {
                    Some(TokenType::Identifier(String::from(token_str) ))
                }
            },
            // Whitespace - ignore
            ' ' => {
                it.next();
                None
            }
            _ => {
                // Error out on any unrecognized token starts.
                it.next();
                return Err(ArevelError::UnknownToken);
            }
        };
        // Add token to result if present
        match token {
            Some(t) => tokens.push(t),
            _ => {}
        };
    }
    return Ok(tokens);
}

#[cfg(test)]
mod tests {
    // Note this useful idiom: importing names from outer (for mod tests) scope.
    use super::*;

    #[test]
    fn test_lex_float() {
        // Floating point numbers should be grouped together
        assert_eq!(lex("3.1415").unwrap(), [numeric_literal!(3.1415)]);

        // Note: Numeric literals converted to float in lexer. Handled separately in parser.
        assert_eq!(lex("9 .75 9").unwrap(), [numeric_literal!(9.0), numeric_literal!(0.75), numeric_literal!(9.0)]);
        assert_eq!(lex("9 1e10").unwrap(), [numeric_literal!(9.0), numeric_literal!(1e10)]);
        assert_eq!(lex("1e-10").unwrap(), [numeric_literal!(1e-10)]);
        assert_eq!(lex("123e+10").unwrap(), [numeric_literal!(123e+10)]);
        assert_eq!(lex("4.237e+101").unwrap(), [numeric_literal!(4.237e+101)]);

        // Unary minus is kept separate in lexer stage and evaluated in parser.
        assert_eq!(lex("-1").unwrap(), [TokenType::OpMinus, numeric_literal!(1.0)]);
        assert_eq!(lex("-.05").unwrap(), [TokenType::OpMinus, numeric_literal!(0.05)]);
        assert_eq!(lex("5 -.05").unwrap(), [numeric_literal!(5.0), TokenType::OpMinus, numeric_literal!(0.05)]);
        assert_eq!(lex("5 + -.05").unwrap(), [numeric_literal!(5.0), TokenType::OpPlus, TokenType::OpMinus, numeric_literal!(0.05)]);

        // Error on undefined exponents.
        assert_eq!(lex("5.1e").unwrap_err(), ArevelError::InvalidFloatFmt);
        assert_eq!(lex("5.1e ").unwrap_err(), ArevelError::InvalidFloatFmt);
        // 30_000_000 syntax support? Stick to standard valid floats for now.
    }

    #[test]
    fn test_reserved_keyword() {
        assert_eq!(reserved_keyword("not"), Some(TokenType::OpNot));
        assert_eq!(reserved_keyword("And"), Some(TokenType::OpAnd));
        assert_eq!(reserved_keyword("NONE"), Some(TokenType::Literal(LiteralValue::NoneValue)));
        assert_eq!(reserved_keyword("True"), Some(TokenType::Literal(TRUE_VALUE)));
        assert_eq!(reserved_keyword("TRUE"), Some(TokenType::Literal(TRUE_VALUE)));
        assert_eq!(reserved_keyword("false"), Some(TokenType::Literal(FALSE_VALUE)));
        assert_eq!(reserved_keyword("unreserved"), None);
    }

    #[test]
    fn test_lex_string() {
        assert_eq!(parse_string(&mut r#""hello world""#.chars().peekable()).unwrap(), LiteralValue::StringValue(String::from("hello world")) );
        // Terminates at end of quote
        assert_eq!(parse_string(&mut r#""hello world" test"#.chars().peekable()).unwrap(), LiteralValue::StringValue(String::from("hello world")) );
        // Matches quotes
        assert_eq!(parse_string(&mut r#"'hello " world' test"#.chars().peekable()).unwrap(), LiteralValue::StringValue(String::from("hello \" world")) );
        // Error on unterminated string
        assert_eq!(parse_string(&mut r#"'hello"#.chars().peekable()).unwrap_err(), ArevelError::UnterminatedString);
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