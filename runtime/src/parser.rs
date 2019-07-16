use super::Result;
use avs::constants::*;
use super::structs::*;



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
    let mut operator_stack: Vec<KeywordType> = Vec::with_capacity(infix.len());

    for token in infix.drain(..) {
        match &token {
            TokenType::Keyword(kw) => {
                match kw {
                    KeywordType::KwOpenParen => operator_stack.push(*kw),
                    KeywordType::KwCloseParen => {
                        // Pop until you find the matching opening paren
                        let mut found = false;
                        while let Some(op) = operator_stack.pop() {
                            // Sholud always be true since the operator stack only contains keywords
                            match op {
                                KeywordType::KwOpenParen => {
                                    found = true;
                                    break;
                                }
                                _ => postfix.push(TokenType::Keyword(op))
                            }
                        }
                        if found == false {
                            return Err(PARSE_ERR_UNMATCHED_PARENS)
                        }
                    },
                    _ => {
                        // For all other operators, flush higher or equal level operators
                        // All operators are left associative in our system right now. (else, equals doesn't get pushed)
                        let my_precedence = get_op_precedence(*kw);
                        while operator_stack.len() > 0 {
                            let op_peek_last = operator_stack.last().unwrap();
                            // Skip any items that aren't really operators.
                            if *op_peek_last == KeywordType::KwOpenParen {
                                break;
                            }

                            let other_precedence = get_op_precedence(*op_peek_last);
                            if other_precedence >= my_precedence {        // output any higher priority operators.
                                postfix.push(TokenType::Keyword(operator_stack.pop().unwrap()));
                            } else {
                                break;
                            }
                        }
                        // Flushed all operators with higher precedence. Add to op stack.
                        operator_stack.push(*kw);
                    }
                }
            },
            TokenType::Literal(_lit) => postfix.push(token),
            TokenType::Identifier(_id) => postfix.push(token)
        }
    }

    // Flush all remaining operators onto the postfix output. 
    // Reverse so we get items in the stack order.
    operator_stack.reverse();
    for op_kw in operator_stack.drain(..) {
        // All of them should be keywords
        match op_kw {
            KeywordType::KwOpenParen => {
                println!("Invalid paren in drain operator stack");
                return Err(PARSE_ERR_UNMATCHED_PARENS)
            }
            _ => {}
        }
        postfix.push(TokenType::Keyword(op_kw));
    }

    return Ok(postfix);
}


#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_parse_basic() {
        // Verify straightforward conversion to postfix
        // 1 + 2
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