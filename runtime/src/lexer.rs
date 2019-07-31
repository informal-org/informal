// Float parsing
extern crate lexical;

use super::{Result};
use std::iter::Peekable;

use avs::constants::*;
use avs::structs::Atom;
use avs::utils::create_value_symbol;
use avs::runtime::SYMBOL_ID_MAP;
use crate::structs::Context;


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
    // Invalid if you reach end of input before closing quotes.
    if ! _terminated {
        return Err(PARSE_ERR_UNTERM_STR);
    }
    return Ok(Atom::StringValue(token));
}

fn parse_identifier(it: &mut Peekable<std::str::Chars<'_>>) -> String {
    let mut token = String::from("");
    // Assert - the caller checks if the first char is not a number
    while let Some(&ch) = it.peek() {
        match ch {
            // IDs are separate from names, so the character set could be more restrictive.
            'a'..='z' | 'A'..='Z' | '_' | '0'..='9' => {
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

fn reserved_keyword(token: &str) -> Option<Atom> {
    // Returns the token type if the token matches a reserved keyword.
    let token_upcase: &str = &token.to_ascii_uppercase();
    if let Some(&symbol_id) = SYMBOL_ID_MAP.get(token_upcase) {
        return Some(Atom::SymbolValue(symbol_id))
    }
    
    return None

    // return match token_upcase {
    //     "IS" => Some(TOKEN_IS),
    //     "NONE" => Some(TOKEN_NONE),
    //     "TRUE" => Some(TOKEN_TRUE),
    //     "FALSE" => Some(TOKEN_FALSE),
    //     "NOT" => Some(TOKEN_NOT),
    //     "AND" => Some(TOKEN_AND),
    //     "OR" => Some(TOKEN_OR),
    //     _ => None
    // }
}

// One-liner shorthand to advance the iterator and return the given value
macro_rules! lex_advance_return {
    ($it:expr, $e:expr) => ({
        $it.next();
        Some(Atom::SymbolValue($e))
    });
}

// Shortcut for lte and gte - check next token and decide which form it is.
macro_rules! lex_comparison_eq {
    ($it:expr, $comp:expr, $comp_eq:expr) => ({
        $it.next();
        if let Some(&eq) = $it.peek() {
            if eq == '=' {
                $it.next();
                Some(Atom::SymbolValue($comp_eq))
            } else {
                Some(Atom::SymbolValue($comp))
            }
        } else {
            Some(Atom::SymbolValue($comp))
        }
    });
}

#[macro_export]
macro_rules! numeric_literal {
     ($val:expr) => ({
       Atom::NumericValue($val)
    });
}

macro_rules! apply_unary_minus {
    ($it:expr, $tokens:expr) => ({
        if let Some(next) = $it.peek() {
            match next {
                '(' => {
                    // Rewrite A + -(.. => A + -1 * (
                    $tokens.push(Atom::NumericValue( -1.0 ));
                    Some(Atom::SymbolValue(SYMBOL_MULTIPLY))
                },
                _ => {
                    Some(parse_number(&mut $it, true)?)
                }
            }
        } else {
            // Unexpected end of string
            return Err(PARSE_ERR_UNEXPECTED_TOKEN);
        }
    });
}

pub fn lex(context: &mut Context, expr: &str) -> Result<Vec<Atom>> {
    // Split into lexems based on some known operators
    let mut tokens: Vec<Atom> = vec![];
    let mut it = expr.chars().peekable();

    while let Some(&ch) = it.peek() {
        // The match should have a case for each starting value of any valid token
        let token: Option<Atom> = match ch {
            // Digit start
            '0'..='9' | '.' => Some(parse_number(&mut it, false)? ),
            // Differentiate subtraction or unary minus
            '-' => {
                // If the previous char was begining of string or another operator
                if let Some(prev) = tokens.last() {
                    match prev {
                        // TODO: Re-verify support for unary minus 
                        // TokenType::Keyword(_kw) => {
                        Atom::SymbolValue(_kw) => {
                             it.next();
                             apply_unary_minus!(it, tokens)
                        },
                        _ => {
                            lex_advance_return!(it, SYMBOL_MINUS)
                        }
                    }
                } else {
                    // Beginning of string = unary minus
                    it.next();
                    apply_unary_minus!(it, tokens)
                }
            },
            // Operators
            '+' => lex_advance_return!(it, SYMBOL_PLUS),
            '*' => lex_advance_return!(it, SYMBOL_MULTIPLY),
            '/' => lex_advance_return!(it, SYMBOL_DIVIDE),
            '(' => lex_advance_return!(it, SYMBOL_OPEN_PAREN),
            ')' => lex_advance_return!(it, SYMBOL_CLOSE_PAREN),
            '=' => lex_advance_return!(it, SYMBOL_EQUALS),
            '<' => lex_comparison_eq!(it, SYMBOL_LT, SYMBOL_LTE),
            '>' => lex_comparison_eq!(it, SYMBOL_GT, SYMBOL_GTE),
            // Interchangable single/double quoted strings grouped as single token.
            '"' | '\'' => Some(parse_string(&mut it)?),
            // Identifiers and reserved keywords
            // TODO: Benchmark if a..z vs looking at char code range.
            'a'..='z' | 'A'..='Z' | '_' => {
                let token_str: String = parse_identifier(&mut it);
                let keyword = reserved_keyword(&token_str);
                if keyword != None { 
                    keyword
                } else {
                    // TODO more specific error
                    return Err(PARSE_ERR_UNKNOWN_TOKEN);
                }
            }
            '@' => {
                let mut token_str: String = String::from("");
                it.next();
                gobble_digits(&mut token_str, &mut it);
                // TODO: Better panic handling
                if let Some(id) = token_str.parse::<u64>().ok() {
                    // TODO: Map the IDs to something else so we don't re-use IDs
                    Some(Atom::SymbolValue( context.get_or_create_cell_symbol(id) ))
                    
                } else {
                    // TODO: Invalid identifier
                    return Err(PARSE_ERR_UNKNOWN_TOKEN);
                }
            },
            // Whitespace - ignore
            ' ' | '\t' | '\n' => {
                it.next();
                None
            }
            _ => {
                // Error out on any unrecognized token starts.
                it.next();
                return Err(PARSE_ERR_UNKNOWN_TOKEN);
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

    #[test]
    fn test_lex_float() {
        let mut context = Context::new(65000);
        // Floating point numbers should be grouped together
        assert_eq!(lex(&mut context, "3.1415").unwrap(), [numeric_literal!(3.1415)]);

        // Note: Numeric literals converted to float in lexer. Handled separately in parser.
        assert_eq!(lex(&mut context, "9 .75 9").unwrap(), [numeric_literal!(9.0), numeric_literal!(0.75), numeric_literal!(9.0)]);
        assert_eq!(lex(&mut context, "9 1e10").unwrap(), [numeric_literal!(9.0), numeric_literal!(1e10)]);
        assert_eq!(lex(&mut context, "1e-10").unwrap(), [numeric_literal!(1e-10)]);
        assert_eq!(lex(&mut context, "123e+10").unwrap(), [numeric_literal!(123e+10)]);
        assert_eq!(lex(&mut context, "4.237e+101").unwrap(), [numeric_literal!(4.237e+101)]);

        // Error on undefined exponents.
        assert_eq!(lex(&mut context, "5.1e").unwrap_err(), PARSE_ERR_INVALID_FLOAT);
        assert_eq!(lex(&mut context, "5.1e ").unwrap_err(), PARSE_ERR_INVALID_FLOAT);
        // 30_000_000 syntax support? Stick to standard valid floats for now.
    }

    #[test]
    fn test_lex_unary_minus() {
        let mut context = Context::new(65000);
        // Unary minus is handled at the lexer stage.
        assert_eq!(lex(&mut context, "-1").unwrap(), [numeric_literal!(-1.0)]);
        assert_eq!(lex(&mut context, "-.05").unwrap(), [numeric_literal!(-0.05)]);
        assert_eq!(lex(&mut context, "5 -.05").unwrap(), [numeric_literal!(5.0), Atom::SymbolValue(SYMBOL_MINUS), numeric_literal!(0.05)]);
        assert_eq!(lex(&mut context, "5 + -.05").unwrap(), [numeric_literal!(5.0), Atom::SymbolValue(SYMBOL_PLUS), numeric_literal!(-0.05)]);
        assert_eq!(lex(&mut context, "-(4) + 2").unwrap(), [numeric_literal!(-1.0), Atom::SymbolValue(SYMBOL_MULTIPLY), Atom::SymbolValue(SYMBOL_OPEN_PAREN), 
         numeric_literal!(4.0), Atom::SymbolValue(SYMBOL_CLOSE_PAREN), Atom::SymbolValue(SYMBOL_PLUS), numeric_literal!(2.0)] );
        assert_eq!(lex(&mut context, "5 * -(2)").unwrap(), [numeric_literal!(5.0), Atom::SymbolValue(SYMBOL_MULTIPLY), numeric_literal!(-1.0), 
            Atom::SymbolValue(SYMBOL_MULTIPLY), Atom::SymbolValue(SYMBOL_OPEN_PAREN), numeric_literal!(2.0), Atom::SymbolValue(SYMBOL_CLOSE_PAREN) ]);
    }

    #[test]
    fn test_reserved_keyword() {
        assert_eq!(reserved_keyword("not"), Some(Atom::SymbolValue(SYMBOL_NOT)));
        assert_eq!(reserved_keyword("And"), Some(Atom::SymbolValue(SYMBOL_AND)));
        assert_eq!(reserved_keyword("NONE"), Some(Atom::SymbolValue(SYMBOL_NONE)));
        assert_eq!(reserved_keyword("True"), Some(Atom::SymbolValue(SYMBOL_TRUE)));
        assert_eq!(reserved_keyword("TRUE"), Some(Atom::SymbolValue(SYMBOL_TRUE)));
        assert_eq!(reserved_keyword("false"), Some(Atom::SymbolValue(SYMBOL_FALSE)));
        assert_eq!(reserved_keyword("unreserved"), None);
    }

    #[test]
    fn test_lex_string() {
        assert_eq!(parse_string(&mut r#""hello world""#.chars().peekable()).unwrap(), Atom::StringValue(String::from("hello world")) );
        // Terminates at end of quote
        assert_eq!(parse_string(&mut r#""hello world" test"#.chars().peekable()).unwrap(), Atom::StringValue(String::from("hello world")) );
        // Matches quotes
        assert_eq!(parse_string(&mut r#"'hello " world' test"#.chars().peekable()).unwrap(), Atom::StringValue(String::from("hello \" world")) );
        // Error on unterminated string
        assert_eq!(parse_string(&mut r#"'hello"#.chars().peekable()).unwrap_err(), PARSE_ERR_UNTERM_STR);
    }


    #[test]
    fn test_lex_identifiers() {
        // TODO - better test case
        // assert_eq!(lex(&mut context, "@1").unwrap(), [Atom::SymbolValue(_)]);
    }



}