// Float parsing
extern crate lexical;

use super::{Result};
use std::iter::Peekable;

use avs::constants::*;
use avs::structs::Atom;
use avs::runtime::SYMBOL_ID_MAP;
use avs::environment::Environment;


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

fn parse_number(it: &mut Peekable<std::str::Chars<'_>>, is_negative: bool) -> Result<Atom> {
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
                    return Err(PARSE_ERR_INVALID_FLOAT);
                }
            } else { // Premature end of string
                return Err(PARSE_ERR_INVALID_FLOAT);
            }
            gobble_digits(&mut token, it);
        }
    }
    // Parse should be sufficient since we've validated format already.
    
    let mut val: f64 = lexical::parse(token);
    if is_negative {
        val = -1.0 * val;
    }
    return Ok(Atom::NumericValue(val));
}

fn parse_string(it: &mut Peekable<std::str::Chars<'_>>) -> Result<Atom> {
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
                        //'0' => token.push('\0'),
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
    // Invalid if you reach end of input before a matching closing quotes (of the same type)
    if ! _terminated {
        return Err(PARSE_ERR_UNTERM_STR);
    }
    return Ok(Atom::StringValue(token));
}

fn is_delimiter(ch: char) -> bool {
    // Delimiters for splitting tokens
    match ch {
        '(' | ')' | '[' | ']' | '{' | '}' | '"' | '\'' | 
        '.' | ',' | ':' | ';' |
        '-' | '+' | '*' | '/' | '%' |
        ' ' | '\t' | '\n' => true,
        _ => false
    }
}

fn parse_identifier(it: &mut Peekable<std::str::Chars<'_>>) -> String {
    let mut token = String::from("");
    // Assert - the caller checks if the first char is not a number
    
    // Unlike symbol names, identifiers may begin with : as first character for keywords.
    if let Some(&ch) = it.peek() {
        if ch == ':' {
            token.push(ch);
            it.next();
        } else if is_delimiter(ch) {
            // Delimiter by itself are valid tokens
            token.push(ch);
            it.next();
            return token;
        }
    }

    while let Some(&ch) = it.peek() {
            // Break on delimiters, gobble otherwise
        if is_delimiter(ch) {
            break;
        } else {
            token.push(ch);
            it.next(); 
        }
    }
    return token;
}

fn reserved_keyword(token: &str) -> Option<Atom> {
    // Returns the token type if the token matches a reserved keyword.
    let token_upcase: &str = &token.to_ascii_uppercase();
    if let Some(&symbol_id) = SYMBOL_ID_MAP.get(token_upcase) {
        return Some(Atom::SymbolValue(symbol_id.symbol))
    }
    
    return None
}

macro_rules! apply_unary_minus {
    ($it:expr, $tokens:expr) => ({
        if let Some(next) = $it.peek() {
            match next {
                '(' => {
                    // Rewrite A + -(.. => A + -1 * (
                    $tokens.push(Atom::NumericValue( -1.0 ));
                    Some(Atom::SymbolValue(SYMBOL_MULTIPLY.symbol))
                },
                _ => {
                    Some(parse_number(&mut $it, true)?)
                }
            }
        } else {
            // Unexpected end of string - Return from outer lex function
            return Err(PARSE_ERR_UNEXPECTED_TOKEN);
        }
    });
}

pub fn lex(context: &mut Environment, expr: &str) -> Result<Vec<Atom>> {
    let mut it = expr.chars().peekable();
    // Split into lexemes based on some known operators
    let mut tokens: Vec<Atom> = vec![];

    while let Some(&ch) = it.peek() {
        // The match should have a case for each starting value of any valid token
        let token: Option<Atom> = match ch {
            // Whitespace - ignore
            ' ' | '\t' | '\n' => {
                it.next();
                None
            },
            // Digit start
            '0'..='9' | '.' => Some(parse_number(&mut it, false)? ),
            // Special case for minus sign to differentiate subtraction or unary minus
            '-' => {
                // If the previous char was beginning of string or another operator
                if let Some(prev) = tokens.last() {
                    match prev {
                        Atom::SymbolValue(_kw) => {
                             it.next();
                             apply_unary_minus!(it, tokens)
                        },
                        _ => {
                            it.next();
                            Some(Atom::SymbolValue(SYMBOL_MINUS.symbol))
                        }
                    }
                } else {
                    // Beginning of string = unary minus
                    it.next();
                    apply_unary_minus!(it, tokens)
                }
            },
            // Interchangeable single/double quoted strings grouped as single token.
            '"' | '\'' => Some(parse_string(&mut it)?),
            _ => {
                // Symbols and reserved symbols
                let token_str: String = parse_identifier(&mut it);
                let keyword = reserved_keyword(&token_str);
                if keyword.is_some() {
                    // Currently disallow operator overloading and changing built-in keywords
                    keyword
                } else {
                    if let Some(symbol_id) = context.lookup_by_name(token_str) {
                        Some(Atom::SymbolValue( *symbol_id ))
                    } else {
                        return Err(PARSE_ERR_UNK_SYMBOL);
                    }
                }
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
    use super::*;

    #[macro_export]
    macro_rules! numeric_literal {
        ($val:expr) => ({
        Atom::NumericValue($val)
        });
    }

    // #[test]
    // fn test_lex_float() {
    //     let mut context = Context::new(APP_SYMBOL_START);
    //     // Floating point numbers should be grouped together
    //     assert_eq!(lex(&mut context, "3.1415").unwrap(), [numeric_literal!(3.1415)]);

    //     // Note: Numeric literals converted to float in lexer. Handled separately in parser.
    //     assert_eq!(lex(&mut context, "9 .75 9").unwrap(), [numeric_literal!(9.0), numeric_literal!(0.75), numeric_literal!(9.0)]);
    //     assert_eq!(lex(&mut context, "9 1e10").unwrap(), [numeric_literal!(9.0), numeric_literal!(1e10)]);
    //     assert_eq!(lex(&mut context, "1e-10").unwrap(), [numeric_literal!(1e-10)]);
    //     assert_eq!(lex(&mut context, "123e+10").unwrap(), [numeric_literal!(123e+10)]);
    //     assert_eq!(lex(&mut context, "4.237e+101").unwrap(), [numeric_literal!(4.237e+101)]);

    //     // Error on undefined exponents.
    //     assert_eq!(lex(&mut context, "5.1e").unwrap_err(), PARSE_ERR_INVALID_FLOAT);
    //     assert_eq!(lex(&mut context, "5.1e ").unwrap_err(), PARSE_ERR_INVALID_FLOAT);
    //     // 30_000_000 syntax support? Stick to standard valid floats for now.
    // }

    // #[test]
    // fn test_lex_unary_minus() {
    //     let mut context = Context::new(APP_SYMBOL_START);
    //     // Unary minus is handled at the lexer stage.
    //     assert_eq!(lex(&mut context, "-1").unwrap(), [numeric_literal!(-1.0)]);
    //     assert_eq!(lex(&mut context, "-.05").unwrap(), [numeric_literal!(-0.05)]);
    //     assert_eq!(lex(&mut context, "5 -.05").unwrap(), [numeric_literal!(5.0), Atom::SymbolValue(SYMBOL_MINUS.symbol), numeric_literal!(0.05)]);
    //     assert_eq!(lex(&mut context, "5 + -2").unwrap(), [numeric_literal!(5.0), Atom::SymbolValue(SYMBOL_PLUS.symbol), numeric_literal!(-2.0)]);

    //     assert_eq!(lex(&mut context, "5 + -.05").unwrap(), [numeric_literal!(5.0), Atom::SymbolValue(SYMBOL_PLUS.symbol), numeric_literal!(-0.05)]);
    //     assert_eq!(lex(&mut context, "-(4) + 2").unwrap(), [numeric_literal!(-1.0), Atom::SymbolValue(SYMBOL_MULTIPLY.symbol), Atom::SymbolValue(SYMBOL_OPEN_PAREN.symbol), 
    //      numeric_literal!(4.0), Atom::SymbolValue(SYMBOL_CLOSE_PAREN.symbol), Atom::SymbolValue(SYMBOL_PLUS.symbol), numeric_literal!(2.0)] );
    //     assert_eq!(lex(&mut context, "5 * -(2)").unwrap(), [numeric_literal!(5.0), Atom::SymbolValue(SYMBOL_MULTIPLY.symbol), numeric_literal!(-1.0), 
    //         Atom::SymbolValue(SYMBOL_MULTIPLY.symbol), Atom::SymbolValue(SYMBOL_OPEN_PAREN.symbol), numeric_literal!(2.0), Atom::SymbolValue(SYMBOL_CLOSE_PAREN.symbol) ]);
    // }

    // #[test]
    // fn test_reserved_keyword() {
    //     assert_eq!(reserved_keyword("not"), Some(Atom::SymbolValue(SYMBOL_NOT.symbol)));
    //     assert_eq!(reserved_keyword("And"), Some(Atom::SymbolValue(SYMBOL_AND.symbol)));
    //     assert_eq!(reserved_keyword("NONE"), Some(Atom::SymbolValue(SYMBOL_NONE.symbol)));
    //     assert_eq!(reserved_keyword("True"), Some(Atom::SymbolValue(SYMBOL_TRUE.symbol)));
    //     assert_eq!(reserved_keyword("TRUE"), Some(Atom::SymbolValue(SYMBOL_TRUE.symbol)));
    //     assert_eq!(reserved_keyword("false"), Some(Atom::SymbolValue(SYMBOL_FALSE.symbol)));
    //     assert_eq!(reserved_keyword("unreserved"), None);
    // }

    // #[test]
    // fn test_lex_string() {
    //     assert_eq!(parse_string(&mut r#""hello world""#.chars().peekable()).unwrap(), Atom::StringValue(String::from("hello world")) );
    //     // Terminates at end of quote
    //     assert_eq!(parse_string(&mut r#""hello world" test"#.chars().peekable()).unwrap(), Atom::StringValue(String::from("hello world")) );
    //     // Matches quotes
    //     assert_eq!(parse_string(&mut r#"'hello " world' test"#.chars().peekable()).unwrap(), Atom::StringValue(String::from("hello \" world")) );
    //     // Error on unterminated string
    //     assert_eq!(parse_string(&mut r#"'hello"#.chars().peekable()).unwrap_err(), PARSE_ERR_UNTERM_STR);
    // }


    // #[test]
    // fn test_lex_identifiers() {
    //     // TODO - better test case
    //     // assert_eq!(lex(&mut context, "@1").unwrap(), [Atom::SymbolValue(_)]);
    // }



}