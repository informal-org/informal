use super::error::{Result, ArevelError};
#[macro_use]
use super::lexer::*;

// Higher numbers have higher precedence. 
// Indexes should match with TokenType enum values.
const KEYWORD_PRECEDENCE: &[u8] = &[
    1, 2,       // and/or
    5,          // is (==)
    6,          // not
    7, 7, 7, 7, // Comparison
    9, 9,       // Add/subtract
    10, 10,     // Multiply, divide
    11, 11,     // Parens
    0           // Equals
];

pub const WASM_FBIN_ADD: &'static str  = "(f64.add)\n";
pub const WASM_FBIN_SUB: &'static str  = "(f64.sub)\n";
pub const WASM_FBIN_MUL: &'static str  = "(f64.mul)\n";
pub const WASM_FBIN_DIV: &'static str  = "(f64.div)\n";

// alternatively. Do .nearest first
pub const WASM_F64_AS_I32: &'static str  = "(i32.trunc_s/f64)\n";

fn get_op_precedence(keyword: KeywordType) -> u8 {
    let index = keyword as usize;
    return KEYWORD_PRECEDENCE[index];
}


// TODO: There may be additional edge cases for handling inline function calls within the expression
// Current assumption is that all variable references are to a value.
pub fn parse(infix: &mut Vec<TokenType>) -> Result<Vec<TokenType>> {
    // Parse the lexed infix input and construct a postfix version
    // Current implementation uses the shunting yard algorithm for operator precedence.
    let mut postfix: Vec<TokenType> = Vec::with_capacity(infix.len());
    let mut operator_stack: Vec<TokenType> = Vec::with_capacity(infix.len());

    for token in infix.drain(..) {
        match &token {
            TokenType::Keyword(kw) => {
                match kw {
                    KeywordType::KwOpenParen => operator_stack.push(token),
                    KeywordType::KwCloseParen => {
                        // Pop until you find the matching opening paren
                        let mut found = false;
                        while let Some(op) = operator_stack.pop() {
                            // Sholud always be true since the operator stack only contains keywords
                            if let TokenType::Keyword(op_kw) = &op {
                                match op_kw {
                                    KeywordType::KwOpenParen => {
                                        found = true;
                                        break;
                                    }
                                    _ => postfix.push(op)
                                }
                            }
                        }
                        if found == false {
                            return Err(ArevelError::UnmatchedParens)
                        }
                    },
                    _ => {
                        // For all other operators, flush higher or equal level operators
                        // All operators are left associative in our system right now. (else, equals doesn't get pushed)
                        let my_precedence = get_op_precedence(*kw);
                        while operator_stack.len() > 0 {
                            let op_peek_last = operator_stack.get(operator_stack.len() - 1);
                            if let Some(TokenType::Keyword(op_kw)) = op_peek_last {
                                // Skip any items that aren't really operators.
                                if *op_kw == KeywordType::KwOpenParen {
                                    break;
                                }

                                let other_precedence = get_op_precedence(*op_kw);
                                if other_precedence >= my_precedence {        // output any higher priority operators.
                                    postfix.push(operator_stack.pop().unwrap());
                                } else {
                                    break;
                                }
                            }
                        }
                        // Flushed all operators with higher precedence. Add to op stack.
                        operator_stack.push(token);
                    }
                }

            },
            TokenType::Literal(_lit) => postfix.push(token),
            TokenType::Identifier(_id) => postfix.push(token),
        }
    }

    // Flush all remaining operators onto the postfix output. 
    // Reverse so we get items in the stack order.
    operator_stack.reverse();
    for token in operator_stack.drain(..) {
        println!("Token drain");
        // All of them should be keywords
        if let TokenType::Keyword(op_kw) = &token {
            match op_kw {
                KeywordType::KwOpenParen => {
                    println!("Invalid paren in drain operator stack");
                    return Err(ArevelError::UnmatchedParens)
                }
                _ => {}
            }
        }
        postfix.push(token);
    }

    return Ok(postfix);
}



pub fn expr_to_wat(postfix: Vec<TokenType>) -> String {
    let header = String::from(r#"
(module
  (type $t0 (func (result f64)))
  (func $main (type $t0) (result f64)
  "#);

    let mut body: Vec<String> = vec![];

    for token in postfix {
        match &token {
            TokenType::Keyword(kw) => {
                let wasm_op = match kw {
                    // TODO: Predefine constants for these;
                    KeywordType::KwPlus => WASM_FBIN_ADD,
                    KeywordType::KwMinus => WASM_FBIN_SUB,
                    KeywordType::KwMultiply => WASM_FBIN_MUL,
                    KeywordType::KwDivide => WASM_FBIN_DIV,
                    _ => {""}
                };
                body.push(String::from(wasm_op));
            }
            TokenType::Literal(lit) => {
                // TODO: Push the literal value
                match &lit {
                    LiteralValue::NumericValue(num) => {
                        let lit_def = ["(f64.const ", &num.to_string(), ")"].concat();
                        body.push( lit_def );
                    }
                    _ => {} // TODO
                }
                
            },
            _ => {}
            // TODO
            // TokenType::Identifier(_id) => postfix.push(token),
        }
    }

    let footer = String::from(r#")
  (table $T0 1 anyfunc)
  (memory $memory 0)
  (export "memory" (memory 0))
  (export "main" (func $main))
  )"#);

  return header + (&body.join("")) + &footer;
    
}


#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_parse_basic() {
        // Verify straightforward conversion to postfix
        let mut input: Vec<TokenType> = vec![TokenType::Literal(LiteralValue::NumericValue(1.0)), TOKEN_PLUS, TokenType::Literal(LiteralValue::NumericValue(2.0))];
        let output: Vec<TokenType> = vec![TokenType::Literal(LiteralValue::NumericValue(1.0)), TokenType::Literal(LiteralValue::NumericValue(2.0)), TOKEN_PLUS];
        assert_eq!(parse(&mut input).unwrap(), output);
    }

    #[test]
    fn test_parse_add_mult() {
        // Verify order of operands - multiply before addition
        // 1 * 2 + 3 = 1 2 * 3 +
        let mut input: Vec<TokenType> = vec![
            TokenType::Literal(LiteralValue::NumericValue(1.0)), 
            TOKEN_MULTIPLY, 
            TokenType::Literal(LiteralValue::NumericValue(2.0)),
            TOKEN_PLUS, 
            TokenType::Literal(LiteralValue::NumericValue(3.0)),
        ];
        let output: Vec<TokenType> = vec![
            TokenType::Literal(LiteralValue::NumericValue(1.0)), 
            TokenType::Literal(LiteralValue::NumericValue(2.0)),
            TOKEN_MULTIPLY, 
            TokenType::Literal(LiteralValue::NumericValue(3.0)),
            TOKEN_PLUS,
        ];
        assert_eq!(parse(&mut input).unwrap(), output);

        // above test with order reversed. 1 + 2 * 3 = 1 2 3 * +
        let mut input2: Vec<TokenType> = vec![
            TokenType::Literal(LiteralValue::NumericValue(1.0)), 
            TOKEN_PLUS, 
            TokenType::Literal(LiteralValue::NumericValue(2.0)),
            TOKEN_MULTIPLY, 
            TokenType::Literal(LiteralValue::NumericValue(3.0)),
        ];

        let output2: Vec<TokenType> = vec![
            TokenType::Literal(LiteralValue::NumericValue(1.0)), 
            TokenType::Literal(LiteralValue::NumericValue(2.0)),
            TokenType::Literal(LiteralValue::NumericValue(3.0)),
            TOKEN_MULTIPLY,
            TOKEN_PLUS,
        ];

        assert_eq!(parse(&mut input2).unwrap(), output2);
    }

    #[test]
    fn test_parse_add_mult_paren() {
        // Verify order of operands - multiply before addition
        // 1 * (2 + 3) = 1 2 3 + *
        let mut input: Vec<TokenType> = vec![
            TokenType::Literal(LiteralValue::NumericValue(1.0)), 
            TOKEN_MULTIPLY, 
            TOKEN_OPEN_PAREN, 
            TokenType::Literal(LiteralValue::NumericValue(2.0)),
            TOKEN_PLUS, 
            TokenType::Literal(LiteralValue::NumericValue(3.0)),
            TOKEN_CLOSE_PAREN 
        ];
        let output: Vec<TokenType> = vec![
            TokenType::Literal(LiteralValue::NumericValue(1.0)), 
            TokenType::Literal(LiteralValue::NumericValue(2.0)),
            TokenType::Literal(LiteralValue::NumericValue(3.0)),
            TOKEN_PLUS,
            TOKEN_MULTIPLY
        ];
        assert_eq!(parse(&mut input).unwrap(), output);

        // above test with order reversed. (1 + 2) * 3 = 1 2 + 3 *
        let mut input2: Vec<TokenType> = vec![
            TOKEN_OPEN_PAREN,
            TokenType::Literal(LiteralValue::NumericValue(1.0)),
            TOKEN_PLUS,
            TokenType::Literal(LiteralValue::NumericValue(2.0)),
            TOKEN_CLOSE_PAREN,
            TOKEN_MULTIPLY,
            TokenType::Literal(LiteralValue::NumericValue(3.0)),
        ];

        let output2: Vec<TokenType> = vec![
            TokenType::Literal(LiteralValue::NumericValue(1.0)), 
            TokenType::Literal(LiteralValue::NumericValue(2.0)),
            TOKEN_PLUS,
            TokenType::Literal(LiteralValue::NumericValue(3.0)),
            TOKEN_MULTIPLY,
        ];

        assert_eq!(parse(&mut input2).unwrap(), output2);
    }
}